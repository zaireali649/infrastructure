#!/usr/bin/env python3
"""
SageMaker Processing Job for Daily Poem Model Scoring to Kafka
Loads models:/poem-model/Production from MLflow, scores daily inputs, produces to Kafka
"""

import os
import sys
import logging
import argparse
import json
import boto3
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta

import pandas as pd
import numpy as np
from model_io import MLflowModelLoader
from kafka_io import KafkaProducer, get_kafka_credentials
from __init__ import __version__

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# SageMaker environment variables
INPUT_DIR = os.environ.get('SM_CHANNEL_INPUT', '/opt/ml/processing/input')
OUTPUT_DIR = os.environ.get('SM_OUTPUT_DATA_DIR', '/opt/ml/processing/output')

# Required environment variables from Terraform configuration
MLFLOW_TRACKING_URI = os.environ.get('MLFLOW_TRACKING_URI')
MLFLOW_MODEL_URI = os.environ.get('MLFLOW_MODEL_URI', 'models:/poem-model/Production')
INPUT_S3_PREFIX = os.environ.get('INPUT_S3_PREFIX')
KAFKA_BOOTSTRAP = os.environ.get('KAFKA_BOOTSTRAP')
KAFKA_TOPIC = os.environ.get('KAFKA_TOPIC')
KAFKA_SECRET_ARN = os.environ.get('KAFKA_SECRET_ARN')  # Optional - for external Kafka auth

def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Daily Poem Model Scoring to Kafka Pipeline')
    
    # Processing configuration
    parser.add_argument('--batch_size', type=int, default=1000,
                       help='Batch size for processing')
    parser.add_argument('--run_window_hours', type=int, default=24,
                       help='Hours of data to process (default: 24 for daily)')
    
    # Data configuration
    parser.add_argument('--input_format', type=str, default='parquet',
                       choices=['parquet', 'csv', 'json'], help='Input data format')
    parser.add_argument('--prediction_threshold', type=float, default=0.5,
                       help='Prediction threshold for binary classification')
    
    # S3 audit output
    parser.add_argument('--enable_s3_audit', action='store_true',
                       help='Enable S3 audit output in addition to Kafka')
    
    # Performance tuning
    parser.add_argument('--max_records_per_batch', type=int, default=10000,
                       help='Maximum records per Kafka batch')
    parser.add_argument('--kafka_timeout', type=int, default=60,
                       help='Kafka producer timeout (seconds)')
    
    return parser.parse_args()

def validate_environment() -> None:
    """Validate that required environment variables are set"""
    required_vars = {
        'MLFLOW_TRACKING_URI': MLFLOW_TRACKING_URI,
        'INPUT_S3_PREFIX': INPUT_S3_PREFIX,
        'KAFKA_BOOTSTRAP': KAFKA_BOOTSTRAP,
        'KAFKA_TOPIC': KAFKA_TOPIC
    }
    
    missing_vars = [var for var, value in required_vars.items() if not value]
    
    if missing_vars:
        raise ValueError(f"Missing required environment variables: {missing_vars}")
    
    logger.info("Environment validation passed")
    logger.info(f"MLflow Model URI: {MLFLOW_MODEL_URI}")
    logger.info(f"Input S3 Prefix: {INPUT_S3_PREFIX}")
    logger.info(f"Kafka Bootstrap: {KAFKA_BOOTSTRAP}")
    logger.info(f"Kafka Topic: {KAFKA_TOPIC}")
    if KAFKA_SECRET_ARN:
        logger.info(f"Kafka Secret ARN: {KAFKA_SECRET_ARN}")

