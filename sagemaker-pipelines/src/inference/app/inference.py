#!/usr/bin/env python3
"""
Simple SageMaker Inference for Iris Model
Loads model from MLflow and runs daily predictions on random data
"""

import os
import logging
import re
import pandas as pd
import numpy as np
import mlflow
import mlflow.sklearn
import boto3
from datetime import datetime

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MLflow settings
MLFLOW_TRACKING_URI = os.environ.get("MLFLOW_TRACKING_URI")
MLFLOW_TRACKING_SERVER_NAME = os.environ.get("MLFLOW_TRACKING_SERVER_NAME", "mlflow-staging-mlflow")
MODEL_NAME = "iris-model"
OUTPUT_DIR = os.environ.get("SM_PROCESSING_OUTPUT_DIR", "/opt/ml/processing/output")


def discover_mlflow_tracking_server():
    """Get MLflow tracking server ARN by name for SageMaker authentication"""
    try:
        # Use boto3 to get the specific MLflow tracking server
        region = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        sagemaker_client = boto3.client("sagemaker", region_name=region)

        logger.info(f"Getting MLflow tracking server: {MLFLOW_TRACKING_SERVER_NAME}")
        
        # Get detailed information for the specific tracking server
        detail_response = sagemaker_client.describe_mlflow_tracking_server(
            TrackingServerName=MLFLOW_TRACKING_SERVER_NAME
        )
        
        # For SageMaker MLflow, use the ARN as tracking URI (with sagemaker-mlflow plugin)
        tracking_arn = detail_response.get("TrackingServerArn")
        tracking_url = detail_response.get("TrackingServerUrl")
        
        if tracking_arn:
            logger.info(f"Retrieved MLflow tracking server URL: {tracking_url}")
            logger.info(f"Retrieved MLflow tracking server ARN: {tracking_arn}")
            return tracking_arn
        else:
            logger.warning(f"No TrackingServerArn in response: {detail_response}")
            return None
        
    except Exception as e:
        logger.warning(f"Failed to get MLflow tracking server '{MLFLOW_TRACKING_SERVER_NAME}': {e}")
        return None


def setup_mlflow():
    """Setup MLflow tracking with SageMaker MLflow server"""
    tracking_uri = MLFLOW_TRACKING_URI

    # If no URI provided via environment, try to discover the ARN
    if not tracking_uri:
        tracking_uri = discover_mlflow_tracking_server()

    if tracking_uri:
        # For SageMaker MLflow, use the ARN as tracking URI
        # The sagemaker-mlflow plugin handles authentication automatically
        mlflow.set_tracking_uri(tracking_uri)
        logger.info(f"MLflow tracking URI set to: {tracking_uri}")
        
        if tracking_uri.startswith("arn:aws:sagemaker"):
            logger.info("Using SageMaker MLflow tracking server with ARN-based authentication")
        else:
            logger.info("Using standard MLflow tracking server")
        return True
    else:
        logger.warning("No MLflow tracking URI available - running without MLflow")
        return False


def load_model():
    """Load the latest model from MLflow"""
    logger.info(f"Loading latest model '{MODEL_NAME}' from MLflow")

    try:
        model_uri = f"models:/{MODEL_NAME}/latest"
        model = mlflow.sklearn.load_model(model_uri)
        logger.info("Latest model loaded successfully")
        return model, "latest"
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


def generate_random_iris_data(n_samples=10):
    """Generate random data similar to Iris dataset"""
    logger.info(f"Generating {n_samples} random samples for prediction")

    # Generate random data within typical Iris ranges
    np.random.seed(int(datetime.now().timestamp()) % 1000)  # Different seed each run

    data = {
        "sepal length (cm)": np.random.uniform(4.0, 8.0, n_samples),
        "sepal width (cm)": np.random.uniform(2.0, 4.5, n_samples),
        "petal length (cm)": np.random.uniform(1.0, 7.0, n_samples),
        "petal width (cm)": np.random.uniform(0.1, 2.5, n_samples),
    }

    df = pd.DataFrame(data)
    logger.info(f"Generated data shape: {df.shape}")
    return df


