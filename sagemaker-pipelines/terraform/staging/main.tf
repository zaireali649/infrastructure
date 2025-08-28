# SageMaker Pipelines - Staging Environment
# Uses the sagemaker-pipelines module with existing infrastructure

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = local.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get existing MLflow tracking server
data "aws_sagemaker_mlflow_tracking_server" "existing" {
  tracking_server_name = local.mlflow_tracking_server_name
}

# Get existing VPC (assuming it exists from mlflow setup)
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["*mlflow*"]
  }
}

# Get existing private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Get existing security group
data "aws_security_group" "sagemaker" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*sagemaker*"]
  }
}

# Local values - all configuration hardcoded here
locals {
  # Core configuration
  project_name = "ml-platform"
  environment  = "staging"
  owner       = "zali"
  aws_region  = "us-east-1"
  
  # MLflow configuration
  mlflow_tracking_server_name = "mlflow-staging-mlflow"
  
  # ECR and container configuration (existing repositories)
  account_id = data.aws_caller_identity.current.account_id
  training_image_uri  = "${local.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/${local.project_name}-${local.environment}-training:latest"
  inference_image_uri = "${local.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/${local.project_name}-${local.environment}-inference:latest"
  
  # S3 configuration (existing bucket)
  s3_bucket_name = "mlflow-${local.environment}-mlflow-artifacts-${local.owner}-${local.environment}"
  s3_bucket_arn  = "arn:aws:s3:::${local.s3_bucket_name}"
  
  # Data paths
  input_data_s3_path    = "s3://${local.s3_bucket_name}/datasets/training/"
  model_output_s3_path  = "s3://${local.s3_bucket_name}/models/"
  inference_input_s3_path  = "s3://${local.s3_bucket_name}/inference/input/"
  inference_output_s3_path = "s3://${local.s3_bucket_name}/inference/output/"
  
  # Kafka topic (handled in Python code, not infrastructure)
  kafka_topic = "poem-predictions-${local.environment}"
  
  # Scheduling configuration
  # Weekly training on Sundays at 2 AM UTC
  training_schedule_expression = "cron(0 2 ? * SUN *)"
  # Daily scoring at 6 AM UTC
  inference_schedule_expression = "cron(0 6 * * ? *)"
  
  # Instance configuration
  training_instance_type = "ml.m5.large"
  inference_instance_type = "ml.m5.large"
  
  # Training hyperparameters
  training_hyperparameters = {
    n_estimators    = "100"
    max_depth       = "10"
    random_state    = "42"
    test_size       = "0.2"
    learning_rate   = "0.1"
  }
  
  # Common tags
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    Owner       = local.owner
    Team        = "ML-Engineering"
    ManagedBy   = "terraform"
    Repository  = "infrastructure"
  }
}

# SageMaker Pipelines Module
module "sagemaker_pipelines" {
  source = "../../../terraform/module/sagemaker-pipelines"

  # Core configuration
  project_name = local.project_name
  environment  = local.environment

  # Pipeline configuration
  enable_training_pipeline   = true
  enable_processing_pipeline = true

  # Existing infrastructure references
  vpc_id             = data.aws_vpc.existing.id
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [data.aws_security_group.sagemaker.id]

  # S3 configuration (existing bucket)
  s3_bucket_arn           = local.s3_bucket_arn
  input_data_s3_path      = local.input_data_s3_path
  model_output_s3_path    = local.model_output_s3_path
  inference_input_s3_path = local.inference_input_s3_path
  inference_output_s3_path = local.inference_output_s3_path

  # Container image configuration (existing ECR repositories)
  training_image_uri  = local.training_image_uri
  inference_image_uri = local.inference_image_uri

  # Training configuration
  training_instance_type      = local.training_instance_type
  training_instance_count     = 1
  training_volume_size        = 30
  training_max_runtime_seconds = 3600
  training_hyperparameters    = local.training_hyperparameters
  training_pipeline_display_name = "Weekly Poem Model Training Pipeline"

  # Training environment variables
  training_environment_variables = {
    MLFLOW_TRACKING_URI = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
    AWS_DEFAULT_REGION  = local.aws_region
    ENVIRONMENT         = local.environment
    OWNER              = local.owner
  }

  # Processing/Inference configuration
  inference_instance_type        = local.inference_instance_type
  inference_instance_count       = 1
  inference_volume_size          = 30
  inference_max_runtime_seconds  = 1800
  processing_pipeline_display_name = "Daily Scoring Pipeline"

  # Processing environment variables (Kafka handled in Python code)
  processing_environment_variables = {
    MLFLOW_TRACKING_URI = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
    MLFLOW_MODEL_URI   = "models:/poem-model/Production"
    INPUT_S3_PREFIX    = local.inference_input_s3_path
    KAFKA_TOPIC        = local.kafka_topic
    AWS_DEFAULT_REGION = local.aws_region
    ENVIRONMENT        = local.environment
  }

  # Scheduling configuration
  enable_training_schedule     = true
  training_schedule_expression = local.training_schedule_expression
  training_schedule_enabled    = false  # Start disabled for testing

  enable_processing_schedule     = true
  processing_schedule_expression = local.inference_schedule_expression
  processing_schedule_enabled    = false  # Start disabled for testing

  # Tags
  tags = local.common_tags
}

# Outputs defined in outputs.tf