def get_s3_input_data_for_window(s3_prefix: str, window_hours: int, input_format: str) -> pd.DataFrame:
    """Load input data from S3 for the specified time window"""
    logger.info(f"Loading input data from S3 prefix: {s3_prefix}")
    logger.info(f"Time window: {window_hours} hours")
    
    try:
        s3_client = boto3.client('s3')
        
        # Parse S3 prefix
        if s3_prefix.startswith('s3://'):
            s3_prefix = s3_prefix[5:]
        
        bucket_name, prefix = s3_prefix.split('/', 1)
        
        # Calculate time window
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=window_hours)
        
        logger.info(f"Data window: {start_time.isoformat()} to {end_time.isoformat()}")
        
        # List objects in the time window
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix=prefix
        )
        
        if 'Contents' not in response:
            logger.warning(f"No objects found in S3 prefix: {s3_prefix}")
            return pd.DataFrame()
        
        # Filter objects by time window and format
        relevant_objects = []
        for obj in response['Contents']:
            # Check if object is within time window
            obj_time = obj['LastModified'].replace(tzinfo=None)
            if start_time <= obj_time <= end_time:
                # Check file format
                if obj['Key'].endswith(f'.{input_format}'):
                    relevant_objects.append(obj['Key'])
        
        if not relevant_objects:
            logger.warning(f"No {input_format} files found in time window")
            return pd.DataFrame()
        
        logger.info(f"Found {len(relevant_objects)} relevant files")
        
        # Download and combine data
        dataframes = []
        for obj_key in relevant_objects:
            logger.info(f"Processing: s3://{bucket_name}/{obj_key}")
            
            # Download to local temp file
            local_path = f"/tmp/{Path(obj_key).name}"
            s3_client.download_file(bucket_name, obj_key, local_path)
            
            # Load based on format
            if input_format == 'parquet':
                df = pd.read_parquet(local_path)
            elif input_format == 'csv':
                df = pd.read_csv(local_path)
            elif input_format == 'json':
                df = pd.read_json(local_path)
            
            # Add metadata
            df['source_file'] = obj_key
            df['ingestion_time'] = datetime.utcnow().isoformat()
            
            dataframes.append(df)
            
            # Clean up temp file
            os.remove(local_path)
        
        # Combine all dataframes
        combined_df = pd.concat(dataframes, ignore_index=True) if dataframes else pd.DataFrame()
        
        logger.info(f"Combined dataset shape: {combined_df.shape}")
        return combined_df
        
    except Exception as e:
        logger.error(f"Failed to load S3 input data: {e}")
        raise

def preprocess_data(df: pd.DataFrame, model_loader: MLflowModelLoader) -> pd.DataFrame:
    """Preprocess data to match training format"""
    logger.info("Preprocessing data for inference")
    
    try:
        # Get expected features from model metadata
        expected_features = model_loader.get_expected_features()
        
        if expected_features:
            # Ensure we have the expected features
            missing_features = set(expected_features) - set(df.columns)
            if missing_features:
                logger.warning(f"Missing features: {missing_features}")
                # Add missing features with default values
                for feature in missing_features:
                    df[feature] = 0  # or appropriate default value
            
            # Select and order features to match training
            df = df[expected_features]
        
        # Handle missing values
        if df.isnull().any().any():
            logger.warning("Filling missing values")
            numeric_columns = df.select_dtypes(include=[np.number]).columns
            categorical_columns = df.select_dtypes(exclude=[np.number]).columns
            
            df[numeric_columns] = df[numeric_columns].fillna(df[numeric_columns].median())
            df[categorical_columns] = df[categorical_columns].fillna('Unknown')
        
        logger.info(f"Preprocessed data shape: {df.shape}")
        return df
        
    except Exception as e:
        logger.error(f"Data preprocessing failed: {e}")
        raise

