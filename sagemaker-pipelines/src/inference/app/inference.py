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
from datetime import datetime

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MLflow settings
MLFLOW_TRACKING_URI = os.environ.get("MLFLOW_TRACKING_URI")
MODEL_NAME = "iris-model"
OUTPUT_DIR = os.environ.get("SM_PROCESSING_OUTPUT_DIR", "/opt/ml/processing/output")


def setup_mlflow():
    """Setup MLflow tracking"""
    if MLFLOW_TRACKING_URI:
        mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
        logger.info(f"MLflow URI: {MLFLOW_TRACKING_URI}")


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
        setup_mlflow()

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
