# Core Configuration Variables
variable "project_name" {
  description = "Name of the project/application"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
  validation {
    condition     = contains(["staging", "prod", "dev"], var.environment)
    error_message = "Environment must be one of: staging, prod, dev."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Pipeline Enablement
variable "enable_training_pipeline" {
  description = "Whether to enable the training pipeline"
  type        = bool
  default     = true
}

variable "enable_processing_pipeline" {
  description = "Whether to enable the processing pipeline"
  type        = bool
  default     = false
}

# Existing Infrastructure References
variable "vpc_id" {
  description = "ID of the existing VPC to use (leave empty for no VPC)"
  type        = string
  default     = ""
  validation {
    condition = var.vpc_id == "" || can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be empty or a valid VPC identifier starting with 'vpc-'."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for SageMaker jobs (leave empty for no VPC)"
  type        = list(string)
  default     = []
  validation {
    condition = length(var.subnet_ids) == 0 || alltrue([
      for id in var.subnet_ids : can(regex("^subnet-", id))
    ])
    error_message = "All subnet IDs must be valid subnet identifiers starting with 'subnet-'."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs for SageMaker jobs"
  type        = list(string)
  default     = []
  validation {
    condition = length(var.security_group_ids) == 0 || alltrue([
      for id in var.security_group_ids : can(regex("^sg-", id))
    ])
    error_message = "All security group IDs must be valid security group identifiers starting with 'sg-'."
  }
}

variable "sagemaker_security_group_id" {
  description = "ID of the existing SageMaker security group (for data source lookup)"
  type        = string
  default     = ""
}

# S3 Configuration
variable "s3_bucket_arn" {
  description = "ARN of the existing S3 bucket for storing data and models"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:s3:::", var.s3_bucket_arn))
    error_message = "S3 bucket ARN must be a valid S3 bucket ARN."
  }
}

variable "input_data_s3_path" {
  description = "S3 path for training input data (required if training pipeline enabled)"
  type        = string
  default     = ""
  validation {
    condition = var.input_data_s3_path == "" || can(regex("^s3://", var.input_data_s3_path))
    error_message = "Input data S3 path must be empty or start with s3://."
  }
}

variable "model_output_s3_path" {
  description = "S3 path for model output (required if training pipeline enabled)"
  type        = string
  default     = ""
  validation {
    condition = var.model_output_s3_path == "" || can(regex("^s3://", var.model_output_s3_path))
    error_message = "Model output S3 path must be empty or start with s3://."
  }
}

variable "inference_input_s3_path" {
  description = "S3 path for inference input data (required if processing pipeline enabled)"
  type        = string
  default     = ""
  validation {
    condition = var.inference_input_s3_path == "" || can(regex("^s3://", var.inference_input_s3_path))
    error_message = "Inference input S3 path must be empty or start with s3://."
  }
}

variable "inference_output_s3_path" {
  description = "S3 path for inference output data (required if processing pipeline enabled)"
  type        = string
  default     = ""
  validation {
    condition = var.inference_output_s3_path == "" || can(regex("^s3://", var.inference_output_s3_path))
    error_message = "Inference output S3 path must be empty or start with s3://."
  }
}

# Container Image Configuration (existing ECR repositories)
variable "training_image_uri" {
  description = "URI of the existing Docker image for training jobs (required if training pipeline enabled)"
  type        = string
  default     = ""
  validation {
    condition = var.training_image_uri == "" || can(regex("^[0-9]+\\.dkr\\.ecr\\.", var.training_image_uri))
    error_message = "Training image URI must be empty or a valid ECR URI."
  }
}

variable "inference_image_uri" {
  description = "URI of the existing Docker image for inference jobs (required if processing pipeline enabled)"
  type        = string
  default     = ""
  validation {
    condition = var.inference_image_uri == "" || can(regex("^[0-9]+\\.dkr\\.ecr\\.", var.inference_image_uri))
    error_message = "Inference image URI must be empty or a valid ECR URI."
  }
}

# Training Configuration
variable "training_instance_type" {
  description = "Instance type for training jobs"
  type        = string
  default     = "ml.m5.large"
}

variable "training_instance_count" {
  description = "Number of instances for training jobs"
  type        = number
  default     = 1
  validation {
    condition     = var.training_instance_count >= 1
    error_message = "Training instance count must be at least 1."
  }
}

variable "training_volume_size" {
  description = "EBS volume size in GB for training jobs"
  type        = number
  default     = 30
  validation {
    condition     = var.training_volume_size >= 1 && var.training_volume_size <= 16384
    error_message = "Training volume size must be between 1 and 16384 GB."
  }
}

variable "training_max_runtime_seconds" {
  description = "Maximum runtime in seconds for training jobs"
  type        = number
  default     = 3600
  validation {
    condition     = var.training_max_runtime_seconds >= 1
    error_message = "Training max runtime must be at least 1 second."
  }
}

variable "training_hyperparameters" {
  description = "Hyperparameters for training jobs"
  type        = map(string)
  default     = {}
}

variable "training_environment_variables" {
  description = "Environment variables for training jobs"
  type        = map(string)
  default     = {}
}

variable "mlflow_tracking_server_name" {
  description = "Name of the MLflow tracking server"
  type        = string
}

variable "training_input_content_type" {
  description = "Content type for training input data"
  type        = string
  default     = "application/x-parquet"
}

variable "training_pipeline_display_name" {
  description = "Display name for the training pipeline"
  type        = string
  default     = "Training Pipeline"
}

# Inference/Processing Configuration
variable "inference_instance_type" {
  description = "Instance type for inference/processing jobs"
  type        = string
  default     = "ml.m5.large"
}

variable "inference_instance_count" {
  description = "Number of instances for inference/processing jobs"
  type        = number
  default     = 1
  validation {
    condition     = var.inference_instance_count >= 1
    error_message = "Inference instance count must be at least 1."
  }
}

variable "inference_volume_size" {
  description = "EBS volume size in GB for inference/processing jobs"
  type        = number
  default     = 30
  validation {
    condition     = var.inference_volume_size >= 1 && var.inference_volume_size <= 16384
    error_message = "Inference volume size must be between 1 and 16384 GB."
  }
}

variable "inference_max_runtime_seconds" {
  description = "Maximum runtime in seconds for inference/processing jobs"
  type        = number
  default     = 1800
  validation {
    condition     = var.inference_max_runtime_seconds >= 1
    error_message = "Inference max runtime must be at least 1 second."
  }
}

variable "processing_environment_variables" {
  description = "Environment variables for processing jobs"
  type        = map(string)
  default     = {}
}

variable "processing_pipeline_display_name" {
  description = "Display name for the processing pipeline"
  type        = string
  default     = "Processing Pipeline"
}

# Scheduling Configuration
variable "enable_training_schedule" {
  description = "Whether to enable scheduled training pipeline execution"
  type        = bool
  default     = false
}

variable "training_schedule_expression" {
  description = "Cron expression for training pipeline schedule"
  type        = string
  default     = "cron(0 2 ? * SUN *)"
  validation {
    condition     = can(regex("^(rate|cron)\\(", var.training_schedule_expression))
    error_message = "Training schedule expression must be a valid rate() or cron() expression."
  }
}

variable "training_schedule_enabled" {
  description = "Whether the training schedule is initially enabled"
  type        = bool
  default     = false
}

variable "enable_processing_schedule" {
  description = "Whether to enable scheduled processing pipeline execution"
  type        = bool
  default     = false
}

variable "processing_schedule_expression" {
  description = "Cron expression for processing pipeline schedule"
  type        = string
  default     = "cron(0 6 * * ? *)"
  validation {
    condition     = can(regex("^(rate|cron)\\(", var.processing_schedule_expression))
    error_message = "Processing schedule expression must be a valid rate() or cron() expression."
  }
}

variable "processing_schedule_enabled" {
  description = "Whether the processing schedule is initially enabled"
  type        = bool
  default     = false
}