def make_predictions(model, data):
    """Make predictions on the data"""
    logger.info("Making predictions")

    try:
        predictions = model.predict(data)

        # Map predictions to class names
        class_names = ["setosa", "versicolor", "virginica"]
        predicted_classes = [class_names[pred] for pred in predictions]

        logger.info(f"Made {len(predictions)} predictions")
        return predictions, predicted_classes
    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        raise


def sanitize_metric_name(name):
    """Sanitize metric names for MLflow compatibility"""
    # MLflow allows: alphanumerics, underscores, dashes, periods, spaces, colons, slashes
    # Remove parentheses and other invalid chars, replace with underscores
    sanitized = re.sub(r'[^a-zA-Z0-9_\-\. :/]', '_', str(name))
    # Remove multiple consecutive underscores
    sanitized = re.sub(r'_+', '_', sanitized)
    # Remove leading/trailing underscores
    sanitized = sanitized.strip('_')
    return sanitized


def log_inference_to_mlflow(data, predictions, predicted_classes, model_version=None):
    """Log inference results to MLflow as an experiment run"""
    logger.info("Logging inference results to MLflow")

    # Create results dataframe for analysis
    results = data.copy()
    results["prediction_numeric"] = predictions
    results["prediction_class"] = predicted_classes
    results["prediction_timestamp"] = datetime.now().isoformat()

    # Get prediction summary
    prediction_counts = pd.Series(predicted_classes).value_counts()
    
    try:
        # Set experiment for inference logging
        mlflow.set_experiment("iris-model-inference")
        
        # Create meaningful run name for inference
        inference_date = datetime.now()
        run_name = f"iris-inference-{inference_date.strftime('%Y-%m-%d_%H-%M-%S')}-{len(data)}samples-{model_version}"
        
        with mlflow.start_run(run_name=run_name):
            # Log run metadata
            mlflow.log_param("model_name", MODEL_NAME)
            mlflow.log_param("model_version", model_version or "latest")
            mlflow.log_param("inference_timestamp", datetime.now().isoformat())
            mlflow.log_param("num_samples", len(data))
            
            # Log prediction metrics
            mlflow.log_metric("total_predictions", len(predictions))
            for class_name, count in prediction_counts.items():
                mlflow.log_metric(f"predictions_{class_name}", count)
                mlflow.log_metric(f"percentage_{class_name}", (count / len(predictions)) * 100)
            
            # Log input data statistics as metrics
            for column in data.columns:
                sanitized_column = sanitize_metric_name(column)
                mlflow.log_metric(f"input_{sanitized_column}_mean", data[column].mean())
                mlflow.log_metric(f"input_{sanitized_column}_std", data[column].std())
            
            # Log the results as an artifact (optional CSV backup)
            try:
                os.makedirs(OUTPUT_DIR, mode=0o755, exist_ok=True)
                output_file = os.path.join(
                    OUTPUT_DIR, f"predictions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
                )
                results.to_csv(output_file, index=False)
                mlflow.log_artifact(output_file, "predictions")
                logger.info(f"Results also saved as artifact: {output_file}")
            except PermissionError as e:
                logger.warning(f"Could not save CSV artifact due to permissions: {e}")
                # Continue without CSV - MLflow logging is the primary goal
            
            logger.info("Inference results logged to MLflow successfully")
            logger.info(f"Prediction summary:\n{prediction_counts}")
            
    except Exception as e:
        logger.error(f"Failed to log inference results to MLflow: {e}")
        # Fallback: try to save basic results info
        logger.info(f"Fallback - Prediction summary:\n{prediction_counts}")
        raise


def main():
    """Main inference function"""
    logger.info("Starting daily Iris model inference")

    try:
        # Setup MLflow
        mlflow_available = setup_mlflow()
        
        if not mlflow_available:
            logger.error("MLflow not available - cannot load model")
            raise RuntimeError("MLflow tracking server not available")

        # Load model
        model, model_version = load_model()

        # Generate random data
        data = generate_random_iris_data(n_samples=20)

        # Make predictions
        predictions, predicted_classes = make_predictions(model, data)

        # Log results to MLflow
        log_inference_to_mlflow(data, predictions, predicted_classes, model_version)

        logger.info("Inference completed successfully!")

    except Exception as e:
        logger.error(f"Inference failed: {e}")
        raise


if __name__ == "__main__":
    main()
