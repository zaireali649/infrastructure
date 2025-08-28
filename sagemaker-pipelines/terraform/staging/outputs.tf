# SageMaker Pipeline Outputs

# Training Pipeline Outputs
output "training_pipeline_arn" {
  description = "ARN of the training pipeline"
  value       = module.sagemaker_pipelines.training_pipeline_arn
}

output "training_pipeline_name" {
  description = "Name of the training pipeline"
  value       = module.sagemaker_pipelines.training_pipeline_name
}

output "training_role_arn" {
  description = "ARN of the training execution role"
  value       = module.sagemaker_pipelines.training_role_arn
}

# Inference Pipeline Outputs
output "processing_pipeline_arn" {
  description = "ARN of the processing/inference pipeline"
  value       = module.sagemaker_pipelines.processing_pipeline_arn
}

output "processing_pipeline_name" {
  description = "Name of the processing/inference pipeline"
  value       = module.sagemaker_pipelines.processing_pipeline_name
}

output "processing_role_arn" {
  description = "ARN of the processing execution role"
  value       = module.sagemaker_pipelines.processing_role_arn
}

# Scheduling Outputs
output "training_schedule_rule_arn" {
  description = "ARN of the training schedule rule"
  value       = module.sagemaker_pipelines.training_schedule_rule_arn
}

output "processing_schedule_rule_arn" {
  description = "ARN of the processing schedule rule"
  value       = module.sagemaker_pipelines.processing_schedule_rule_arn
}

output "scheduler_role_arn" {
  description = "ARN of the EventBridge scheduler role"
  value       = module.sagemaker_pipelines.scheduler_role_arn
}

# S3 Configuration Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket used for ML data"
  value       = local.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for ML data"
  value       = data.aws_s3_bucket.ml_bucket.arn
}

# Container Image Outputs
output "training_image_uri" {
  description = "URI of the training container image"
  value       = local.training_image_uri
}

output "inference_image_uri" {
  description = "URI of the inference container image"
  value       = local.inference_image_uri
}

# MLflow Configuration
output "mlflow_tracking_uri" {
  description = "MLflow tracking server URI"
  value       = local.mlflow_tracking_uri
}

# Quick Start Commands
output "manual_training_command" {
  description = "AWS CLI command to manually trigger training pipeline"
  value = format(
    "aws sagemaker start-pipeline-execution --pipeline-name %s --region %s",
    module.sagemaker_pipelines.training_pipeline_name,
    data.aws_region.current.name
  )
}

output "manual_inference_command" {
  description = "AWS CLI command to manually trigger inference pipeline"
  value = format(
    "aws sagemaker start-pipeline-execution --pipeline-name %s --region %s",
    module.sagemaker_pipelines.processing_pipeline_name,
    data.aws_region.current.name
  )
}
