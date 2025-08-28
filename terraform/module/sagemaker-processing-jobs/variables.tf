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

# Processing Job Configuration
variable "processing_image_uri" {
  description = "ECR URI for the processing container image"
  type        = string
}

variable "input_data_s3_path" {
  description = "S3 path for input data to be processed"
  type        = string
}

variable "output_data_s3_path" {
  description = "S3 path for processing job outputs (optional audit)"
  type        = string
  default     = ""
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for processing data"
  type        = string
}

variable "enable_s3_audit_output" {
  description = "Whether to enable S3 audit output"
  type        = bool
  default     = true
}

# Instance Configuration
variable "instance_type" {
  description = "SageMaker instance type for processing"
  type        = string
  default     = "ml.m5.large"
}

variable "instance_count" {
  description = "Number of instances for processing"
  type        = number
  default     = 1
}

variable "volume_size_gb" {
  description = "Size of EBS volume in GB"
  type        = number
  default     = 30
}

variable "max_runtime_seconds" {
  description = "Maximum runtime for processing job in seconds"
  type        = number
  default     = 1800  # 30 minutes for daily processing
}

# MLflow Configuration
variable "mlflow_tracking_uri" {
  description = "MLflow tracking server URI"
  type        = string
}

variable "mlflow_model_uri" {
  description = "MLflow model URI (e.g., models:/poem-model/Production)"
  type        = string
  default     = "models:/poem-model/Production"
}

# Kafka Configuration
variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  type        = string
}

variable "kafka_topic" {
  description = "Kafka topic for output messages"
  type        = string
}

variable "kafka_secret_arn" {
  description = "ARN of Secrets Manager secret containing Kafka credentials"
  type        = string
  default     = null
}

variable "msk_cluster_arn" {
  description = "ARN of MSK cluster (for IAM authentication)"
  type        = string
  default     = null
}

# Environment Variables
variable "environment_variables" {
  description = "Environment variables for the processing container"
  type        = map(string)
  default     = {}
}

# Networking Configuration
variable "vpc_config" {
  description = "VPC configuration for processing jobs"
  type = object({
    security_group_ids = list(string)
    subnet_ids        = list(string)
  })
  default = null
}

# Scheduling Configuration
variable "enable_scheduling" {
  description = "Whether to enable scheduled processing pipeline execution"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "Cron expression for processing schedule (e.g., daily)"
  type        = string
  default     = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
}

variable "schedule_enabled" {
  description = "Whether the schedule rule is enabled"
  type        = bool
  default     = false
}
