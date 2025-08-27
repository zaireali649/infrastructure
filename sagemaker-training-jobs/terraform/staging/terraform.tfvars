# SageMaker Training Jobs - Staging Environment Configuration

# Core Configuration
project_name = "ml-platform"
environment  = "staging"
aws_region   = "us-east-1"

# Training Job Configuration
training_image           = "763104351884.dkr.ecr.us-east-1.amazonaws.com/sklearn-learn:1.0-1-cpu-py3"
training_job_name_prefix = "ml-platform-staging-training"

# Instance Configuration
instance_type       = "ml.m5.large"
instance_count      = 1
volume_size_gb      = 30
max_runtime_seconds = 3600  # 1 hour

# Data Configuration - Update these paths with your actual S3 bucket
input_data_config = [
  {
    ChannelName = "training"
    DataSource = {
      S3DataSource = {
        S3DataType = "S3Prefix"
        S3Uri      = "s3://ml-platform-staging-ml-bucket/datasets/training/"
      }
    }
    ContentType = "text/csv"
    InputMode   = "File"
  }
]

output_data_s3_path = "s3://ml-platform-staging-ml-bucket/training-outputs/"
# s3_bucket_arn will be populated from the SageMaker Studio module output

# Scheduling Configuration
enable_scheduling   = true
schedule_expression = "cron(0 3 * * ? *)"  # Daily at 3 AM UTC
schedule_enabled    = false  # Start disabled for initial testing

# MLflow Integration - These will be populated from the MLflow module
enable_mlflow_integration = true
# mlflow_tracking_server_arn and mlflow_tracking_uri will be set from module outputs

# Hyperparameters for sklearn RandomForest example
hyperparameters = {
  max_depth     = "5"
  n_estimators  = "100"
  random_state  = "42"
  criterion     = "gini"
  max_features  = "auto"
}

# Environment Variables
environment_variables = {
  MODEL_NAME       = "staging-classifier"
  MODEL_VERSION    = "1.0"
  LOG_LEVEL        = "INFO"
  PYTHON_PATH      = "/opt/ml/code"
  SAGEMAKER_REGION = "us-east-1"
}

# Cost Optimization (disabled for staging)
enable_spot_training = false

# Lambda Launcher (disabled for basic setup)
enable_custom_launcher = false

# Network Configuration (using default VPC for staging)
enable_network_isolation = false

# Tags
tags = {
  Team               = "ML-Engineering"
  Environment        = "staging"
  Project            = "ml-platform"
  CostCenter         = "Engineering"
  DataClassification = "Internal"
  Owner              = "ml-team"
  Purpose            = "automated-training"
}
