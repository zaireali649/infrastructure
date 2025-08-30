# SageMaker Managed MLflow Staging Environment Outputs

# Primary MLflow Service Outputs
output "mlflow_tracking_uri" {
  description = "MLflow tracking server URI for client configuration"
  value       = module.mlflow.tracking_server_url
}

output "mlflow_ui_url" {
  description = "MLflow UI URL for web access"
  value       = module.mlflow.tracking_server_url
}

output "tracking_server_arn" {
  description = "ARN of the SageMaker MLflow tracking server"
  value       = module.mlflow.tracking_server_arn
}

output "tracking_server_name" {
  description = "Name of the SageMaker MLflow tracking server"
  value       = module.mlflow.tracking_server_name
}

output "mlflow_version" {
  description = "MLflow version running on the tracking server"
  value       = module.mlflow.mlflow_version
}

# Storage Outputs
output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for MLflow artifacts"
  value       = module.mlflow.artifacts_bucket_name
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for MLflow artifacts"
  value       = module.mlflow.artifacts_bucket_arn
}

output "artifact_store_uri" {
  description = "S3 URI for MLflow artifacts"
  value       = module.mlflow.artifact_store_uri
}

# Security Outputs
output "mlflow_role_arn" {
  description = "ARN of the MLflow IAM role"
  value       = module.mlflow.mlflow_role_arn
}

output "mlflow_role_name" {
  description = "Name of the MLflow IAM role"
  value       = module.mlflow.mlflow_role_name
}

# Configuration Instructions
output "client_configuration_commands" {
  description = "Commands to configure MLflow client to use this server"
  value = <<-EOT
    # Python configuration
    import mlflow
    mlflow.set_tracking_uri("${module.mlflow.tracking_server_url}")
    
    # Environment variable configuration
    export MLFLOW_TRACKING_URI="${module.mlflow.tracking_server_url}"
    
    # Verify connection
    print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")
  EOT
}

output "sagemaker_studio_integration" {
  description = "Information for integrating with SageMaker Studio"
  value = <<-EOT
    SageMaker Managed MLflow Integration
    
    Tracking URI: ${module.mlflow.tracking_server_url}
    Artifacts Bucket: ${module.mlflow.artifact_store_uri}
    
    The managed MLflow service is automatically integrated with SageMaker Studio.
    You can access it directly from SageMaker Studio or configure it in notebooks:
    
    import mlflow
    import os
    
    # Set tracking URI (may be automatically configured in SageMaker Studio)
    mlflow.set_tracking_uri("${module.mlflow.tracking_server_url}")
    
    # Verify connection
    print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")
    
    # Start logging experiments
    with mlflow.start_run():
        mlflow.log_param("algorithm", "random_forest")
        mlflow.log_metric("accuracy", 0.95)
        # Models are automatically registered if automatic_model_registration = true
  EOT
}

# Deployment Information
output "deployment_summary" {
  description = "Deployment summary and next steps"
  value = <<-EOT
    SageMaker Managed MLflow Deployment Complete!
    
    Tracking Server: ${module.mlflow.tracking_server_name}
    Web UI/API: ${module.mlflow.tracking_server_url}
    Artifacts: ${module.mlflow.artifact_store_uri}
    MLflow Version: ${module.mlflow.mlflow_version}
    Auto Registration: Enabled
    
    Benefits of Managed MLflow:
    - Fully managed - No infrastructure to maintain
    - Auto-scaling - Scales automatically with usage
    - SageMaker Integration - Works seamlessly with SageMaker Studio
    - Cost-effective - Pay only for what you use
    
    Next Steps:
    1. Access MLflow UI through SageMaker Studio or directly via URL
    2. Configure your ML clients to use the tracking URI
    3. Start logging experiments and models
    4. Leverage automatic model registration for MLOps workflows
    
    Pro Tip: The tracking server is automatically available in SageMaker Studio!
  EOT
}

# For CloudFormation/legacy compatibility
output "MLflowTrackingServerURL" {
  description = "MLflow tracking server URL (CloudFormation compatibility)"
  value       = module.mlflow.tracking_server_url
}

output "MLflowTrackingServerArn" {
  description = "MLflow tracking server ARN (CloudFormation compatibility)" 
  value       = module.mlflow.tracking_server_arn
}

output "ArtifactsBucketName" {
  description = "S3 bucket for MLflow artifacts (CloudFormation compatibility)"
  value       = module.mlflow.artifacts_bucket_name
}
