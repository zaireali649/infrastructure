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
    """Dynamically discover MLflow tracking server"""
    try:
        # Use boto3 to find the MLflow tracking server
        sagemaker_client = boto3.client("sagemaker")

        # List MLflow tracking servers
        response = sagemaker_client.list_mlflow_tracking_servers()

        # Find the staging MLflow server
        for server in response["TrackingServerSummaries"]:
            if "staging" in server["TrackingServerName"].lower():
                tracking_url = server["TrackingServerUrl"]
                logger.info(f"Discovered MLflow tracking server: {tracking_url}")
                return tracking_url

        # If no staging server found, try to find any MLflow server
        if response["TrackingServerSummaries"]:
            tracking_url = response["TrackingServerSummaries"][0]["TrackingServerUrl"]
            logger.info(f"Using first available MLflow tracking server: {tracking_url}")
            return tracking_url

        logger.warning("No MLflow tracking servers found")
        return None

    except Exception as e:
        logger.warning(f"Failed to discover MLflow tracking server: {e}")
        return None


def setup_mlflow():
    """Setup MLflow tracking"""
    tracking_uri = MLFLOW_TRACKING_URI

    # If no URI provided via environment, try to discover it
    if not tracking_uri:
        tracking_uri = discover_mlflow_tracking_server()

    if tracking_uri:
        mlflow.set_tracking_uri(tracking_uri)
        logger.info(f"MLflow URI: {tracking_uri}")
    else:
        logger.warning("No MLflow tracking URI available - running without MLflow")
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

    os.makedirs(MODEL_DIR, exist_ok=True)

    # Save model and scaler
    joblib.dump(model, os.path.join(MODEL_DIR, "model.joblib"))
    joblib.dump(scaler, os.path.join(MODEL_DIR, "scaler.joblib"))

    logger.info("Local artifacts saved")


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
