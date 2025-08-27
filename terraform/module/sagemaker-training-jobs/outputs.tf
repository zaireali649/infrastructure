# Training Role Outputs
output "training_role_arn" {
  description = "ARN of the SageMaker training IAM role"
  value       = aws_iam_role.training_role.arn
}

output "training_role_name" {
  description = "Name of the SageMaker training IAM role"
  value       = aws_iam_role.training_role.name
}

# Scheduler Outputs
output "scheduler_role_arn" {
  description = "ARN of the EventBridge scheduler IAM role"
  value       = var.enable_scheduling ? aws_iam_role.scheduler_role[0].arn : null
}

output "scheduler_role_name" {
  description = "Name of the EventBridge scheduler IAM role"
  value       = var.enable_scheduling ? aws_iam_role.scheduler_role[0].name : null
}

output "schedule_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = var.enable_scheduling ? aws_cloudwatch_event_rule.training_schedule[0].arn : null
}

output "schedule_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = var.enable_scheduling ? aws_cloudwatch_event_rule.training_schedule[0].name : null
}

output "schedule_expression" {
  description = "Schedule expression used for training jobs"
  value       = var.enable_scheduling ? var.schedule_expression : null
}

# Lambda Launcher Outputs (when enabled)
output "lambda_function_arn" {
  description = "ARN of the Lambda training job launcher function"
  value       = var.enable_custom_launcher ? aws_lambda_function.training_job_launcher[0].arn : null
}

output "lambda_function_name" {
  description = "Name of the Lambda training job launcher function"
  value       = var.enable_custom_launcher ? aws_lambda_function.training_job_launcher[0].function_name : null
}

output "lambda_role_arn" {
  description = "ARN of the Lambda function IAM role"
  value       = var.enable_custom_launcher ? aws_iam_role.lambda_role[0].arn : null
}

# Training Configuration Outputs
output "training_image" {
  description = "Docker image URI used for training"
  value       = var.training_image
}

output "instance_type" {
  description = "Instance type used for training"
  value       = var.instance_type
}

output "instance_count" {
  description = "Number of instances used for training"
  value       = var.instance_count
}

output "output_data_s3_path" {
  description = "S3 path for training job outputs"
  value       = var.output_data_s3_path
}

# MLflow Integration Outputs
output "mlflow_tracking_uri" {
  description = "MLflow tracking URI for experiment tracking"
  value       = var.mlflow_tracking_uri
}

output "mlflow_tracking_server_arn" {
  description = "ARN of the MLflow tracking server"
  value       = var.mlflow_tracking_server_arn
}

output "mlflow_integration_enabled" {
  description = "Whether MLflow integration is enabled"
  value       = var.enable_mlflow_integration && var.mlflow_tracking_server_arn != null
}

# Resource Naming Outputs
output "name_prefix" {
  description = "Naming prefix used for all resources"
  value       = "${var.project_name}-${var.environment}"
}

output "job_definition_name" {
  description = "Name of the training job definition"
  value       = var.job_definition_name != null ? var.job_definition_name : "${var.project_name}-${var.environment}-training-job"
}

# Configuration Summary Outputs
output "training_job_configuration" {
  description = "Summary of training job configuration"
  value = {
    project_name          = var.project_name
    environment          = var.environment
    training_image       = var.training_image
    instance_type        = var.instance_type
    instance_count       = var.instance_count
    volume_size_gb       = var.volume_size_gb
    max_runtime_seconds  = var.max_runtime_seconds
    scheduling_enabled   = var.enable_scheduling
    schedule_expression  = var.schedule_expression
    mlflow_enabled      = var.enable_mlflow_integration && var.mlflow_tracking_server_arn != null
    custom_launcher_enabled = var.enable_custom_launcher
    spot_training_enabled = var.enable_spot_training
    network_isolation_enabled = var.enable_network_isolation
  }
}

# CloudFormation compatibility outputs
output "TrainingRoleArn" {
  description = "SageMaker training role ARN (CloudFormation compatibility)"
  value       = aws_iam_role.training_role.arn
}

output "ScheduleRuleArn" {
  description = "EventBridge schedule rule ARN (CloudFormation compatibility)"
  value       = var.enable_scheduling ? aws_cloudwatch_event_rule.training_schedule[0].arn : null
}

output "TrainingJobDefinitionName" {
  description = "Training job definition name (CloudFormation compatibility)"
  value       = var.job_definition_name != null ? var.job_definition_name : "${var.project_name}-${var.environment}-training-job"
}
