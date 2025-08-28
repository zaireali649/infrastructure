# Core Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, prod, etc.)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Training Job Configuration
variable "training_image_uri" {
  description = "ECR URI for the training container image"
  type        = string
}

variable "input_data_s3_path" {
  description = "S3 path for input training data"
  type        = string
}

variable "output_data_s3_path" {
  description = "S3 path for training job outputs"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for training data and outputs"
  type        = string
}

variable "input_content_type" {
  description = "Content type of input data"
  type        = string
  default     = "application/x-parquet"
}

# Instance Configuration
variable "instance_type" {
  description = "SageMaker instance type for training"
  type        = string
  default     = "ml.m5.large"
}

variable "instance_count" {
  description = "Number of instances for training"
  type        = number
  default     = 1
}

variable "volume_size_gb" {
  description = "Size of EBS volume in GB"
  type        = number
  default     = 30
}

variable "max_runtime_seconds" {
  description = "Maximum runtime for training job in seconds"
  type        = number
  default     = 3600
}

# MLflow Configuration
variable "mlflow_tracking_uri" {
  description = "MLflow tracking server URI"
  type        = string
}

# Hyperparameters and Environment
variable "hyperparameters" {
  description = "Hyperparameters for the training algorithm"
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Environment variables for the training container"
  type        = map(string)
  default     = {}
}

# Networking Configuration
variable "vpc_config" {
  description = "VPC configuration for training jobs"
  type = object({
    security_group_ids = list(string)
    subnet_ids        = list(string)
  })
  default = null
}

# Scheduling Configuration
variable "enable_scheduling" {
  description = "Whether to enable scheduled training pipeline execution"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "Cron expression for training schedule (e.g., weekly)"
  type        = string
  default     = "cron(0 2 ? * SUN *)"  # Weekly on Sunday at 2 AM UTC
}

variable "schedule_enabled" {
  description = "Whether the schedule rule is enabled"
  type        = bool
  default     = false
}