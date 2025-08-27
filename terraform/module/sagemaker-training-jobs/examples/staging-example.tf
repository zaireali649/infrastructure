# Example SageMaker Training Jobs Module Usage for Staging Environment
# This example shows how to integrate the training jobs module with existing SageMaker Studio and MLflow infrastructure

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73.0"
    }
  }
}

# Local variables for consistent naming
locals {
  project_name        = "ml-pipeline"
  environment         = "staging"
  bucket_name_suffix  = "alice-staging"
  
  common_tags = {
    Environment        = "staging"
    Project           = "ml-pipeline"
    Team              = "ML-Engineering"
    ManagedBy         = "terraform"
    CostCenter        = "Engineering"
    DataClassification = "Internal"
  }
}

# Data sources for existing infrastructure
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Example: SageMaker Studio Module (assuming it exists)
module "sagemaker_studio" {
  source = "../../sagemaker-studio"

  project_name        = local.project_name
  environment         = local.environment
  bucket_name_suffix  = local.bucket_name_suffix
  vpc_id              = data.aws_vpc.default.id
  subnet_ids          = data.aws_subnets.default.ids

  tags = local.common_tags
}

# Example: MLflow Module (assuming it exists)
module "mlflow" {
  source = "../../mlflow"

  project_name       = local.project_name
  environment        = local.environment
  bucket_name_suffix = local.bucket_name_suffix

  # Use the same S3 bucket as SageMaker Studio
  create_s3_bucket   = false
  artifact_store_uri = "s3://${module.sagemaker_studio.s3_bucket_name}"

  tags = local.common_tags
}

# Basic Training Job Example
module "basic_training_job" {
  source = "../"  # Points to the parent module

  project_name    = local.project_name
  environment     = local.environment
  
  # Training configuration
  training_image      = "763104351884.dkr.ecr.us-east-1.amazonaws.com/sklearn-learn:1.0-1-cpu-py3"  # Built-in SageMaker image
  instance_type       = "ml.m5.large"
  instance_count      = 1
  volume_size_gb      = 30
  max_runtime_seconds = 3600  # 1 hour

  # Data configuration
  input_data_config = [
    {
      ChannelName = "training"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = "s3://${module.sagemaker_studio.s3_bucket_name}/datasets/training/"
        }
      }
      ContentType = "text/csv"
      InputMode   = "File"
    }
  ]
  
  output_data_s3_path = "s3://${module.sagemaker_studio.s3_bucket_name}/models/basic-training/"
  s3_bucket_arn       = module.sagemaker_studio.s3_bucket_arn

  # Scheduling - run daily at 3 AM UTC
  schedule_expression = "cron(0 3 * * ? *)"
  schedule_enabled    = true

  # MLflow integration
  mlflow_tracking_server_arn = module.mlflow.tracking_server_arn
  mlflow_tracking_uri        = module.mlflow.tracking_server_url
  enable_mlflow_integration  = true

  # Basic hyperparameters
  hyperparameters = {
    max_depth     = "5"
    n_estimators  = "100"
    random_state  = "42"
  }

  # Environment variables
  environment_variables = {
    MODEL_NAME = "basic-classifier"
    VERSION    = "1.0"
    LOG_LEVEL  = "INFO"
  }

  tags = local.common_tags
}

# Advanced Training Job Example with GPU and Distributed Training
module "advanced_training_job" {
  source = "../"

  project_name    = "${local.project_name}-advanced"
  environment     = local.environment
  
  # Advanced training configuration
  training_image      = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-training:1.12-gpu-py39"
  instance_type       = "ml.p3.2xlarge"  # GPU instance
  instance_count      = 2               # Distributed training
  volume_size_gb      = 100
  max_runtime_seconds = 7200           # 2 hours

