terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73.0"  # Version that supports SageMaker MLflow and EventBridge
    }
  }
}
