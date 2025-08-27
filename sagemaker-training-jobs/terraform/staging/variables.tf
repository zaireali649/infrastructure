# Core Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ml-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

# Existing Infrastructure Integration
variable "existing_sagemaker_domain_name" {
  description = "Name of existing SageMaker domain (for integration)"
  type        = string
  default     = null
}

# Training Job Configuration
variable "training_image" {
  description = "Docker image URI for training"
  type        = string
  default     = "763104351884.dkr.ecr.us-east-1.amazonaws.com/sklearn-learn:1.0-1-cpu-py3"
}

variable "training_job_name_prefix" {
  description = "Prefix for training job names"
  type        = string
  default     = "ml-training"
}

variable "training_input_mode" {
  description = "Input mode for training data"
  type        = string
  default     = "File"
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for training"
  type        = string
  default     = "ml.m5.large"
}

variable "instance_count" {
  description = "Number of instances for training"
  type        = number
  default     = 1
}

variable "volume_size_gb" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 30
}

variable "max_runtime_seconds" {
  description = "Maximum runtime for training jobs in seconds"
  type        = number
  default     = 3600  # 1 hour
}

# Data Configuration
variable "input_data_config" {
  description = "Input data configuration for training"
  type = list(object({
    ChannelName = string
    DataSource = object({
      S3DataSource = object({
        S3DataType             = string
        S3Uri                  = string
        S3DataDistributionType = optional(string, "FullyReplicated")
      })
    })
    ContentType     = optional(string, "text/csv")
    CompressionType = optional(string, "None")
    InputMode       = optional(string, "File")
  }))
  default = []
}

variable "output_data_s3_path" {
  description = "S3 path for training job outputs"
  type        = string
  default     = "s3://ml-platform-staging-ml-bucket/training-outputs/"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for training data"
  type        = string
  default     = null
}

# Scheduling Configuration
variable "enable_scheduling" {
  description = "Whether to enable EventBridge scheduling"
  type        = bool
  default     = true
}

variable "schedule_expression" {
  description = "EventBridge schedule expression"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

variable "schedule_enabled" {
  description = "Whether the schedule is enabled"
  type        = bool
  default     = true
}

# MLflow Integration
variable "mlflow_tracking_server_arn" {
  description = "ARN of the MLflow tracking server"
  type        = string
  default     = null
}

variable "mlflow_tracking_uri" {
  description = "MLflow tracking URI"
  type        = string
  default     = null
}

variable "enable_mlflow_integration" {
  description = "Whether to enable MLflow integration"
  type        = bool
  default     = true
}

# Hyperparameters and Environment
variable "hyperparameters" {
  description = "Hyperparameters for the training algorithm"
  type        = map(string)
  default = {
    max_depth    = "5"
    n_estimators = "100"
    random_state = "42"
  }
}

variable "environment_variables" {
  description = "Environment variables for the training container"
  type        = map(string)
  default = {
    MODEL_NAME = "staging-model"
    VERSION    = "1.0"
    LOG_LEVEL  = "INFO"
  }
}

# Cost Optimization
variable "enable_spot_training" {
  description = "Whether to enable managed spot training"
  type        = bool
  default     = false
}

variable "checkpoint_config" {
  description = "Checkpoint configuration for spot training"
  type = object({
    S3Uri     = string
    LocalPath = optional(string, "/opt/ml/checkpoints")
  })
  default = null
}

# Lambda Configuration (Optional)
variable "enable_custom_launcher" {
  description = "Whether to use a custom Lambda launcher"
  type        = bool
  default     = false
}

variable "lambda_zip_path" {
  description = "Path to the Lambda function ZIP file"
  type        = string
  default     = null
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.9"
}

variable "lambda_environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

# Network Configuration (Optional)
variable "vpc_config" {
  description = "VPC configuration for training jobs"
  type = object({
    SecurityGroupIds = list(string)
    Subnets          = list(string)
  })
  default = null
}

variable "enable_network_isolation" {
  description = "Whether to enable network isolation"
  type        = bool
  default     = false
}

# Monitoring Configuration (Optional)
variable "profiler_config" {
  description = "Profiler configuration for training jobs"
  type = object({
    S3OutputPath                    = string
    ProfilingIntervalInMilliseconds = optional(number, 500)
    ProfilingParameters             = optional(map(string), {})
  })
  default = null
}

variable "debugger_hook_config" {
  description = "Debugger hook configuration"
  type = object({
    S3OutputPath   = string
    LocalPath      = optional(string, "/opt/ml/output/tensors")
    HookParameters = optional(map(string), {})
  })
  default = null
}

# IAM Configuration
variable "additional_training_role_policies" {
  description = "Additional IAM policy ARNs for the training role"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Team               = "ML-Engineering"
    Environment        = "staging"
    Project            = "ml-platform"
    CostCenter         = "Engineering"
    DataClassification = "Internal"
  }
}