  # Multiple data channels
  input_data_config = [
    {
      ChannelName = "training"
      DataSource = {
        S3DataSource = {
          S3DataType             = "S3Prefix"
          S3Uri                  = "s3://${module.sagemaker_studio.s3_bucket_name}/datasets/training/"
          S3DataDistributionType = "ShardedByS3Key"  # For distributed training
        }
      }
      ContentType = "application/x-parquet"
      InputMode   = "File"
    },
    {
      ChannelName = "validation"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = "s3://${module.sagemaker_studio.s3_bucket_name}/datasets/validation/"
        }
      }
      ContentType = "application/x-parquet"
      InputMode   = "File"
    }
  ]
  
  output_data_s3_path = "s3://${module.sagemaker_studio.s3_bucket_name}/models/advanced-training/"
  s3_bucket_arn       = module.sagemaker_studio.s3_bucket_arn

  # Cost optimization with spot instances
  enable_spot_training = true
  checkpoint_config = {
    S3Uri     = "s3://${module.sagemaker_studio.s3_bucket_name}/checkpoints/"
    LocalPath = "/opt/ml/checkpoints"
  }

  # Weekly schedule - every Sunday at 2 AM UTC
  schedule_expression = "cron(0 2 ? * SUN *)"
  schedule_enabled    = true

  # MLflow integration
  mlflow_tracking_server_arn = module.mlflow.tracking_server_arn
  mlflow_tracking_uri        = module.mlflow.tracking_server_url
  enable_mlflow_integration  = true

  # Deep learning hyperparameters
  hyperparameters = {
    epochs        = "50"
    learning_rate = "0.001"
    batch_size    = "64"
    optimizer     = "adam"
    dropout       = "0.2"
    hidden_size   = "512"
  }

  # Environment variables for advanced training
  environment_variables = {
    MODEL_NAME     = "advanced-neural-network"
    VERSION        = "2.0"
    LOG_LEVEL      = "DEBUG"
    CUDA_VISIBLE_DEVICES = "0,1"
    NCCL_DEBUG     = "INFO"
  }

  # Monitoring and profiling
  profiler_config = {
    S3OutputPath                    = "s3://${module.sagemaker_studio.s3_bucket_name}/profiler/"
    ProfilingIntervalInMilliseconds = 500
    ProfilingParameters = {
      DataloaderProfilingConfig_DisableFramework = "false"
    }
  }

  debugger_hook_config = {
    S3OutputPath = "s3://${module.sagemaker_studio.s3_bucket_name}/debugger/"
    LocalPath    = "/opt/ml/output/tensors"
    HookParameters = {
      save_interval = "100"
      include_regex = ".*gradient.*"
    }
  }

  tags = merge(local.common_tags, {
    TrainingType = "Advanced"
    GPUEnabled   = "true"
    Distributed  = "true"
  })
}

# Example with Custom Docker Image (ECR)
module "custom_image_training" {
  source = "../"

  project_name    = "${local.project_name}-custom"
  environment     = local.environment
  
  # Custom training image (replace with your ECR URI)
  training_image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-custom-training:latest"
  instance_type       = "ml.m5.xlarge"
  instance_count      = 1
  volume_size_gb      = 50
  max_runtime_seconds = 1800  # 30 minutes

  # Single channel for custom algorithm
  input_data_config = [
    {
      ChannelName = "input"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = "s3://${module.sagemaker_studio.s3_bucket_name}/custom-data/"
        }
      }
      ContentType     = "application/json"
      CompressionType = "Gzip"
      InputMode       = "File"
    }
  ]
  
  output_data_s3_path = "s3://${module.sagemaker_studio.s3_bucket_name}/models/custom-training/"
  s3_bucket_arn       = module.sagemaker_studio.s3_bucket_arn

  # Run every 6 hours
  schedule_expression = "rate(6 hours)"
  schedule_enabled    = true

  # MLflow integration
  mlflow_tracking_server_arn = module.mlflow.tracking_server_arn
  mlflow_tracking_uri        = module.mlflow.tracking_server_url
  enable_mlflow_integration  = true

  # Custom algorithm parameters
  hyperparameters = {
    algorithm_type   = "custom_ensemble"
    feature_selection = "true"
    cross_validation = "5"
    scoring_metric   = "f1_macro"
  }

  # Custom environment variables
  environment_variables = {
    CUSTOM_CONFIG_PATH = "/opt/ml/input/config/custom_config.json"
    PREPROCESSING_TYPE = "advanced"
    OUTPUT_FORMAT      = "pickle"
  }

  tags = merge(local.common_tags, {
    ImageType = "Custom"
    Algorithm = "Ensemble"
  })
}

# Outputs for reference
output "basic_training_role_arn" {
  description = "ARN of the basic training job IAM role"
  value       = module.basic_training_job.training_role_arn
}

output "advanced_training_schedule_arn" {
  description = "ARN of the advanced training schedule rule"
  value       = module.advanced_training_job.schedule_rule_arn
}

output "custom_training_configuration" {
  description = "Configuration summary of custom training job"
  value       = module.custom_image_training.training_job_configuration
}

output "mlflow_integration_status" {
  description = "MLflow integration status for all training jobs"
  value = {
    basic_mlflow_enabled    = module.basic_training_job.mlflow_integration_enabled
    advanced_mlflow_enabled = module.advanced_training_job.mlflow_integration_enabled
    custom_mlflow_enabled   = module.custom_image_training.mlflow_integration_enabled
    mlflow_tracking_uri     = module.mlflow.tracking_server_url
  }
}
