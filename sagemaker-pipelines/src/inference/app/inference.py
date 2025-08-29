#!/usr/bin/env python3
"""
Simple SageMaker Inference for Iris Model
Loads model from MLflow and runs daily predictions on random data
"""

import os
import logging
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
    """Load the latest production model from MLflow"""
    logger.info(f"Loading model '{MODEL_NAME}' from MLflow")

    try:
        # Load the production model
        model_uri = f"models:/{MODEL_NAME}/Production"
        model = mlflow.sklearn.load_model(model_uri)
        logger.info("Model loaded successfully")
        return model
    except Exception as e:
        logger.warning(f"Failed to load production model: {e}")
        # Fallback to latest version
        try:
            model_uri = f"models:/{MODEL_NAME}/latest"
            model = mlflow.sklearn.load_model(model_uri)
            logger.info("Loaded latest model version")
            return model
        except Exception as e2:
            logger.error(f"Failed to load any model: {e2}")
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


def save_results(data, predictions, predicted_classes):
    """Save prediction results"""
    logger.info("Saving prediction results")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Create results dataframe
    results = data.copy()
    results["prediction_numeric"] = predictions
    results["prediction_class"] = predicted_classes
    results["prediction_timestamp"] = datetime.now().isoformat()

    # Save to CSV
    output_file = os.path.join(
        OUTPUT_DIR, f"predictions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    )
    results.to_csv(output_file, index=False)

    logger.info(f"Results saved to {output_file}")
    logger.info(f"Prediction summary:\n{pd.Series(predicted_classes).value_counts()}")


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
        model = load_model()

        # Generate random data
        data = generate_random_iris_data(n_samples=20)

        # Make predictions
        predictions, predicted_classes = make_predictions(model, data)

        # Save results
        save_results(data, predictions, predicted_classes)

        logger.info("Inference completed successfully!")

    except Exception as e:
        logger.error(f"Inference failed: {e}")
        raise


if __name__ == "__main__":
    main()
