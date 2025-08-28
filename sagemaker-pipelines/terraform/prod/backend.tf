# Terraform Backend Configuration for SageMaker Pipelines - Production

terraform {
  backend "s3" {
    bucket         = "terraform-state-zali-prod"
    key            = "sagemaker-pipelines/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
