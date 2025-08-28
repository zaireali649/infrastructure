# Core Configuration Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "iris-ml"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
  validation {
    condition     = contains(["staging", "prod", "dev"], var.environment)
    error_message = "Environment must be one of: staging, prod, dev."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Owner       = "ml-team"
    Project     = "iris-classification"
    Environment = "staging"
  }
}

# S3 Configuration
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for ML data and models"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.s3_bucket_name))
    error_message = "S3 bucket name must contain only lowercase letters, numbers, and hyphens."
  }
}

# Container Images
variable "training_image_uri" {
  description = "ECR URI for the training container"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+\\.dkr\\.ecr\\.", var.training_image_uri))
    error_message = "Training image URI must be a valid ECR URI."
  }
}

variable "inference_image_uri" {
  description = "ECR URI for the inference container"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+\\.dkr\\.ecr\\.", var.inference_image_uri))
    error_message = "Inference image URI must be a valid ECR URI."
  }
}

# MLflow Configuration
variable "mlflow_tracking_uri" {
  description = "MLflow tracking server URI"
  type        = string
  validation {
    condition     = can(regex("^https?://", var.mlflow_tracking_uri))
    error_message = "MLflow tracking URI must be a valid HTTP/HTTPS URL."
  }
}

# Scheduling Configuration
variable "enable_training_schedule" {
  description = "Whether to enable the weekly training schedule"
  type        = bool
  default     = true
}

variable "enable_inference_schedule" {
  description = "Whether to enable the daily inference schedule"
  type        = bool
  default     = true
}

# Training Configuration (optional overrides)
variable "training_instance_type" {
  description = "Instance type for training jobs"
  type        = string
  default     = "ml.m5.large"
}

variable "inference_instance_type" {
  description = "Instance type for inference jobs"
  type        = string
  default     = "ml.m5.large"
}

# Regional Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}
