# SageMaker Managed MLflow Staging Environment
# This configuration deploys SageMaker's managed MLflow tracking server

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

  # Remote state management (configure TF_BACKEND_BUCKET secret to enable)
  backend "s3" {
    # These values will be provided via -backend-config in CI/CD
    # bucket = "configured-via-backend-config"
    # key    = "configured-via-backend-config" 
    # region = "configured-via-backend-config"
  }
}

# Configure the AWS provider with explicit settings
provider "aws" {
  region = "us-east-1"
  
  # Explicit configuration to avoid provider issues
  default_tags {
    tags = local.common_tags
  }
  
  # Ensure consistent behavior
  retry_mode = "standard"
  max_retries = 3
}

# Data sources for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for consistent naming and tagging
locals {
  project_name = "mlflow"
  environment  = "staging"

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "zali"
    Repository  = "infrastructure"
    Service     = "sagemaker-mlflow"
    Team        = "ML-Engineering"
    CostCenter  = "Engineering"
    Purpose     = "ml-experiment-tracking"
    Integration = "sagemaker-studio"
  }
}

# SageMaker Managed MLflow module
module "mlflow" {
  source = "../../../terraform/module/mlflow"

  # Required parameters
  project_name       = local.project_name
  environment        = local.environment
  bucket_name_suffix = "zali-staging"

  # MLflow configuration
  tracking_server_name            = null  # Auto-generate: mlflow-staging-mlflow
  mlflow_version                 = "3.0.0"
  automatic_model_registration   = true
  weekly_maintenance_window_start = "TUE:03:30"

  # S3 configuration
  create_s3_bucket   = true
  artifact_store_uri = null  # Auto-generate S3 bucket
  kms_key_id        = null   # Use default S3 encryption

  # IAM configuration
  mlflow_role_name         = null  # Auto-generate: mlflow-staging-mlflow-role
  additional_role_policies = []

  tags = local.common_tags
}
