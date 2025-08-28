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
  default     = "prod"
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
  default     = "mlflow-prod-mlflow"
}

# S3 Configuration
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for ML artifacts"
  type        = string
  default     = "arn:aws:s3:::mlflow-prod-mlflow-artifacts-zali-prod"
}

variable "training_data_s3_uri" {
  description = "S3 URI for training data"
  type        = string
  default     = "s3://mlflow-prod-mlflow-artifacts-zali-prod/datasets/training/"
}

variable "model_output_s3_uri" {
  description = "S3 URI for model outputs"
  type        = string
  default     = "s3://mlflow-prod-mlflow-artifacts-zali-prod/models/"
}

variable "inference_input_s3_uri" {
  description = "S3 URI for inference input data"
  type        = string
  default     = "s3://mlflow-prod-mlflow-artifacts-zali-prod/inference/input/"
}

variable "inference_output_s3_uri" {
  description = "S3 URI for inference output data"
  type        = string
  default     = "s3://mlflow-prod-mlflow-artifacts-zali-prod/inference/output/"
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

# Training Configuration (Production values)
variable "training_instance_type" {
  description = "Instance type for training jobs"
  type        = string
  default     = "ml.m5.xlarge"  # Larger for production
}

variable "training_instance_count" {
  description = "Number of instances for training"
  type        = number
  default     = 1
}

variable "training_volume_size_gb" {
  description = "EBS volume size for training jobs (GB)"
  type        = number
  default     = 100  # Larger for production datasets
}

variable "max_runtime_seconds" {
  description = "Maximum runtime for training jobs (seconds)"
  type        = number
  default     = 7200  # 2 hours for production
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
  default     = "cron(0 1 * * ? *)"  # Daily at 1 AM UTC
}

variable "training_schedule_enabled" {
  description = "Whether the training schedule is enabled"
  type        = bool
  default     = true  # Enabled by default in production
}

# Training Hyperparameters
variable "training_hyperparameters" {
  description = "Hyperparameters for training algorithm"
  type        = map(string)
  default = {
    n_estimators    = "200"  # More trees for production
    max_depth       = "15"   # Deeper trees for production
    random_state    = "42"
    test_size       = "0.2"
    model_name      = "prod-classifier"
    experiment_name = "production-experiments"
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
    LOG_LEVEL       = "INFO"
    FEATURE_STORE   = "s3"
  }
}

# Inference Configuration (Production values)
variable "inference_instance_type" {
  description = "Instance type for inference jobs"
  type        = string
  default     = "ml.m5.xlarge"  # Larger for production
}

variable "inference_instance_count" {
  description = "Number of instances for inference"
  type        = number
  default     = 2  # Multiple instances for production
}

variable "inference_volume_size_gb" {
  description = "EBS volume size for inference jobs (GB)"
  type        = number
  default     = 100  # Larger for production datasets
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
  default     = "cron(0 5 * * ? *)"  # Daily at 5 AM UTC
}

variable "inference_schedule_enabled" {
  description = "Whether the inference schedule is enabled"
  type        = bool
  default     = true  # Enabled by default in production
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
  default     = "ml-predictions-prod"
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
    MODEL_NAME     = "prod-classifier"
    BATCH_SIZE     = "5000"  # Larger batches for production
    OUTPUT_FORMAT  = "json"
    LOG_LEVEL      = "INFO"
    KAFKA_TIMEOUT  = "60"    # Longer timeout for production
    RETRY_ATTEMPTS = "5"     # More retries for production
  }
}
