# SageMaker Pipelines - Production Environment
# Composes remote modules via ?ref=tag for training and inference pipelines

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73.0"
    }
  }

  # Production backend configuration
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "sagemaker-pipelines/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get existing MLflow tracking server
data "aws_sagemaker_mlflow_tracking_server" "existing" {
  tracking_server_name = var.mlflow_tracking_server_name
}

# Local values for resource configuration
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    Team        = "ML-Engineering"
    ManagedBy   = "terraform"
    CostCenter  = "data-science"
  }
}

# SageMaker Training Jobs Module (referenced via git tag)
module "sagemaker_training_jobs" {
  source = "git::https://github.com/your-org/terraform-modules.git//sagemaker-training-jobs?ref=v1.0.0"

  # Core configuration
  project_name = var.project_name
  environment  = var.environment
  
  # Training configuration
  training_image              = var.training_image_uri
  training_job_name_prefix    = "${local.name_prefix}-training"
  training_input_mode         = "File"
  
  # Production instance configuration
  instance_type       = var.training_instance_type
  instance_count      = var.training_instance_count
  volume_size_gb      = var.training_volume_size_gb
  max_runtime_seconds = var.max_runtime_seconds

  # Data configuration
  input_data_config = [
    {
      ChannelName = "training"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = var.training_data_s3_uri
        }
      }
      ContentType = "application/x-parquet"
      InputMode   = "File"
    }
  ]
  
  output_data_s3_path = var.model_output_s3_uri
  s3_bucket_arn       = var.s3_bucket_arn

  # Production scheduling configuration
  enable_scheduling   = var.enable_training_schedule
  schedule_expression = var.training_schedule_expression
  schedule_enabled    = var.training_schedule_enabled

  # MLflow integration
  mlflow_tracking_server_arn = data.aws_sagemaker_mlflow_tracking_server.existing.arn
  mlflow_tracking_uri        = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
  enable_mlflow_integration  = true

  # Hyperparameters
  hyperparameters = var.training_hyperparameters

  # Environment variables
  environment_variables = merge(
    var.training_environment_variables,
    {
      MLFLOW_TRACKING_URI = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
      AWS_DEFAULT_REGION  = var.aws_region
      ENVIRONMENT         = var.environment
      OWNER               = var.owner
    }
  )

  # Pipeline configuration
  pipeline_description = "Production training pipeline for ${var.project_name}"

  # Tags
  tags = local.common_tags
}

# SageMaker Processing Jobs Module for Inference (referenced via git tag)
module "sagemaker_processing_jobs" {
  source = "git::https://github.com/your-org/terraform-modules.git//sagemaker-processing-jobs?ref=v1.0.0"

  # Core configuration
  project_name = var.project_name
  environment  = var.environment
  
  # Processing configuration
  processing_image            = var.inference_image_uri
  processing_job_name_prefix  = "${local.name_prefix}-inference"
  
  # Production instance configuration
  instance_type    = var.inference_instance_type
  instance_count   = var.inference_instance_count
  volume_size_gb   = var.inference_volume_size_gb

  # Data configuration
  input_data_config = [
    {
      ChannelName = "input"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = var.inference_input_s3_uri
        }
      }
      ContentType = "application/x-parquet"
    }
  ]
  
  output_data_config = [
    {
      ChannelName   = "output"
      S3OutputPath  = var.inference_output_s3_uri
    }
  ]

  # Production scheduling configuration
  enable_scheduling   = var.enable_inference_schedule
  schedule_expression = var.inference_schedule_expression
  schedule_enabled    = var.inference_schedule_enabled

  # Environment variables for Kafka integration
  environment_variables = merge(
    var.inference_environment_variables,
    {
      KAFKA_BOOTSTRAP_SERVERS = var.kafka_bootstrap_servers
      KAFKA_TOPIC            = var.kafka_output_topic
      KAFKA_SECURITY_PROTOCOL = var.kafka_security_protocol
      KAFKA_SASL_MECHANISM   = var.kafka_sasl_mechanism
      MLFLOW_TRACKING_URI    = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
      AWS_DEFAULT_REGION     = var.aws_region
      ENVIRONMENT            = var.environment
    }
  )

  # Pipeline configuration
  pipeline_description = "Production daily inference pipeline outputting to Kafka for ${var.project_name}"

  # Tags
  tags = local.common_tags
}

# ECR Repositories for custom images
resource "aws_ecr_repository" "training" {
  name                 = "${local.name_prefix}-training"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "inference" {
  name                 = "${local.name_prefix}-inference"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ECR lifecycle policies for production
resource "aws_ecr_lifecycle_policy" "training" {
  repository = aws_ecr_repository.training.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "inference" {
  repository = aws_ecr_repository.inference.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
