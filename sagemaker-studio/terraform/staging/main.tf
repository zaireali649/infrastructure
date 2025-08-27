# SageMaker Studio Staging Environment
# This configuration deploys SageMaker Studio using the reusable module

provider "aws" {
  region = "us-east-1"
}


# Configure the AWS provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Data sources for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Data sources for VPC and subnets
data "aws_vpc" "main" {
  id = var.vpc_id
  
  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "VPC ID '${var.vpc_id}' not found. Please verify the VPC ID is correct and exists in the current AWS region."
    }
  }
}

# Data source for subnet auto-discovery (only used if subnet_ids not provided)
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# Local values for consistent naming and tagging
locals {
  project_name = "sagemaker-studio"
  environment  = "staging"
  
  # Use provided subnet_ids if available, otherwise use all subnets in VPC
  selected_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.all.ids
  
  common_tags = merge(var.additional_tags, {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "zali"
    Repository  = "infrastructure"
  })
}

# SageMaker Studio module
module "sagemaker_studio" {
  source = "../../../terraform/module/sagemaker-studio"

  # Required parameters
  project_name        = local.project_name
  environment         = local.environment
  bucket_name_suffix  = var.bucket_name_suffix
  vpc_id              = var.vpc_id
  subnet_ids          = local.selected_subnet_ids

  # User configuration
  user_profile_name = var.user_profile_name

  # Network and security settings
  auth_mode               = var.auth_mode
  app_network_access_type = var.app_network_access_type
  default_instance_type   = var.default_instance_type

  # S3 configuration
  enable_s3_bucket = var.enable_s3_bucket
  s3_bucket_name   = var.s3_bucket_name

  # App settings optimized for staging
  jupyter_server_app_settings = {
    default_resource_spec = {
      instance_type = var.jupyter_instance_type
    }
    lifecycle_config_arns = var.lifecycle_config_arns
  }

  kernel_gateway_app_settings = {
    default_resource_spec = {
      instance_type = var.kernel_gateway_instance_type
    }
    lifecycle_config_arns = var.lifecycle_config_arns
  }

  tensor_board_app_settings = {
    default_resource_spec = {
      instance_type = var.tensorboard_instance_type
    }
  }

  # Sharing settings
  sharing_settings = var.sharing_settings

  # Additional IAM policies if needed
  additional_execution_role_policies = var.additional_execution_role_policies

  # Custom naming (optional)
  domain_name         = var.custom_domain_name
  execution_role_name = var.custom_execution_role_name

  tags = local.common_tags
}
