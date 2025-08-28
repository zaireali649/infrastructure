#!/usr/bin/env python3
"""
SageMaker Training Application for Weekly Poem Model Training
Trains model, logs to MLflow, registers as 'poem-model', and promotes to Production
"""

import os
import sys
import logging
import argparse
from pathlib import Path
from typing import Tuple, Dict, Any, Optional

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.preprocessing import LabelEncoder
import mlflow
import mlflow.sklearn
from mlflow.tracking import MlflowClient
import joblib
from datetime import datetime
import json

from utils import setup_logging, load_config, save_artifacts
from __init__ import __version__

# Set up logging
logger = logging.getLogger(__name__)

# SageMaker environment variables
MODEL_DIR = os.environ.get('SM_MODEL_DIR', '/opt/ml/model')
INPUT_DIR = os.environ.get('SM_CHANNEL_TRAINING', '/opt/ml/input/data/training')
OUTPUT_DIR = os.environ.get('SM_OUTPUT_DATA_DIR', '/opt/ml/output')
HYPERPARAMS_FILE = os.environ.get('SM_HPS', '/opt/ml/input/config/hyperparameters.json')

# MLflow environment variables
MLFLOW_TRACKING_URI = os.environ.get('MLFLOW_TRACKING_URI')
MODEL_NAME = "poem-model"  # Fixed model name as specified

