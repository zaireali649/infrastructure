# Training Jobs Module Outputs
output "training_role_arn" {
  description = "ARN of the SageMaker training IAM role"
  value       = module.sagemaker_training_jobs.training_role_arn
}

output "training_role_name" {
  description = "Name of the SageMaker training IAM role"
  value       = module.sagemaker_training_jobs.training_role_name
}

output "scheduler_role_arn" {
  description = "ARN of the EventBridge scheduler IAM role"
  value       = module.sagemaker_training_jobs.scheduler_role_arn
}

output "schedule_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = module.sagemaker_training_jobs.schedule_rule_arn
}

output "schedule_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = module.sagemaker_training_jobs.schedule_rule_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda training launcher (if enabled)"
  value       = module.sagemaker_training_jobs.lambda_function_arn
}

output "training_job_configuration" {
  description = "Summary of training job configuration"
  value       = module.sagemaker_training_jobs.training_job_configuration
}

output "mlflow_integration_status" {
  description = "MLflow integration configuration"
  value = {
    enabled            = module.sagemaker_training_jobs.mlflow_integration_enabled
    tracking_uri       = module.sagemaker_training_jobs.mlflow_tracking_uri
    tracking_server_arn = module.sagemaker_training_jobs.mlflow_tracking_server_arn
  }
}

# Convenience outputs for integration
output "project_name" {
  description = "Project name used for resource naming"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
