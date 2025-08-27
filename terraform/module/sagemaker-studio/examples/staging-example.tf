# Example configuration for SageMaker Studio in staging environment
# This file shows how to use the SageMaker Studio module with common staging settings

# Data sources to find existing VPC and subnets
data "aws_vpc" "main" {
  # Assuming you have a VPC tagged with Name = "staging-vpc"
  tags = {
    Name        = "staging-vpc"
    Environment = "staging"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  # Assuming private subnets are tagged appropriately
  tags = {
    Type = "private"
  }
}

# Local values for consistency
locals {
  project_name = "ml-platform"
  environment  = "staging"
  region       = data.aws_region.current.name

  common_tags = {
    Environment = local.environment
    Project     = local.project_name
    Team        = "ML-Engineering"
    Owner       = "ml-team@company.com"
    ManagedBy   = "terraform"
  }
}

# Current region data source
data "aws_region" "current" {}

# SageMaker Studio module configuration
module "sagemaker_studio" {
  source = "../"  # Path to the module

  # Required parameters
  project_name        = local.project_name
  environment         = local.environment
  bucket_name_suffix  = "staging-team-alpha"  # Make this unique for your org
  vpc_id              = data.aws_vpc.main.id
  subnet_ids          = data.aws_subnets.private.ids

  # Staging-specific configurations
  user_profile_name           = "staging-ml-user"
  auth_mode                   = "IAM"
  app_network_access_type     = "PublicInternetOnly"  # Use "VpcOnly" for production
  default_instance_type       = "ml.t3.medium"       # Cost-effective for staging

  # S3 configuration
  enable_s3_bucket = true
  # s3_bucket_name = "custom-ml-bucket-name"  # Optional: specify custom bucket name

  # App settings for staging environment
  jupyter_server_app_settings = {
    default_resource_spec = {
      instance_type = "ml.t3.medium"
    }
    lifecycle_config_arns = []
  }

  kernel_gateway_app_settings = {
    default_resource_spec = {
      instance_type = "ml.t3.medium"
    }
    lifecycle_config_arns = []
  }

  # Sharing settings
  sharing_settings = {
    notebook_output_option = "Allowed"
    # s3_output_path = "s3://${module.sagemaker_studio.s3_bucket_name}/notebook-outputs/"
  }

  # Additional IAM policies if needed
  # additional_execution_role_policies = [
  #   "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
  #   "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  # ]

  tags = local.common_tags
}

# Outputs for use by other resources
output "sagemaker_domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = module.sagemaker_studio.domain_id
}

output "sagemaker_domain_url" {
  description = "SageMaker Studio Domain URL"
  value       = module.sagemaker_studio.domain_url
}

output "sagemaker_execution_role_arn" {
  description = "SageMaker execution role ARN"
  value       = module.sagemaker_studio.execution_role_arn
}

output "sagemaker_user_profile_name" {
  description = "SageMaker Studio User Profile Name"
  value       = module.sagemaker_studio.user_profile_name
}

output "ml_artifacts_bucket_name" {
  description = "S3 bucket name for ML artifacts"
  value       = module.sagemaker_studio.s3_bucket_name
}

# CloudFormation compatibility outputs
output "BucketName" {
  description = "S3 bucket for ML data and model artifacts (CloudFormation compatibility)"
  value       = module.sagemaker_studio.BucketName
}

output "RoleArn" {
  description = "SageMaker execution role (CloudFormation compatibility)"
  value       = module.sagemaker_studio.RoleArn
}

output "DomainId" {
  description = "SageMaker Studio Domain ID (CloudFormation compatibility)"
  value       = module.sagemaker_studio.DomainId
}

output "StudioUserName" {
  description = "SageMaker Studio User (CloudFormation compatibility)"
  value       = module.sagemaker_studio.StudioUserName
}
