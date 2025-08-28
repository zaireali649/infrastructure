# Processing Role
output "processing_role_arn" {
  description = "ARN of the SageMaker processing execution role"
  value       = aws_iam_role.processing_role.arn
}

output "processing_role_name" {
  description = "Name of the SageMaker processing execution role"
  value       = aws_iam_role.processing_role.name
}

# Pipeline
output "pipeline_arn" {
  description = "ARN of the SageMaker processing pipeline"
  value       = aws_sagemaker_pipeline.processing_pipeline.arn
}

output "pipeline_name" {
  description = "Name of the SageMaker processing pipeline"
  value       = aws_sagemaker_pipeline.processing_pipeline.pipeline_name
}

# Pipeline Role
output "pipeline_role_arn" {
  description = "ARN of the SageMaker pipeline execution role"
  value       = aws_iam_role.pipeline_role.arn
}

# Scheduling
output "schedule_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = var.enable_scheduling ? aws_cloudwatch_event_rule.processing_schedule[0].arn : null
}

output "schedule_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = var.enable_scheduling ? aws_cloudwatch_event_rule.processing_schedule[0].name : null
}

output "scheduler_role_arn" {
  description = "ARN of the EventBridge scheduler role"
  value       = var.enable_scheduling ? aws_iam_role.scheduler_role[0].arn : null
}