def generate_predictions(df: pd.DataFrame, model_loader: MLflowModelLoader, 
                        args: argparse.Namespace) -> pd.DataFrame:
    """Generate predictions using the loaded poem model"""
    logger.info(f"Generating predictions for {len(df)} samples using poem-model")
    
    try:
        # Get predictions from model
        predictions = model_loader.predict(df)
        prediction_probabilities = model_loader.predict_proba(df)
        
        # Create results dataframe
        results = df.copy()
        results['prediction'] = predictions
        results['prediction_timestamp'] = datetime.utcnow().isoformat()
        results['model_name'] = 'poem-model'
        results['model_version'] = model_loader.get_model_version()
        results['model_stage'] = 'Production'
        
        # Add prediction probabilities if available
        if prediction_probabilities is not None:
            if prediction_probabilities.shape[1] == 2:  # Binary classification
                results['prediction_probability'] = prediction_probabilities[:, 1]
                results['prediction_confidence'] = np.max(prediction_probabilities, axis=1)
            else:  # Multi-class
                results['prediction_confidence'] = np.max(prediction_probabilities, axis=1)
                # Add class probabilities
                class_names = model_loader.get_class_names()
                if class_names:
                    for i, class_name in enumerate(class_names):
                        results[f'prob_{class_name}'] = prediction_probabilities[:, i]
        
        # Add prediction flags for binary classification
        if prediction_probabilities is not None and prediction_probabilities.shape[1] == 2:
            results['high_confidence'] = results['prediction_confidence'] > 0.8
            results['above_threshold'] = results['prediction_probability'] > args.prediction_threshold
        
        logger.info(f"Generated {len(results)} predictions")
        return results
        
    except Exception as e:
        logger.error(f"Prediction generation failed: {e}")
        raise

def batch_process_and_send_to_kafka(predictions_df: pd.DataFrame, kafka_producer: KafkaProducer,
                                   args: argparse.Namespace) -> Dict[str, Any]:
    """Process predictions in batches and send to Kafka"""
    logger.info(f"Sending {len(predictions_df)} predictions to Kafka topic: {KAFKA_TOPIC}")
    
    try:
        total_records = len(predictions_df)
        success_count = 0
        error_count = 0
        
        # Process in batches
        for i in range(0, total_records, args.max_records_per_batch):
            batch_end = min(i + args.max_records_per_batch, total_records)
            batch_df = predictions_df.iloc[i:batch_end]
            
            logger.info(f"Processing batch {i//args.max_records_per_batch + 1}: records {i+1} to {batch_end}")
            
            # Convert batch to Kafka messages
            messages = []
            for _, row in batch_df.iterrows():
                try:
                    # Create JSON message
                    message = {
                        'timestamp': row['prediction_timestamp'],
                        'model_name': row['model_name'],
                        'model_version': row['model_version'],
                        'model_stage': row['model_stage'],
                        'prediction': int(row['prediction']) if np.issubdtype(type(row['prediction']), np.integer) else float(row['prediction']),
                        'features': row.drop([
                            'prediction', 'prediction_timestamp', 'model_name', 
                            'model_version', 'model_stage', 'source_file', 'ingestion_time'
                        ]).to_dict()
                    }
                    
                    # Add probability information if available
                    if 'prediction_probability' in row:
                        message['prediction_probability'] = float(row['prediction_probability'])
                    if 'prediction_confidence' in row:
                        message['prediction_confidence'] = float(row['prediction_confidence'])
                    if 'high_confidence' in row:
                        message['high_confidence'] = bool(row['high_confidence'])
                    if 'above_threshold' in row:
                        message['above_threshold'] = bool(row['above_threshold'])
                    
                    # Add audit information
                    message['audit'] = {
                        'source_file': row.get('source_file', 'unknown'),
                        'ingestion_time': row.get('ingestion_time'),
                        'processing_batch': i//args.max_records_per_batch + 1
                    }
                    
                    messages.append(message)
                    
                except Exception as e:
                    logger.error(f"Failed to prepare message for record {row.name}: {e}")
                    error_count += 1
            
            # Send batch to Kafka
            if messages:
                try:
                    batch_success = kafka_producer.send_batch(messages, topic=KAFKA_TOPIC)
                    success_count += batch_success
                    logger.info(f"Batch sent: {batch_success}/{len(messages)} messages")
                except Exception as e:
                    logger.error(f"Failed to send batch to Kafka: {e}")
                    error_count += len(messages)
        
        # Flush remaining messages
        kafka_producer.flush()
        
        results = {
            'total_predictions': total_records,
            'successful_sends': success_count,
            'failed_sends': error_count,
            'success_rate': success_count / total_records if total_records > 0 else 0,
            'batches_processed': (total_records + args.max_records_per_batch - 1) // args.max_records_per_batch
        }
        
        logger.info(f"Kafka sending completed: {results}")
        return results
        
    except Exception as e:
        logger.error(f"Kafka batch processing failed: {e}")
        raise

