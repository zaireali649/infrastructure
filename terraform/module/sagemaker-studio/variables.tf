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

variable "bucket_name_suffix" {
  description = "Unique suffix for S3 bucket naming (e.g., your name or initials)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_name_suffix))
    error_message = "Bucket name suffix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "VPC ID where SageMaker Studio will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for SageMaker Studio (private subnets recommended)"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "domain_name" {
  description = "Name for the SageMaker Studio Domain (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "user_profile_name" {
  description = "Name for the default SageMaker Studio user profile"
  type        = string
  default     = "default-user"
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

variable "enable_s3_bucket" {
  description = "Whether to create an S3 bucket for ML artifacts"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Custom S3 bucket name (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "additional_execution_role_policies" {
  description = "Additional IAM policy ARNs to attach to the SageMaker execution role"
  type        = list(string)
  default     = []
}

variable "default_instance_type" {
  description = "Default instance type for SageMaker Studio apps"
  type        = string
  default     = "ml.t3.medium"
}

variable "sharing_settings" {
  description = "Sharing settings for SageMaker Studio notebooks"
  type = object({
    notebook_output_option = optional(string, "Allowed")
    s3_output_path         = optional(string)
    s3_kms_key_id          = optional(string)
  })
  default = {
    notebook_output_option = "Allowed"
  }
}

variable "jupyter_server_app_settings" {
  description = "Settings for Jupyter Server App"
  type = object({
    default_resource_spec = optional(object({
      instance_type               = optional(string)
      lifecycle_config_arn        = optional(string)
      sagemaker_image_arn         = optional(string)
      sagemaker_image_version_arn = optional(string)
    }))
    lifecycle_config_arns = optional(list(string), [])
  })
  default = {}
}

variable "kernel_gateway_app_settings" {
  description = "Settings for Kernel Gateway App"
  type = object({
    default_resource_spec = optional(object({
      instance_type               = optional(string)
      lifecycle_config_arn        = optional(string)
      sagemaker_image_arn         = optional(string)
      sagemaker_image_version_arn = optional(string)
    }))
    lifecycle_config_arns = optional(list(string), [])
  })
  default = {}
}

variable "tensor_board_app_settings" {
  description = "Settings for TensorBoard App"
  type = object({
    default_resource_spec = optional(object({
      instance_type               = optional(string)
      lifecycle_config_arn        = optional(string)
      sagemaker_image_arn         = optional(string)
      sagemaker_image_version_arn = optional(string)
    }))
  })
  default = {}
}

variable "execution_role_name" {
  description = "Custom name for the SageMaker execution role (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
