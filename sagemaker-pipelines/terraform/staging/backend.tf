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


