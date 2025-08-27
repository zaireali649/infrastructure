# Variables for SageMaker Managed MLflow Staging Environment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name_suffix" {
  description = "Unique suffix for S3 bucket naming"
  type        = string
  default     = "zali-staging"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_name_suffix))
    error_message = "Bucket name suffix must contain only lowercase letters, numbers, and hyphens."
  }
}

# MLflow Configuration
variable "mlflow_version" {
  description = "MLflow version for the tracking server"
  type        = string
  default     = "3.0"
}

variable "automatic_model_registration" {
  description = "Whether to enable automatic model registration"
  type        = bool
  default     = true
}

variable "weekly_maintenance_window_start" {
  description = "Weekly maintenance window start time (e.g., TUE:03:30)"
  type        = string
  default     = "TUE:03:30"
  validation {
    condition = can(regex("(?i)^(MON|TUE|WED|THU|FRI|SAT|SUN):([01][0-9]|2[0-3]):[0-5][0-9]$", var.weekly_maintenance_window_start))
    error_message = "Maintenance window must be in format DAY:HH:MM (e.g., TUE:03:30)."
  }
}

# S3 Configuration
variable "create_s3_bucket" {
  description = "Whether to create a new S3 bucket for MLflow artifacts"
  type        = bool
  default     = true
}

variable "artifact_store_uri" {
  description = "S3 URI for artifact storage (required if create_s3_bucket is false)"
  type        = string
  default     = null
  validation {
    condition = var.artifact_store_uri == null || can(regex("^s3://[a-z0-9.-]+(/.*)?$", var.artifact_store_uri))
    error_message = "Artifact store URI must be a valid S3 URI (e.g., s3://bucket-name/path)."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption (optional)"
  type        = string
  default     = null
}

# Custom resource naming (optional)
variable "custom_tracking_server_name" {
  description = "Custom name for the MLflow tracking server (optional)"
  type        = string
  default     = null
  validation {
    condition = var.custom_tracking_server_name == null || can(regex("^[a-zA-Z0-9\\-]{1,256}$", var.custom_tracking_server_name))
    error_message = "Tracking server name must be 1-256 characters and contain only alphanumeric characters and hyphens."
  }
}

variable "custom_mlflow_role_name" {
  description = "Custom name for the MLflow IAM role (optional)"
  type        = string
  default     = null
}

variable "additional_role_policies" {
  description = "Additional IAM policy ARNs to attach to the MLflow role"
  type        = list(string)
  default     = []
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# GitHub Actions specific variables (sensitive values will come from secrets)
variable "github_repository" {
  description = "GitHub repository name for tagging"
  type        = string
  default     = "infrastructure"
}

variable "github_workflow" {
  description = "GitHub workflow name for tagging"
  type        = string
  default     = "mlflow-deploy"
}
