# MLflow Tracking Server Outputs
output "tracking_server_arn" {
  description = "ARN of the MLflow tracking server"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.arn
}

output "tracking_server_name" {
  description = "Name of the MLflow tracking server"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.tracking_server_name
}

output "tracking_server_url" {
  description = "URL of the MLflow tracking server"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.tracking_server_url
}

output "mlflow_version" {
  description = "MLflow version running on the tracking server"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.mlflow_version
}

# S3 Bucket Outputs
output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for MLflow artifacts"
  value       = var.create_s3_bucket ? aws_s3_bucket.mlflow_artifacts[0].id : null
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for MLflow artifacts"
  value       = var.create_s3_bucket ? aws_s3_bucket.mlflow_artifacts[0].arn : null
}

output "artifact_store_uri" {
  description = "S3 URI for MLflow artifacts"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.artifact_store_uri
}

# IAM Role Outputs
output "mlflow_role_arn" {
  description = "ARN of the MLflow IAM role"
  value       = aws_iam_role.mlflow_role.arn
}

output "mlflow_role_name" {
  description = "Name of the MLflow IAM role"
  value       = aws_iam_role.mlflow_role.name
}

# Configuration Outputs for Client Setup
output "mlflow_tracking_uri" {
  description = "MLflow tracking URI for client configuration"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.tracking_server_url
}

# For CloudFormation/legacy compatibility
output "MLflowTrackingServerURL" {
  description = "MLflow tracking server URL (CloudFormation compatibility)"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.tracking_server_url
}

output "MLflowTrackingServerArn" {
  description = "MLflow tracking server ARN (CloudFormation compatibility)"
  value       = aws_sagemaker_mlflow_tracking_server.mlflow.arn
}

output "ArtifactsBucketName" {
  description = "S3 bucket for MLflow artifacts (CloudFormation compatibility)"
  value       = var.create_s3_bucket ? aws_s3_bucket.mlflow_artifacts[0].id : null
}

output "MLflowRoleArn" {
  description = "MLflow IAM role ARN (CloudFormation compatibility)"
  value       = aws_iam_role.mlflow_role.arn
}