def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments and hyperparameters"""
    parser = argparse.ArgumentParser(description='ML Platform Training Pipeline')
    
    # Model hyperparameters
    parser.add_argument('--n_estimators', type=int, default=100, help='Number of trees in forest')
    parser.add_argument('--max_depth', type=int, default=10, help='Maximum depth of trees')
    parser.add_argument('--random_state', type=int, default=42, help='Random state for reproducibility')
    parser.add_argument('--test_size', type=float, default=0.2, help='Test set proportion')
    parser.add_argument('--learning_rate', type=float, default=0.1, help='Learning rate (for future algorithms)')
    
    # MLflow configuration
    parser.add_argument('--model_name', type=str, default='ml-classifier', help='MLflow model name')
    parser.add_argument('--experiment_name', type=str, default='staging-experiments', help='MLflow experiment')
    
    # Training configuration
    parser.add_argument('--model_type', type=str, default='classification', help='Type of ML problem')
    parser.add_argument('--data_format', type=str, default='parquet', help='Input data format')
    parser.add_argument('--validation_size', type=float, default=0.2, help='Validation set size')
    
    # Parse from command line first, then override with SageMaker hyperparameters
    args = parser.parse_args()
    
    # Load SageMaker hyperparameters if available
    if os.path.exists(HYPERPARAMS_FILE):
        try:
            with open(HYPERPARAMS_FILE, 'r') as f:
                hyperparams = json.load(f)
            
            # Override command line args with SageMaker hyperparameters
            for key, value in hyperparams.items():
                if hasattr(args, key):
                    # Convert string values to appropriate types
                    current_type = type(getattr(args, key))
                    if current_type == bool:
                        setattr(args, key, value.lower() in ('true', '1', 'yes'))
                    elif current_type in (int, float):
                        setattr(args, key, current_type(value))
                    else:
                        setattr(args, key, value)
                        
            logger.info(f"Loaded hyperparameters from SageMaker: {hyperparams}")
        except Exception as e:
            logger.warning(f"Could not load SageMaker hyperparameters: {e}")
    
    return args

def setup_mlflow(experiment_name: str = "poem-model-training") -> MlflowClient:
    """Setup MLflow tracking with error handling"""
    try:
        # Set tracking URI from environment (required)
        if not MLFLOW_TRACKING_URI:
            raise ValueError("MLFLOW_TRACKING_URI environment variable is required")
        
        mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
        logger.info(f"MLflow tracking URI: {MLFLOW_TRACKING_URI}")
        
        # Set or create experiment
        mlflow.set_experiment(experiment_name)
        logger.info(f"Using MLflow experiment: {experiment_name}")
        
        # Create MLflow client for model registration and promotion
        client = MlflowClient()
        logger.info("MLflow client initialized successfully")
        
        return client
            
    except Exception as e:
        logger.error(f"MLflow setup failed: {e}")
        raise

def load_and_validate_data() -> pd.DataFrame:
    """Load and validate training data with comprehensive error handling"""
    logger.info(f"Loading data from: {INPUT_DIR}")
    
    try:
        # Find data files
        input_path = Path(INPUT_DIR)
        data_files = []
        
        # Look for common data file formats
        for pattern in ['*.parquet', '*.csv', '*.json']:
            data_files.extend(list(input_path.rglob(pattern)))
        
        if not data_files:
            raise FileNotFoundError(f"No data files found in {INPUT_DIR}")
        
        logger.info(f"Found {len(data_files)} data files: {[f.name for f in data_files]}")
        
        # Load data based on file type
        dataframes = []
        for file_path in data_files:
            logger.info(f"Loading {file_path}")
            
            if file_path.suffix == '.parquet':
                df = pd.read_parquet(file_path)
            elif file_path.suffix == '.csv':
                df = pd.read_csv(file_path)
            elif file_path.suffix == '.json':
                df = pd.read_json(file_path)
            else:
                logger.warning(f"Unsupported file format: {file_path}")
                continue
                
            dataframes.append(df)
        
        # Combine all dataframes
        if len(dataframes) == 1:
            combined_df = dataframes[0]
        else:
            combined_df = pd.concat(dataframes, ignore_index=True)
        
        logger.info(f"Combined dataset shape: {combined_df.shape}")
        logger.info(f"Columns: {combined_df.columns.tolist()}")
        
        # Basic data validation
        if combined_df.empty:
            raise ValueError("Dataset is empty")
        
        if combined_df.shape[1] < 2:
            raise ValueError("Dataset must have at least 2 columns (features + target)")
        
        # Check for missing values
        missing_values = combined_df.isnull().sum()
        if missing_values.any():
            logger.warning(f"Missing values found:\n{missing_values[missing_values > 0]}")
        
        return combined_df
        
    except Exception as e:
        logger.error(f"Data loading failed: {e}")
        raise

def prepare_features_and_target(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series, Optional[LabelEncoder]]:
    """Prepare features and target with robust preprocessing"""
    logger.info("Preparing features and target variables")
    
    try:
        # Assume last column is target (common convention)
        feature_columns = df.columns[:-1]
        target_column = df.columns[-1]
        
        X = df[feature_columns].copy()
        y = df[target_column].copy()
        
        logger.info(f"Features: {feature_columns.tolist()}")
        logger.info(f"Target: {target_column}")
        logger.info(f"Features shape: {X.shape}, Target shape: {y.shape}")
        
        # Handle categorical target
        label_encoder = None
        if y.dtype == 'object' or y.dtype.name == 'category':
            label_encoder = LabelEncoder()
            y_encoded = label_encoder.fit_transform(y.astype(str))
            logger.info(f"Encoded target classes: {label_encoder.classes_}")
            y = pd.Series(y_encoded, index=y.index)
        
        # Handle categorical features
        categorical_features = X.select_dtypes(include=['object', 'category']).columns
        if len(categorical_features) > 0:
            logger.info(f"Encoding categorical features: {categorical_features.tolist()}")
            for col in categorical_features:
                le = LabelEncoder()
                X[col] = le.fit_transform(X[col].astype(str))
        
        # Handle missing values (simple imputation)
        if X.isnull().any().any():
            logger.warning("Filling missing values with median/mode")
            numeric_columns = X.select_dtypes(include=[np.number]).columns
            categorical_columns = X.select_dtypes(exclude=[np.number]).columns
            
            # Fill numeric with median
            X[numeric_columns] = X[numeric_columns].fillna(X[numeric_columns].median())
            # Fill categorical with mode
            X[categorical_columns] = X[categorical_columns].fillna(X[categorical_columns].mode().iloc[0])
        
        return X, y, label_encoder
        
    except Exception as e:
        logger.error(f"Feature preparation failed: {e}")
        raise

def train_model(X: pd.DataFrame, y: pd.Series, args: argparse.Namespace) -> Tuple[RandomForestClassifier, pd.DataFrame, pd.Series, np.ndarray, float]:
    """Train the model with comprehensive logging"""
    logger.info("Starting model training")
    
    try:
        # Split data
        stratify = y if len(np.unique(y)) > 1 and len(np.unique(y)) < len(y) * 0.5 else None
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, 
            test_size=args.test_size,
            random_state=args.random_state,
            stratify=stratify
        )
        
        logger.info(f"Train set: {X_train.shape[0]} samples")
        logger.info(f"Test set: {X_test.shape[0]} samples")
        logger.info(f"Feature count: {X_train.shape[1]}")
        
        # Create and train model
        model = RandomForestClassifier(
            n_estimators=args.n_estimators,
            max_depth=args.max_depth,
            random_state=args.random_state,
            n_jobs=-1,
            class_weight='balanced'  # Handle imbalanced classes
        )
        
        logger.info("Training model...")
        model.fit(X_train, y_train)
        
        # Make predictions
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        logger.info(f"Training completed. Accuracy: {accuracy:.4f}")
        
        return model, X_test, y_test, y_pred, accuracy
        
    except Exception as e:
        logger.error(f"Model training failed: {e}")
        raise

def log_to_mlflow_and_register(model: RandomForestClassifier, X_test: pd.DataFrame, y_test: pd.Series, 
                               y_pred: np.ndarray, accuracy: float, args: argparse.Namespace,
                               client: MlflowClient) -> str:
    """Log comprehensive metrics and artifacts to MLflow, register model, and promote to Production"""
    try:
        with mlflow.start_run() as run:
            run_id = run.info.run_id
            logger.info(f"Started MLflow run: {run_id}")
            
            # Log parameters
            mlflow.log_param("model_type", "RandomForestClassifier")
            mlflow.log_param("n_estimators", args.n_estimators)
            mlflow.log_param("max_depth", args.max_depth)
            mlflow.log_param("random_state", args.random_state)
            mlflow.log_param("test_size", args.test_size)
            mlflow.log_param("training_date", datetime.now().isoformat())
            mlflow.log_param("environment", os.environ.get('ENVIRONMENT', 'unknown'))
            mlflow.log_param("owner", os.environ.get('OWNER', 'unknown'))
            mlflow.log_param("version", __version__)
            mlflow.log_param("model_name", MODEL_NAME)
            
            # Log metrics
            mlflow.log_metric("accuracy", accuracy)
            mlflow.log_metric("n_features", X_test.shape[1])
            mlflow.log_metric("n_test_samples", X_test.shape[0])
            mlflow.log_metric("n_classes", len(np.unique(y_test)))
            
            # Calculate additional metrics for classification
            if len(np.unique(y_test)) > 1:
                from sklearn.metrics import precision_score, recall_score, f1_score, roc_auc_score
                
                average = 'weighted' if len(np.unique(y_test)) > 2 else 'binary'
                
                precision = precision_score(y_test, y_pred, average=average, zero_division=0)
                recall = recall_score(y_test, y_pred, average=average, zero_division=0)
                f1 = f1_score(y_test, y_pred, average=average, zero_division=0)
                
                mlflow.log_metric("precision", precision)
                mlflow.log_metric("recall", recall)
                mlflow.log_metric("f1_score", f1)
                
                # ROC AUC for binary classification
                if len(np.unique(y_test)) == 2:
                    try:
                        y_pred_proba = model.predict_proba(X_test)[:, 1]
                        auc = roc_auc_score(y_test, y_pred_proba)
                        mlflow.log_metric("roc_auc", auc)
                    except Exception as e:
                        logger.warning(f"Could not calculate ROC AUC: {e}")
            
            # Save and log additional artifacts
            save_artifacts(model, X_test, y_test, y_pred, OUTPUT_DIR)
            
            # Log artifacts
            for artifact_file in Path(OUTPUT_DIR).glob("*.csv"):
                mlflow.log_artifact(str(artifact_file))
            for artifact_file in Path(OUTPUT_DIR).glob("*.json"):
                mlflow.log_artifact(str(artifact_file))
            
            # Log model with poem-model name
            model_info = mlflow.sklearn.log_model(
                sk_model=model,
                artifact_path="model",
                registered_model_name=MODEL_NAME,
                signature=mlflow.models.infer_signature(X_test, y_pred)
            )
            
            logger.info(f"Model logged to MLflow: {model_info.model_uri}")
            
            # Register the model and promote to Production
            model_version = promote_model_to_production(client, MODEL_NAME, run_id, accuracy)
            
            logger.info("Successfully logged to MLflow and promoted to Production")
            return model_version
            
    except Exception as e:
        logger.error(f"MLflow logging failed: {e}")
        raise

def promote_model_to_production(client: MlflowClient, model_name: str, run_id: str, accuracy: float) -> str:
    """Register model and promote to Production stage"""
    try:
        # Get the latest version of the registered model
        latest_versions = client.get_latest_versions(model_name, stages=["None", "Staging", "Production"])
        
        # Find the version that was just created
        model_version = None
        for version in client.search_model_versions(f"name='{model_name}'"):
            if version.run_id == run_id:
                model_version = version.version
                break
        
        if not model_version:
            # If model doesn't exist, it was just created by log_model
            # Wait a moment and try again
            import time
            time.sleep(2)
            for version in client.search_model_versions(f"name='{model_name}'"):
                if version.run_id == run_id:
                    model_version = version.version
                    break
        
        if not model_version:
            raise ValueError(f"Could not find model version for run {run_id}")
        
        logger.info(f"Found model version {model_version} for poem-model")
        
        # Check if we should promote based on performance
        should_promote = True  # You can add validation logic here
        
        if should_promote:
            # First, demote any existing Production models to Archived
            production_versions = client.get_latest_versions(model_name, stages=["Production"])
            for prod_version in production_versions:
                logger.info(f"Archiving previous Production version {prod_version.version}")
                client.transition_model_version_stage(
                    name=model_name,
                    version=prod_version.version,
                    stage="Archived",
                    archive_existing_versions=True
                )
            
            # Promote the new model to Production
            logger.info(f"Promoting model version {model_version} to Production")
            client.transition_model_version_stage(
                name=model_name,
                version=model_version,
                stage="Production",
                archive_existing_versions=True
            )
            
            # Add description with performance metrics
            client.update_model_version(
                name=model_name,
                version=model_version,
                description=f"Weekly training run - Accuracy: {accuracy:.4f} - Promoted on {datetime.now().isoformat()}"
            )
            
            logger.info(f"Successfully promoted poem-model version {model_version} to Production")
        else:
            logger.warning(f"Model performance (accuracy: {accuracy:.4f}) did not meet criteria for Production promotion")
        
        return model_version
        
    except Exception as e:
        logger.error(f"Model promotion failed: {e}")
        # Don't fail the entire training job if promotion fails
        return "unknown"

def save_model(model: RandomForestClassifier, label_encoder: Optional[LabelEncoder] = None) -> None:
    """Save model artifacts for SageMaker"""
    logger.info(f"Saving model to: {MODEL_DIR}")
    
    try:
        # Ensure model directory exists
        Path(MODEL_DIR).mkdir(parents=True, exist_ok=True)
        
        # Save the trained model
        model_path = Path(MODEL_DIR) / 'model.joblib'
        joblib.dump(model, model_path)
        
        # Save label encoder if used
        if label_encoder is not None:
            encoder_path = Path(MODEL_DIR) / 'label_encoder.joblib'
            joblib.dump(label_encoder, encoder_path)
        
        # Save model metadata
        metadata = {
            'model_type': 'RandomForestClassifier',
            'framework': 'scikit-learn',
            'version': __version__,
            'training_date': datetime.now().isoformat(),
            'has_label_encoder': label_encoder is not None,
            'python_version': sys.version,
            'dependencies': {
                'scikit-learn': getattr(__import__('sklearn'), '__version__', 'unknown'),
                'pandas': getattr(pd, '__version__', 'unknown'),
                'numpy': getattr(np, '__version__', 'unknown')
            }
        }
        
        metadata_path = Path(MODEL_DIR) / 'metadata.json'
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        logger.info("Model artifacts saved successfully")
        
    except Exception as e:
        logger.error(f"Model saving failed: {e}")
        raise

def main() -> None:
    """Main training function for weekly poem model training"""
    # Setup logging
    setup_logging()
    logger.info(f"Starting Weekly Poem Model Training Pipeline v{__version__}")
    
    try:
        # Parse arguments
        args = parse_arguments()
        logger.info(f"Training configuration: {vars(args)}")
        
        # Setup MLflow and get client
        client = setup_mlflow("poem-model-training")
        
        # Load and validate data
        df = load_and_validate_data()
        
        # Prepare features and target
        X, y, label_encoder = prepare_features_and_target(df)
        
        # Train model
        model, X_test, y_test, y_pred, accuracy = train_model(X, y, args)
        
        # Log to MLflow, register model, and promote to Production
        model_version = log_to_mlflow_and_register(model, X_test, y_test, y_pred, accuracy, args, client)
        
        # Save model artifacts
        save_model(model, label_encoder)
        
        logger.info(f"Training completed successfully!")
        logger.info(f"Final accuracy: {accuracy:.4f}")
        logger.info(f"Model '{MODEL_NAME}' version {model_version} promoted to Production")
        
        # Exit with success
        sys.exit(0)
        
    except Exception as e:
        logger.error(f"Training pipeline failed: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()
