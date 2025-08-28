# IAM Role Outputs
output "training_role_arn" {
  description = "ARN of the SageMaker training role"
  value       = var.enable_training_pipeline ? aws_iam_role.training_role[0].arn : null
}

output "training_role_name" {
  description = "Name of the SageMaker training role"
  value       = var.enable_training_pipeline ? aws_iam_role.training_role[0].name : null
}

output "processing_role_arn" {
  description = "ARN of the SageMaker processing role"
  value       = var.enable_processing_pipeline ? aws_iam_role.processing_role[0].arn : null
}

output "processing_role_name" {
  description = "Name of the SageMaker processing role"
  value       = var.enable_processing_pipeline ? aws_iam_role.processing_role[0].name : null
}

output "scheduler_role_arn" {
  description = "ARN of the EventBridge scheduler role"
  value       = (var.enable_training_schedule && var.enable_training_pipeline) || (var.enable_processing_schedule && var.enable_processing_pipeline) ? aws_iam_role.scheduler_role[0].arn : null
}

output "scheduler_role_name" {
  description = "Name of the EventBridge scheduler role"
  value       = (var.enable_training_schedule && var.enable_training_pipeline) || (var.enable_processing_schedule && var.enable_processing_pipeline) ? aws_iam_role.scheduler_role[0].name : null
}

# SageMaker Pipeline Outputs
output "training_pipeline_arn" {
  description = "ARN of the training SageMaker pipeline"
  value       = var.enable_training_pipeline ? aws_sagemaker_pipeline.training_pipeline[0].arn : null
}

output "training_pipeline_name" {
  description = "Name of the training SageMaker pipeline"
  value       = var.enable_training_pipeline ? aws_sagemaker_pipeline.training_pipeline[0].pipeline_name : null
}

output "processing_pipeline_arn" {
  description = "ARN of the processing SageMaker pipeline"
  value       = var.enable_processing_pipeline ? aws_sagemaker_pipeline.processing_pipeline[0].arn : null
}

output "processing_pipeline_name" {
  description = "Name of the processing SageMaker pipeline"
  value       = var.enable_processing_pipeline ? aws_sagemaker_pipeline.processing_pipeline[0].pipeline_name : null
}

# EventBridge Schedule Outputs
output "training_schedule_rule_arn" {
  description = "ARN of the training schedule EventBridge rule"
  value       = var.enable_training_schedule && var.enable_training_pipeline ? aws_cloudwatch_event_rule.training_schedule[0].arn : null
}

output "training_schedule_rule_name" {
  description = "Name of the training schedule EventBridge rule"
  value       = var.enable_training_schedule && var.enable_training_pipeline ? aws_cloudwatch_event_rule.training_schedule[0].name : null
}

output "processing_schedule_rule_arn" {
  description = "ARN of the processing schedule EventBridge rule"
  value       = var.enable_processing_schedule && var.enable_processing_pipeline ? aws_cloudwatch_event_rule.processing_schedule[0].arn : null
}

output "processing_schedule_rule_name" {
  description = "Name of the processing schedule EventBridge rule"
  value       = var.enable_processing_schedule && var.enable_processing_pipeline ? aws_cloudwatch_event_rule.processing_schedule[0].name : null
}

output "training_schedule_expression" {
  description = "Cron expression for the training schedule"
  value       = var.training_schedule_expression
}

output "processing_schedule_expression" {
  description = "Cron expression for the processing schedule"
  value       = var.processing_schedule_expression
}

# Configuration Summary
output "module_configuration" {
  description = "Summary of module configuration"
  value = {
    project_name                 = var.project_name
    environment                 = var.environment
    training_pipeline_enabled   = var.enable_training_pipeline
    processing_pipeline_enabled = var.enable_processing_pipeline
    training_schedule_enabled   = var.enable_training_schedule
    processing_schedule_enabled = var.enable_processing_schedule
    training_instance_type      = var.training_instance_type
    inference_instance_type     = var.inference_instance_type
    vpc_enabled                 = length(var.subnet_ids) > 0
  }
}

# Existing Infrastructure References (for verification)
output "existing_infrastructure" {
  description = "References to existing infrastructure being used"
  value = {
    vpc_id                = var.vpc_id
    subnet_ids           = var.subnet_ids
    security_group_ids   = var.security_group_ids
    s3_bucket_arn        = var.s3_bucket_arn
    training_image_uri   = var.training_image_uri
    inference_image_uri  = var.inference_image_uri
  }
}