def save_audit_output(predictions_df: pd.DataFrame, kafka_results: Dict[str, Any], 
                     output_dir: str, args: argparse.Namespace) -> None:
    """Save processing results and audit data to S3"""
    logger.info(f"Saving audit output to: {output_dir}")
    
    try:
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save processing summary
        summary = {
            'processing_timestamp': datetime.utcnow().isoformat(),
            'model_uri': MLFLOW_MODEL_URI,
            'input_s3_prefix': INPUT_S3_PREFIX,
            'kafka_topic': KAFKA_TOPIC,
            'total_records_processed': len(predictions_df),
            'kafka_results': kafka_results,
            'run_window_hours': args.run_window_hours,
            'batch_size': args.batch_size,
            'prediction_stats': {
                'mean_confidence': float(predictions_df['prediction_confidence'].mean()) if 'prediction_confidence' in predictions_df else None,
                'prediction_distribution': predictions_df['prediction'].value_counts().to_dict() if 'prediction' in predictions_df else None
            },
            'version': __version__
        }
        
        with open(output_path / 'processing_summary.json', 'w') as f:
            json.dump(summary, f, indent=2)
        
        # Save predictions sample for audit
        if args.enable_s3_audit and len(predictions_df) > 0:
            if len(predictions_df) > 1000:
                sample_predictions = predictions_df.sample(n=1000, random_state=42)
            else:
                sample_predictions = predictions_df
                
            sample_predictions.to_parquet(output_path / 'predictions_audit_sample.parquet', index=False)
            logger.info(f"Saved {len(sample_predictions)} predictions to audit file")
        
        logger.info("Audit output saved successfully")
        
    except Exception as e:
        logger.error(f"Failed to save audit output: {e}")

def main() -> None:
    """Main daily scoring pipeline function"""
    logger.info(f"Starting Daily Poem Model Scoring Pipeline v{__version__}")
    
    try:
        # Parse arguments and validate environment
        args = parse_arguments()
        validate_environment()
        
        logger.info(f"Configuration: {vars(args)}")
        
        # Initialize MLflow model loader for poem-model Production
        logger.info(f"Loading MLflow model: {MLFLOW_MODEL_URI}")
        model_loader = MLflowModelLoader(
            tracking_uri=MLFLOW_TRACKING_URI,
            model_uri=MLFLOW_MODEL_URI
        )
        
        # Load the Production model
        model_loader.load_model()
        logger.info("Poem model loaded successfully from Production stage")
        
        # Initialize Kafka producer with credentials
        kafka_credentials = get_kafka_credentials(KAFKA_SECRET_ARN) if KAFKA_SECRET_ARN else {}
        kafka_producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            topic=KAFKA_TOPIC,
            timeout=args.kafka_timeout,
            credentials=kafka_credentials
        )
        
        # Load input data for the time window
        input_data = get_s3_input_data_for_window(
            INPUT_S3_PREFIX, 
            args.run_window_hours, 
            args.input_format
        )
        
        if input_data.empty:
            logger.warning("No input data found for processing window")
            return
        
        # Preprocess data
        processed_data = preprocess_data(input_data, model_loader)
        
        # Generate predictions using poem-model
        predictions = generate_predictions(processed_data, model_loader, args)
        
        # Send predictions to Kafka in batches
        kafka_results = batch_process_and_send_to_kafka(predictions, kafka_producer, args)
        
        # Save audit output to S3
        save_audit_output(predictions, kafka_results, OUTPUT_DIR, args)
        
        # Close Kafka producer
        kafka_producer.close()
        
        logger.info("Daily scoring pipeline completed successfully")
        logger.info(f"Processed {len(predictions)} records")
        logger.info(f"Success rate: {kafka_results['success_rate']:.2%}")
        
        # Exit with success
        sys.exit(0)
        
    except Exception as e:
        logger.error(f"Daily scoring pipeline failed: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()