# Iris Training Pipeline

Simple SageMaker training pipeline for the Iris dataset.

## Overview

This pipeline:
- Loads the Iris dataset from scikit-learn
- Trains a RandomForest model with StandardScaler preprocessing
- Saves the model to SageMaker managed MLflow
- Runs weekly via SageMaker scheduled training jobs

## Files

- `app/train.py` - Main training script
- `app/__init__.py` - Package initialization
- `Dockerfile` - Container definition
- `requirements.txt` - Python dependencies
- `pyproject.toml` - Project configuration

## Environment Variables

- `MLFLOW_TRACKING_URI` - MLflow server URL
- `SM_MODEL_DIR` - SageMaker model output directory
- `SM_OUTPUT_DATA_DIR` - SageMaker output directory

## Model

- **Algorithm**: RandomForestClassifier
- **Preprocessing**: StandardScaler
- **Target**: Iris species classification
- **Registered Name**: `iris-model`