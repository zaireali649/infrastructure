# SageMaker Training Jobs - Staging Environment
# This configuration creates scheduled SageMaker training jobs with MLflow integration

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
  region = var.aws_region

  default_tags {
    tags = {
      Environment        = var.environment
      Project           = var.project_name
      ManagedBy         = "terraform"
      Service           = "sagemaker-training"
      TerraformModule   = "sagemaker-training-jobs"
    }
  }
}

# Data sources for existing infrastructure
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Data source for existing SageMaker Studio resources (if available)
data "aws_sagemaker_domain" "existing" {
  count       = var.existing_sagemaker_domain_name != null ? 1 : 0
  domain_name = var.existing_sagemaker_domain_name
}

# Main SageMaker Training Jobs Module
module "sagemaker_training_jobs" {
  source = "../../../terraform/module/sagemaker-training-jobs"

  project_name    = var.project_name
  environment     = var.environment
  
  # Training configuration
  training_image              = var.training_image
  training_job_name_prefix    = var.training_job_name_prefix
  training_input_mode         = var.training_input_mode
  
  # Instance configuration
  instance_type       = var.instance_type
  instance_count      = var.instance_count
  volume_size_gb      = var.volume_size_gb
  max_runtime_seconds = var.max_runtime_seconds

  # Data configuration
  input_data_config   = var.input_data_config
  output_data_s3_path = var.output_data_s3_path
  s3_bucket_arn       = var.s3_bucket_arn

  # Scheduling configuration
  enable_scheduling   = var.enable_scheduling
  schedule_expression = var.schedule_expression
  schedule_enabled    = var.schedule_enabled

  # MLflow integration
  mlflow_tracking_server_arn = var.mlflow_tracking_server_arn
  mlflow_tracking_uri        = var.mlflow_tracking_uri
  enable_mlflow_integration  = var.enable_mlflow_integration

  # Hyperparameters and environment
  hyperparameters       = var.hyperparameters
  environment_variables = var.environment_variables

  # Cost optimization
  enable_spot_training = var.enable_spot_training
  checkpoint_config    = var.checkpoint_config

  # Advanced configuration
  enable_custom_launcher      = var.enable_custom_launcher
  lambda_zip_path            = var.lambda_zip_path
  lambda_handler             = var.lambda_handler
  lambda_runtime             = var.lambda_runtime
  lambda_environment_variables = var.lambda_environment_variables
  
  # Network configuration
  vpc_config                = var.vpc_config
  enable_network_isolation  = var.enable_network_isolation

  # Monitoring
  profiler_config       = var.profiler_config
  debugger_hook_config  = var.debugger_hook_config

  # IAM configuration
  additional_training_role_policies = var.additional_training_role_policies

  # Tags
  tags = var.tags
}
