# Project Configuration
variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
  default     = "staging"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens."
  }
}

# Training Job Configuration
variable "job_definition_name" {
  description = "Name for the training job definition (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "training_job_name_prefix" {
  description = "Prefix for training job names (timestamp will be appended)"
  type        = string
  default     = null
}

variable "training_image" {
  description = "Docker image URI for training (ECR repository URI or public image)"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/", var.training_image)) || can(regex("^[a-z0-9.-]+/", var.training_image))
    error_message = "Training image must be a valid ECR URI or Docker image reference."
  }
}

variable "training_input_mode" {
  description = "Input mode for training data"
  type        = string
  default     = "File"
  validation {
    condition     = contains(["File", "Pipe"], var.training_input_mode)
    error_message = "Training input mode must be either 'File' or 'Pipe'."
  }
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for training"
  type        = string
  default     = "ml.m5.large"
  validation {
    condition     = can(regex("^ml\\.", var.instance_type))
    error_message = "Instance type must be a valid SageMaker instance type (starts with 'ml.')."
  }
}

variable "instance_count" {
  description = "Number of instances for training"
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 100
    error_message = "Instance count must be between 1 and 100."
  }
}

variable "volume_size_gb" {
  description = "Size of the EBS volume attached to the training instance (in GB)"
  type        = number
  default     = 30
  validation {
    condition     = var.volume_size_gb >= 1 && var.volume_size_gb <= 16384
    error_message = "Volume size must be between 1 GB and 16,384 GB."
  }
}

variable "max_runtime_seconds" {
  description = "Maximum runtime for training jobs in seconds"
  type        = number
  default     = 86400 # 24 hours
  validation {
    condition     = var.max_runtime_seconds > 0 && var.max_runtime_seconds <= 2592000 # 30 days
    error_message = "Max runtime must be between 1 second and 2,592,000 seconds (30 days)."
  }
}

# Data Configuration
variable "input_data_config" {
  description = "Input data configuration for training"
  type = list(object({
    ChannelName     = string
    DataSource = object({
      S3DataSource = object({
        S3DataType             = string # "S3Prefix" or "ManifestFile"
        S3Uri                  = string
        S3DataDistributionType = optional(string, "FullyReplicated") # "FullyReplicated" or "ShardedByS3Key"
      })
    })
    ContentType     = optional(string, "application/x-parquet")
    CompressionType = optional(string, "None") # "None" or "Gzip"
    InputMode       = optional(string, "File") # "File" or "Pipe"
  }))
  default = []
  validation {
    condition     = length(var.input_data_config) >= 0
    error_message = "Input data config must be a valid list of data channel configurations."
  }
}

variable "output_data_s3_path" {
  description = "S3 path for training job outputs"
  type        = string
  validation {
    condition     = can(regex("^s3://[a-z0-9.-]+(/.*)?$", var.output_data_s3_path))
    error_message = "Output data S3 path must be a valid S3 URI."
  }
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for training data and artifacts"
  type        = string
  default     = null
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

# Scheduling Configuration
variable "enable_scheduling" {
  description = "Whether to enable EventBridge scheduling for training jobs"
  type        = bool
  default     = true
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (cron or rate)"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
  validation {
    condition = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.schedule_expression))
    error_message = "Schedule expression must be a valid EventBridge rate or cron expression."
  }
}

variable "schedule_enabled" {
  description = "Whether the EventBridge schedule is enabled"
  type        = bool
  default     = true
}

variable "schedule_rule_name" {
  description = "Name for the EventBridge schedule rule (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

# MLflow Integration
variable "mlflow_tracking_server_arn" {
  description = "ARN of the MLflow tracking server for model registration"
  type        = string
  default     = null
}

variable "mlflow_tracking_uri" {
  description = "MLflow tracking URI for experiment tracking"
  type        = string
  default     = null
}

variable "enable_mlflow_integration" {
  description = "Whether to enable MLflow integration for experiment tracking"
  type        = bool
  default     = true
}

# Custom Lambda Launcher (Optional)
variable "enable_custom_launcher" {
  description = "Whether to use a custom Lambda function for launching training jobs"
  type        = bool
  default     = false
}

variable "lambda_zip_path" {
  description = "Path to the Lambda function ZIP file (required if enable_custom_launcher is true)"
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
  validation {
    condition     = contains(["python3.8", "python3.9", "python3.10", "python3.11"], var.lambda_runtime)
    error_message = "Lambda runtime must be a supported Python version."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.lambda_timeout > 0 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

# IAM Configuration
variable "training_role_name" {
  description = "Name for the SageMaker training IAM role (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "scheduler_role_name" {
  description = "Name for the EventBridge scheduler IAM role (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "additional_training_role_policies" {
  description = "Additional IAM policy ARNs to attach to the SageMaker training role"
  type        = list(string)
  default     = []
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
  description = "Whether to enable network isolation for training jobs"
  type        = bool
  default     = false
}

# Monitoring and Logging
variable "enable_spot_training" {
  description = "Whether to enable managed spot training for cost optimization"
  type        = bool
  default     = false
}

variable "checkpoint_config" {
  description = "Checkpoint configuration for spot training"
  type = object({
    S3Uri       = string
    LocalPath   = optional(string, "/opt/ml/checkpoints")
  })
  default = null
}

variable "profiler_config" {
  description = "Profiler configuration for training jobs"
  type = object({
    S3OutputPath                 = string
    ProfilingIntervalInMilliseconds = optional(number, 500)
    ProfilingParameters          = optional(map(string), {})
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

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
