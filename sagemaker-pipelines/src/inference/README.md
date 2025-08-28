# Iris Inference Pipeline

Simple SageMaker inference pipeline for the Iris model.

## Overview

This pipeline:
- Loads the trained Iris model from SageMaker managed MLflow
- Generates random data similar to Iris dataset
- Makes predictions and saves results
- Runs daily via SageMaker scheduled processing jobs

## Files

- `app/inference.py` - Main inference script
- `app/__init__.py` - Package initialization
- `Dockerfile` - Container definition
- `requirements.txt` - Python dependencies
- `pyproject.toml` - Project configuration

## Environment Variables

- `MLFLOW_TRACKING_URI` - MLflow server URL
- `SM_PROCESSING_OUTPUT_DIR` - SageMaker output directory

## Output

Results are saved as CSV files with:
- Input features (sepal/petal measurements)
- Numeric predictions (0, 1, 2)
- Class predictions (setosa, versicolor, virginica)
- Timestamp