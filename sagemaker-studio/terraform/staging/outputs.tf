# Outputs for SageMaker Studio Staging Environment

# Core SageMaker Studio outputs
output "sagemaker_domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = module.sagemaker_studio.domain_id
}

output "sagemaker_domain_arn" {
  description = "SageMaker Studio Domain ARN"
  value       = module.sagemaker_studio.domain_arn
}

output "sagemaker_domain_url" {
  description = "SageMaker Studio Domain URL"
  value       = module.sagemaker_studio.domain_url
}

output "sagemaker_domain_name" {
  description = "SageMaker Studio Domain Name"
  value       = module.sagemaker_studio.domain_name
}

# IAM outputs
output "sagemaker_execution_role_arn" {
  description = "SageMaker execution role ARN"
  value       = module.sagemaker_studio.execution_role_arn
}

output "sagemaker_execution_role_name" {
  description = "SageMaker execution role name"
  value       = module.sagemaker_studio.execution_role_name
}

# User profile outputs
output "sagemaker_user_profile_arn" {
  description = "SageMaker Studio User Profile ARN"
  value       = module.sagemaker_studio.user_profile_arn
}

output "sagemaker_user_profile_name" {
  description = "SageMaker Studio User Profile Name"
  value       = module.sagemaker_studio.user_profile_name
}

# S3 outputs
output "ml_artifacts_bucket_name" {
  description = "S3 bucket name for ML artifacts"
  value       = module.sagemaker_studio.s3_bucket_name
}

output "ml_artifacts_bucket_arn" {
  description = "S3 bucket ARN for ML artifacts"
  value       = module.sagemaker_studio.s3_bucket_arn
}

# Environment information
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

# Debug outputs
output "debug_info" {
  description = "Debug information for troubleshooting"
  value = {
    vpc_id_provided     = var.vpc_id
    subnet_ids_provided = var.subnet_ids
    subnet_ids_count    = length(var.subnet_ids)
    discovered_subnets  = "auto-discovery disabled"
    selected_subnets    = local.selected_subnet_ids
  }
}

output "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  description = "VPC ID where SageMaker Studio is deployed"
  value       = var.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs where SageMaker Studio is deployed"
  value       = local.selected_subnet_ids
}

# CloudFormation compatibility outputs for migration
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

# Useful information for connecting other services
output "sagemaker_studio_connection_info" {
  description = "Connection information for SageMaker Studio"
  value = {
    domain_id         = module.sagemaker_studio.domain_id
    domain_url        = module.sagemaker_studio.domain_url
    user_profile_name = module.sagemaker_studio.user_profile_name
    execution_role_arn = module.sagemaker_studio.execution_role_arn
    s3_bucket_name    = module.sagemaker_studio.s3_bucket_name
    region           = data.aws_region.current.name
  }
}
