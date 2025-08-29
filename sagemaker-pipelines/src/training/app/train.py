#!/usr/bin/env python3
"""
Simple SageMaker Training for Iris Dataset
Trains a RandomForest model weekly and saves to MLflow
"""

import os
import logging
import pandas as pd
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report
import mlflow
import mlflow.sklearn
import joblib
import boto3
from datetime import datetime

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# SageMaker directories
MODEL_DIR = os.environ.get("SM_MODEL_DIR", "/opt/ml/model")
OUTPUT_DIR = os.environ.get("SM_OUTPUT_DATA_DIR", "/opt/ml/output")

# MLflow settings
MLFLOW_TRACKING_URI = os.environ.get("MLFLOW_TRACKING_URI")
MLFLOW_TRACKING_SERVER_NAME = os.environ.get("MLFLOW_TRACKING_SERVER_NAME", "mlflow-staging-mlflow")
MODEL_NAME = "iris-model"


def load_iris_data():
    """Load and prepare Iris dataset"""
    logger.info("Loading Iris dataset")
    iris = load_iris()
    X = pd.DataFrame(iris.data, columns=iris.feature_names)
    y = pd.Series(iris.target, name="target")

    logger.info(f"Dataset shape: {X.shape}")
    logger.info(f"Classes: {iris.target_names}")
    return X, y, iris.target_names


def train_model(X, y):
    """Train RandomForest model with scaling"""
    logger.info("Training RandomForest model")

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Train model
    model = RandomForestClassifier(n_estimators=100, random_state=42, max_depth=5)
    model.fit(X_train_scaled, y_train)

    # Evaluate
    y_pred = model.predict(X_test_scaled)
    accuracy = accuracy_score(y_test, y_pred)

    logger.info(f"Model accuracy: {accuracy:.4f}")
    logger.info(f"Classification Report:\n{classification_report(y_test, y_pred)}")

    return model, scaler, accuracy


def discover_mlflow_tracking_server():
    """Get MLflow tracking server ARN by name"""
    try:
        # Use boto3 to get the specific MLflow tracking server
        region = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
        sagemaker_client = boto3.client("sagemaker", region_name=region)

        logger.info(f"Getting MLflow tracking server: {MLFLOW_TRACKING_SERVER_NAME}")
        
        # Get detailed information for the specific tracking server
        detail_response = sagemaker_client.describe_mlflow_tracking_server(
            TrackingServerName=MLFLOW_TRACKING_SERVER_NAME
        )
        
        # For SageMaker MLflow, we need the ARN, not the URL
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
    """Setup MLflow tracking"""
    tracking_uri = MLFLOW_TRACKING_URI

    # If no URI provided via environment, try to discover it
    if not tracking_uri:
        tracking_uri = discover_mlflow_tracking_server()

    if tracking_uri:
        mlflow.set_tracking_uri(tracking_uri)
        if tracking_uri.startswith("arn:"):
            logger.info(f"MLflow ARN: {tracking_uri}")
        else:
            logger.info(f"MLflow URI: {tracking_uri}")
    else:
        logger.warning("No MLflow tracking URI/ARN available - running without MLflow")
        return False

    mlflow.set_experiment("iris-model-training")
    return True


def save_to_mlflow(model, scaler, accuracy, class_names):
    """Save model to MLflow"""
    logger.info("Saving model to MLflow")

    with mlflow.start_run():
        # Log parameters
        mlflow.log_param("model_type", "RandomForestClassifier")
        mlflow.log_param("n_estimators", 100)
        mlflow.log_param("max_depth", 5)
        mlflow.log_param("dataset", "iris")
        mlflow.log_param("training_date", datetime.now().isoformat())
        
        # Log metrics
        mlflow.log_metric("accuracy", accuracy)

        # Create a model with preprocessing
        class IrisModel:
            def __init__(self, model, scaler, class_names):
                self.model = model
                self.scaler = scaler
                self.class_names = class_names

            def predict(self, X):
                X_scaled = self.scaler.transform(X)
                predictions = self.model.predict(X_scaled)
                return predictions

        # Wrap model with preprocessing
        wrapped_model = IrisModel(model, scaler, class_names)

        # Log model
        mlflow.sklearn.log_model(
            wrapped_model, "model", registered_model_name=MODEL_NAME
        )

        logger.info(f"Model saved to MLflow as '{MODEL_NAME}'")


def save_local_artifacts(model, scaler):
    """Save model artifacts locally for SageMaker"""
    logger.info(f"Saving artifacts to {MODEL_DIR}")

    try:
        # Ensure directory exists with proper permissions
        os.makedirs(MODEL_DIR, mode=0o755, exist_ok=True)
        
        # Save model and scaler
        joblib.dump(model, os.path.join(MODEL_DIR, "model.joblib"))
        joblib.dump(scaler, os.path.join(MODEL_DIR, "scaler.joblib"))
        
        logger.info("Local artifacts saved")
    except PermissionError as e:
        logger.warning(f"Permission denied saving to {MODEL_DIR}: {e}")
        # Try alternative output location
        alt_dir = "/tmp/model_output"
        logger.info(f"Trying alternative location: {alt_dir}")
        os.makedirs(alt_dir, mode=0o755, exist_ok=True)
        joblib.dump(model, os.path.join(alt_dir, "model.joblib"))
        joblib.dump(scaler, os.path.join(alt_dir, "scaler.joblib"))
        logger.info(f"Artifacts saved to alternative location: {alt_dir}")
    except Exception as e:
        logger.error(f"Failed to save local artifacts: {e}")
        # Don't fail the entire training job for local artifact saving
        logger.warning("Continuing training without local artifacts")


def main():
    """Main training function"""
    logger.info("Starting Iris model training")

    try:
        # Setup MLflow
        mlflow_available = setup_mlflow()

        # Load data
        X, y, class_names = load_iris_data()
        
        # Train model
        model, scaler, accuracy = train_model(X, y)

        # Save to MLflow if available
        if mlflow_available:
            save_to_mlflow(model, scaler, accuracy, class_names)
        else:
            logger.warning("Skipping MLflow logging - no tracking server available")

        # Save local artifacts
        save_local_artifacts(model, scaler)

        logger.info("Training completed successfully!")
        
    except Exception as e:
        logger.error(f"Training failed: {e}")
        raise


if __name__ == "__main__":
    main()
