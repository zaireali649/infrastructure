# SageMaker Pipelines - Staging Outputs

output "training_pipeline_arn" {
  description = "ARN of the training SageMaker pipeline"
  value       = module.sagemaker_pipelines.training_pipeline_arn
}

output "training_pipeline_name" {
  description = "Name of the training SageMaker pipeline"
  value       = module.sagemaker_pipelines.training_pipeline_name
}

output "processing_pipeline_arn" {
  description = "ARN of the processing SageMaker pipeline"
  value       = module.sagemaker_pipelines.processing_pipeline_arn
}

output "processing_pipeline_name" {
  description = "Name of the processing SageMaker pipeline"
  value       = module.sagemaker_pipelines.processing_pipeline_name
}

output "training_role_arn" {
  description = "ARN of the training IAM role"
  value       = module.sagemaker_pipelines.training_role_arn
}

output "processing_role_arn" {
  description = "ARN of the processing IAM role"
  value       = module.sagemaker_pipelines.processing_role_arn
}

output "training_schedule_rule_arn" {
  description = "ARN of the training schedule EventBridge rule"
  value       = module.sagemaker_pipelines.training_schedule_rule_arn
}

output "processing_schedule_rule_arn" {
  description = "ARN of the processing schedule EventBridge rule"
  value       = module.sagemaker_pipelines.processing_schedule_rule_arn
}

output "module_configuration" {
  description = "Summary of module configuration"
  value       = module.sagemaker_pipelines.module_configuration
}

output "existing_infrastructure" {
  description = "References to existing infrastructure being used"
  value       = module.sagemaker_pipelines.existing_infrastructure
}
