# Core Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ml-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "zali"
}

# MLflow Configuration
variable "mlflow_tracking_server_name" {
  description = "Name of the existing MLflow tracking server"
  type        = string
  default     = "mlflow-staging-mlflow"
}

# S3 Configuration
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for ML artifacts"
  type        = string
  default     = "arn:aws:s3:::mlflow-staging-mlflow-artifacts-zali-staging"
}

variable "training_data_s3_uri" {
  description = "S3 URI for training data"
  type        = string
  default     = "s3://mlflow-staging-mlflow-artifacts-zali-staging/datasets/training/"
}

variable "model_output_s3_uri" {
  description = "S3 URI for model outputs"
  type        = string
  default     = "s3://mlflow-staging-mlflow-artifacts-zali-staging/models/"
}

variable "inference_input_s3_uri" {
  description = "S3 URI for inference input data"
  type        = string
  default     = "s3://mlflow-staging-mlflow-artifacts-zali-staging/inference/input/"
}

variable "inference_output_s3_uri" {
  description = "S3 URI for inference output data"
  type        = string
  default     = "s3://mlflow-staging-mlflow-artifacts-zali-staging/inference/output/"
}

# Container Image Configuration
variable "training_image_uri" {
  description = "ECR URI for training container image"
  type        = string
  # Will be set via terraform.tfvars after ECR push
}

variable "inference_image_uri" {
  description = "ECR URI for inference container image"
  type        = string
  # Will be set via terraform.tfvars after ECR push
}

# Training Configuration
variable "training_instance_type" {
  description = "Instance type for training jobs"
  type        = string
  default     = "ml.m5.large"
}

variable "training_instance_count" {
  description = "Number of instances for training"
  type        = number
  default     = 1
}

variable "training_volume_size_gb" {
  description = "EBS volume size for training jobs (GB)"
  type        = number
  default     = 30
}

variable "max_runtime_seconds" {
  description = "Maximum runtime for training jobs (seconds)"
  type        = number
  default     = 3600  # 1 hour
}

# Training Scheduling
variable "enable_training_schedule" {
  description = "Whether to enable training job scheduling"
  type        = bool
  default     = true
}

variable "training_schedule_expression" {
  description = "Cron expression for training job schedule"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

variable "training_schedule_enabled" {
  description = "Whether the training schedule is enabled"
  type        = bool
  default     = false  # Start disabled for testing
}

# Training Hyperparameters
variable "training_hyperparameters" {
  description = "Hyperparameters for training algorithm"
  type        = map(string)
  default = {
    n_estimators    = "100"
    max_depth       = "10"
    random_state    = "42"
    test_size       = "0.2"
    model_name      = "ml-classifier"
    experiment_name = "staging-experiments"
  }
}

# Training Environment Variables
variable "training_environment_variables" {
  description = "Environment variables for training container"
  type        = map(string)
  default = {
    MODEL_TYPE      = "classification"
    DATA_FORMAT     = "parquet"
    VALIDATION_SIZE = "0.2"
  }
}

# Inference Configuration
variable "inference_instance_type" {
  description = "Instance type for inference jobs"
  type        = string
  default     = "ml.m5.large"
}

variable "inference_instance_count" {
  description = "Number of instances for inference"
  type        = number
  default     = 1
}

variable "inference_volume_size_gb" {
  description = "EBS volume size for inference jobs (GB)"
  type        = number
  default     = 30
}

# Inference Scheduling
variable "enable_inference_schedule" {
  description = "Whether to enable inference job scheduling"
  type        = bool
  default     = true
}

variable "inference_schedule_expression" {
  description = "Cron expression for inference job schedule"
  type        = string
  default     = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
}

variable "inference_schedule_enabled" {
  description = "Whether the inference schedule is enabled"
  type        = bool
  default     = false  # Start disabled for testing
}

# Kafka Configuration
variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers (comma-separated)"
  type        = string
  # Set via terraform.tfvars
}

variable "kafka_output_topic" {
  description = "Kafka topic for inference output"
  type        = string
  default     = "ml-predictions"
}

variable "kafka_security_protocol" {
  description = "Kafka security protocol"
  type        = string
  default     = "SASL_SSL"
}

variable "kafka_sasl_mechanism" {
  description = "Kafka SASL mechanism"
  type        = string
  default     = "PLAIN"
}

# Inference Environment Variables
variable "inference_environment_variables" {
  description = "Environment variables for inference container"
  type        = map(string)
  default = {
    MODEL_NAME     = "ml-classifier"
    BATCH_SIZE     = "1000"
    OUTPUT_FORMAT  = "json"
    LOG_LEVEL      = "INFO"
  }
}
