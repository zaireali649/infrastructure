# Variables for SageMaker Studio Staging Environment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID to deploy SageMaker Studio into"
  type        = string
  default     = null
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

variable "user_profile_name" {
  description = "Name for the SageMaker Studio user profile"
  type        = string
  default     = "zali"
}

variable "auth_mode" {
  description = "Authentication mode for SageMaker Studio Domain"
  type        = string
  default     = "IAM"
  validation {
    condition     = contains(["IAM", "SSO"], var.auth_mode)
    error_message = "Auth mode must be either 'IAM' or 'SSO'."
  }
}

variable "app_network_access_type" {
  description = "Network access type for SageMaker Studio apps"
  type        = string
  default     = "PublicInternetOnly"
  validation {
    condition     = contains(["PublicInternetOnly", "VpcOnly"], var.app_network_access_type)
    error_message = "App network access type must be either 'PublicInternetOnly' or 'VpcOnly'."
  }
}

variable "default_instance_type" {
  description = "Default instance type for SageMaker Studio apps"
  type        = string
  default     = "ml.t3.medium"
}

variable "jupyter_instance_type" {
  description = "Instance type for Jupyter Server App"
  type        = string
  default     = "ml.t3.medium"
}

variable "kernel_gateway_instance_type" {
  description = "Instance type for Kernel Gateway App"
  type        = string
  default     = "ml.t3.medium"
}

variable "tensorboard_instance_type" {
  description = "Instance type for TensorBoard App"
  type        = string
  default     = "ml.t3.medium"
}

variable "enable_s3_bucket" {
  description = "Whether to create an S3 bucket for ML artifacts"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Custom S3 bucket name (optional)"
  type        = string
  default     = null
}

variable "custom_domain_name" {
  description = "Custom name for the SageMaker Studio Domain (optional)"
  type        = string
  default     = null
}

variable "custom_execution_role_name" {
  description = "Custom name for the SageMaker execution role (optional)"
  type        = string
  default     = null
}

variable "lifecycle_config_arns" {
  description = "List of lifecycle configuration ARNs to apply to apps"
  type        = list(string)
  default     = []
}

variable "sharing_settings" {
  description = "Sharing settings for SageMaker Studio notebooks"
  type = object({
    notebook_output_option = optional(string, "Allowed")
    s3_output_path        = optional(string)
    s3_kms_key_id         = optional(string)
  })
  default = {
    notebook_output_option = "Allowed"
  }
}

variable "additional_execution_role_policies" {
  description = "Additional IAM policy ARNs to attach to the SageMaker execution role"
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
  default     = "terraform-deploy"
}
