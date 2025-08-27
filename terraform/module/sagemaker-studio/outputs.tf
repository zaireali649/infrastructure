output "domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = aws_sagemaker_domain.studio_domain.id
}

output "domain_arn" {
  description = "SageMaker Studio Domain ARN"
  value       = aws_sagemaker_domain.studio_domain.arn
}

output "domain_url" {
  description = "SageMaker Studio Domain URL"
  value       = aws_sagemaker_domain.studio_domain.url
}

output "domain_name" {
  description = "SageMaker Studio Domain Name"
  value       = aws_sagemaker_domain.studio_domain.domain_name
}

output "execution_role_arn" {
  description = "SageMaker execution role ARN"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "execution_role_name" {
  description = "SageMaker execution role name"
  value       = aws_iam_role.sagemaker_execution_role.name
}

output "user_profile_arn" {
  description = "SageMaker Studio User Profile ARN"
  value       = aws_sagemaker_user_profile.default_user.arn
}

output "user_profile_name" {
  description = "SageMaker Studio User Profile Name"
  value       = aws_sagemaker_user_profile.default_user.user_profile_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for ML artifacts"
  value       = var.enable_s3_bucket ? aws_s3_bucket.ml_artifacts[0].id : null
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for ML artifacts"
  value       = var.enable_s3_bucket ? aws_s3_bucket.ml_artifacts[0].arn : null
}

output "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = var.enable_s3_bucket ? aws_s3_bucket.ml_artifacts[0].bucket_regional_domain_name : null
}

# For backwards compatibility with CloudFormation template outputs
output "BucketName" {
  description = "S3 bucket for ML data and model artifacts (CloudFormation compatibility)"
  value       = var.enable_s3_bucket ? aws_s3_bucket.ml_artifacts[0].id : null
}

output "RoleArn" {
  description = "SageMaker execution role (CloudFormation compatibility)"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "DomainId" {
  description = "SageMaker Studio Domain ID (CloudFormation compatibility)"
  value       = aws_sagemaker_domain.studio_domain.id
}

output "StudioUserName" {
  description = "SageMaker Studio User (CloudFormation compatibility)"
  value       = aws_sagemaker_user_profile.default_user.user_profile_name
}
