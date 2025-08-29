# SageMaker Pipelines Staging Environment
# Simple Iris ML Pipeline with Weekly Training and Daily Inference

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider with explicit settings
provider "aws" {
  region = local.aws_region
  
  # Explicit configuration to avoid provider issues
  default_tags {
    tags = merge(local.tags, {
      Project     = local.project_name
      Environment = local.environment
      ManagedBy   = "terraform"
      Component   = "sagemaker-pipelines"
    })
  }
  
  # Ensure consistent behavior
  retry_mode = "standard"
  max_retries = 3
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local configuration values
locals {
  # Core Configuration
  project_name = "iris-ml"
  environment  = "staging"
  aws_region   = "us-east-1"
  
  # Common tags
  tags = {
    Owner       = "ml-team"
    Project     = "iris-classification"
    Environment = "staging"
  }
  
  # S3 Configuration - Using MLflow artifacts bucket
  # This should match the bucket created by MLflow module
  s3_bucket_name = "mlflow-staging-mlflow-artifacts-zali-staging"  # MLflow artifacts bucket
  
  # Container Images - Update these URIs with your actual ECR repositories
  training_image_uri  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/ml-platform-staging-training:latest"
  inference_image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/ml-platform-staging-inference:latest"
  
  # MLflow Configuration
  mlflow_tracking_uri = "https://mlflow-staging-mlflow.${data.aws_region.current.name}.amazonaws.com"
  
  # Scheduling Configuration
  enable_training_schedule  = true
  enable_inference_schedule = true
  
  # Instance Configuration
  training_instance_type  = "ml.m5.large"
  inference_instance_type = "ml.m5.large"
}

# Get existing infrastructure from data sources
data "aws_s3_bucket" "ml_bucket" {
  bucket = local.s3_bucket_name
}

# Call the SageMaker Pipelines module
module "sagemaker_pipelines" {
  source = "../../../terraform/module/sagemaker-pipelines"

  # Core configuration
  project_name = local.project_name
  environment  = local.environment
  tags = merge(local.tags, {
    Project     = local.project_name
    Environment = local.environment
    Component   = "sagemaker-pipelines"
    ManagedBy   = "terraform"
  })

  # Pipeline enablement - both training and inference for Iris
  enable_training_pipeline   = true
  enable_processing_pipeline = true

  # S3 configuration
  s3_bucket_arn             = data.aws_s3_bucket.ml_bucket.arn
  input_data_s3_path        = "s3://${local.s3_bucket_name}/iris/input/"
  model_output_s3_path      = "s3://${local.s3_bucket_name}/iris/models/"
  inference_input_s3_path   = "s3://${local.s3_bucket_name}/iris/inference-input/"
  inference_output_s3_path  = "s3://${local.s3_bucket_name}/iris/inference-output/"

  # Container images - using the ECR repositories we built
  training_image_uri  = local.training_image_uri
  inference_image_uri = local.inference_image_uri

  # Training configuration for Iris model
  training_instance_type         = "ml.m5.large"
  training_instance_count        = 1
  training_volume_size          = 30
  training_max_runtime_seconds  = 1800  # 30 minutes
  training_input_content_type   = "text/csv"  # Since Iris will be CSV format

  # Training environment variables for MLflow
  training_environment_variables = {
    MLFLOW_TRACKING_URI = local.mlflow_tracking_uri
    ENVIRONMENT         = local.environment
    MODEL_NAME          = "iris-model"
  }

  # Training hyperparameters
  training_hyperparameters = {
    n_estimators = "100"
    max_depth    = "5"
    random_state = "42"
  }

  # Inference/Processing configuration
  inference_instance_type        = "ml.m5.large"
  inference_instance_count       = 1
  inference_volume_size         = 30
  inference_max_runtime_seconds = 1200  # 20 minutes

  # Processing environment variables
  processing_environment_variables = {
    MLFLOW_TRACKING_URI = local.mlflow_tracking_uri
    ENVIRONMENT         = local.environment
    MODEL_NAME          = "iris-model"
  }

  # Display names
  training_pipeline_display_name   = "Iris-Training-Pipeline"
  processing_pipeline_display_name = "Iris-Inference-Pipeline"

  # Scheduling - Weekly training (Sundays at 2 AM) and Daily inference (6 AM)
  enable_training_schedule     = true
  training_schedule_expression = "cron(0 2 ? * SUN *)"  # Weekly on Sunday at 2 AM UTC
  training_schedule_enabled    = local.enable_training_schedule

  enable_processing_schedule     = true
  processing_schedule_expression = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
  processing_schedule_enabled    = local.enable_inference_schedule

  # Network configuration (optional - using defaults for no VPC)
  vpc_id             = ""
  subnet_ids         = []
  security_group_ids = []
}
