# SageMaker Managed MLflow Staging Environment
# This configuration deploys SageMaker's managed MLflow tracking server

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"  # Pin to stable version to avoid provider issues
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
  region = var.aws_region
  
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

  common_tags = merge(var.additional_tags, {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "zali"
    Repository  = "infrastructure"
    Service     = "sagemaker-mlflow"
  })
}

# SageMaker Managed MLflow module
module "mlflow" {
  source = "../../../terraform/module/mlflow"

  # Required parameters
  project_name       = local.project_name
  environment        = local.environment
  bucket_name_suffix = var.bucket_name_suffix

  # MLflow configuration
  tracking_server_name            = var.custom_tracking_server_name
  mlflow_version                 = var.mlflow_version
  automatic_model_registration   = var.automatic_model_registration
  weekly_maintenance_window_start = var.weekly_maintenance_window_start

  # S3 configuration
  create_s3_bucket   = var.create_s3_bucket
  artifact_store_uri = var.artifact_store_uri
  kms_key_id        = var.kms_key_id

  # IAM configuration
  mlflow_role_name         = var.custom_mlflow_role_name
  additional_role_policies = var.additional_role_policies

  tags = local.common_tags
}
