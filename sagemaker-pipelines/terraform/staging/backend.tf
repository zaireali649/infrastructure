# Terraform Backend Configuration for Staging Environment

terraform {
  # Remote state management (configure TF_BACKEND_BUCKET secret to enable)
  backend "s3" {
    # These values will be provided via -backend-config in CI/CD
    # bucket = "configured-via-backend-config"
    # key    = "configured-via-backend-config" 
    # region = "configured-via-backend-config"
    # dynamodb_table = "configured-via-backend-config"
    # encrypt = true
  }
}

# Configure the AWS provider with explicit settings
provider "aws" {
  region = var.aws_region
  
  # Explicit configuration to avoid provider issues
  default_tags {
    tags = merge(var.tags, {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "sagemaker-pipelines"
    })
  }
  
  # Ensure consistent behavior
  retry_mode = "standard"
  max_retries = 3
}
