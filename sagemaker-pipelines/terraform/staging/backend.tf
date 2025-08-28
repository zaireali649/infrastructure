# Terraform Backend Configuration for SageMaker Pipelines - Staging

terraform {
  backend "s3" {
    bucket         = "terraform-state-zali-staging"
    key            = "sagemaker-pipelines/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
