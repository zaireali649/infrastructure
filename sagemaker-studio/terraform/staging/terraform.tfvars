# SageMaker Studio Staging Environment Configuration
# This file contains the configuration for deploying SageMaker Studio for user 'zali'

# AWS Configuration
aws_region = "us-east-1" # Update this to your preferred region

# Network Configuration
# Update these values to match your actual VPC and subnet IDs
vpc_id     = "vpc-xxxxxxxxx"                          # Your VPC ID
subnet_ids = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"] # Your subnet IDs (required)

# Project Configuration
bucket_name_suffix = "zali-staging" # This will create bucket: sagemaker-studio-staging-ml-bucket-zali-staging

# User Configuration
user_profile_name = "zali"

# SageMaker Studio Settings
auth_mode               = "IAM"
app_network_access_type = "PublicInternetOnly" # Change to "VpcOnly" for production

# Instance Types (optimized for staging/cost)
default_instance_type        = "ml.t3.medium"
jupyter_instance_type        = "ml.t3.medium"
kernel_gateway_instance_type = "ml.t3.medium"
tensorboard_instance_type    = "ml.t3.medium"

# S3 Configuration
enable_s3_bucket = true
# s3_bucket_name = null  # Let it auto-generate or specify custom name

# Notebook Sharing Settings
sharing_settings = {
  notebook_output_option = "Allowed"
  # s3_output_path = null  # Will be set to the created bucket
  # s3_kms_key_id = null   # Use default S3 encryption
}

# Custom Resource Names (optional - will auto-generate if not specified)
# custom_domain_name = "zali-sagemaker-staging"
# custom_execution_role_name = "zali-sagemaker-staging-role"

# Lifecycle Configurations (add ARNs if you have custom lifecycle configs)
lifecycle_config_arns = []

# Additional IAM Policies (uncomment if you need additional permissions)
# additional_execution_role_policies = [
#   "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
# ]

# Additional Tags
additional_tags = {
  Owner       = "zali"
  Team        = "ML-Engineering"
  CostCenter  = "Engineering"
  Environment = "staging"
  Purpose     = "ml-experimentation"
}

# GitHub Configuration (for CI/CD tracking)
github_repository = "infrastructure"
github_workflow   = "sagemaker-deploy"
