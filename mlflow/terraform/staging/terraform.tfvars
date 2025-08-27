# SageMaker Managed MLflow Staging Environment Configuration
# This file contains the configuration for deploying managed MLflow for user 'zali'

# AWS Configuration
aws_region = "us-east-1" # Update this to your preferred region

# Project Configuration
bucket_name_suffix = "zali-staging" # This will create bucket: mlflow-staging-mlflow-artifacts-zali-staging

# MLflow Configuration
mlflow_version                   = "3.0"      # Latest stable version
automatic_model_registration     = true         # Enable automatic model registration
weekly_maintenance_window_start  = "Tue:03:30"  # Tuesday 3:30 AM maintenance window

# S3 Configuration - Choose one option:

# Option 1: Create new S3 bucket (default)
create_s3_bucket = true
# artifact_store_uri = null  # Will be auto-generated

# Option 2: Use existing S3 bucket (e.g., from SageMaker Studio)
# create_s3_bucket = false
# artifact_store_uri = "s3://sagemaker-studio-staging-ml-bucket-zali-staging"

# Security Configuration
# kms_key_id = null  # Use default S3 encryption, or specify KMS key ARN for enhanced security

# Custom Resource Names (optional - will auto-generate if not specified)
# custom_tracking_server_name = "zali-mlflow-staging"
# custom_mlflow_role_name = "zali-mlflow-staging-role"

# Additional IAM Policies (uncomment if you need additional permissions)
# additional_role_policies = [
#   "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
# ]

# Additional Tags
additional_tags = {
  Owner       = "zali"
  Team        = "ML-Engineering"
  CostCenter  = "Engineering"
  Environment = "staging"
  Purpose     = "ml-experiment-tracking"
  Service     = "sagemaker-mlflow"
  Integration = "sagemaker-studio"
}

# GitHub Configuration (for CI/CD tracking)
github_repository = "infrastructure"
github_workflow   = "mlflow-deploy"
