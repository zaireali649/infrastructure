# SageMaker Pipelines - Staging Environment
# Weekly training + Daily scoring with hardcoded configuration

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = local.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

# Get existing MLflow tracking server
data "aws_sagemaker_mlflow_tracking_server" "existing" {
  tracking_server_name = local.mlflow_tracking_server_name
}

# Local values - all configuration hardcoded here
locals {
  # Core configuration
  project_name = "ml-platform"
  environment  = "staging"
  owner       = "zali"
  aws_region  = "us-east-1"
  
  # MLflow configuration
  mlflow_tracking_server_name = "mlflow-staging-mlflow"
  
  # ECR and container configuration
  account_id = data.aws_caller_identity.current.account_id
  training_image_uri  = "${local.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/${local.project_name}-${local.environment}-training:latest"
  inference_image_uri = "${local.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/${local.project_name}-${local.environment}-inference:latest"
  
  # S3 configuration
  s3_bucket_name = "mlflow-${local.environment}-mlflow-artifacts-${local.owner}-${local.environment}"
  s3_bucket_arn  = "arn:aws:s3:::${local.s3_bucket_name}"
  
  # Data paths
  input_data_s3_path    = "s3://${local.s3_bucket_name}/datasets/training/"
  model_output_s3_path  = "s3://${local.s3_bucket_name}/models/"
  inference_input_s3_path  = "s3://${local.s3_bucket_name}/inference/input/"
  inference_output_s3_path = "s3://${local.s3_bucket_name}/inference/output/"
  
  # MSK Kafka configuration (hardcoded for staging)
  kafka_cluster_name = "${local.project_name}-${local.environment}-kafka"
  kafka_topic = "poem-predictions-${local.environment}"
  
  # Scheduling configuration
  # Weekly training on Sundays at 2 AM UTC
  training_schedule_expression = "cron(0 2 ? * SUN *)"
  # Daily scoring at 6 AM UTC
  inference_schedule_expression = "cron(0 6 * * ? *)"
  
  # Instance configuration
  training_instance_type = "ml.m5.large"
  inference_instance_type = "ml.m5.large"
  
  # Training hyperparameters
  training_hyperparameters = {
    n_estimators    = "100"
    max_depth       = "10"
    random_state    = "42"
    test_size       = "0.2"
    learning_rate   = "0.1"
  }
  
  # Common tags
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    Owner       = local.owner
    Team        = "ML-Engineering"
    ManagedBy   = "terraform"
    Repository  = "infrastructure"
  }
  
  # VPC configuration
  vpc_cidr = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
}

# VPC for private subnet networking
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-igw"
  })
}

# Public subnets
resource "aws_subnet" "public" {
  count = length(local.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-${count.index + 1}"
    Type = "public"
  })
}

# Private subnets
resource "aws_subnet" "private" {
  count = length(local.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-private-${count.index + 1}"
    Type = "private"
  })
}

# NAT Gateways
resource "aws_eip" "nat" {
  count = length(aws_subnet.public)
  
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count = length(aws_subnet.public)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-nat-${count.index + 1}"
  })
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-private-rt-${count.index + 1}"
  })
}

# Route table associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group for SageMaker jobs
resource "aws_security_group" "sagemaker" {
  name_prefix = "${local.project_name}-${local.environment}-sagemaker-"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound from same security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-sagemaker-sg"
  })
}

# Security Group for MSK Kafka
resource "aws_security_group" "kafka" {
  name_prefix = "${local.project_name}-${local.environment}-kafka-"
  vpc_id      = aws_vpc.main.id

  # Allow Kafka traffic from SageMaker
  ingress {
    from_port       = 9092
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
  }

  # Allow Zookeeper traffic from SageMaker
  ingress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker.id]
  }

  # Allow traffic within Kafka cluster
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-kafka-sg"
  })
}

# MSK Kafka Cluster
resource "aws_msk_cluster" "kafka" {
  cluster_name           = local.kafka_cluster_name
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = aws_subnet.private[*].id
    security_groups = [aws_security_group.kafka.id]
    
    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.kafka.name
      }
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Group for Kafka
resource "aws_cloudwatch_log_group" "kafka" {
  name              = "/aws/msk/${local.kafka_cluster_name}"
  retention_in_days = 14

  tags = local.common_tags
}

# ECR Repositories
resource "aws_ecr_repository" "training" {
  name                 = "${local.project_name}-${local.environment}-training"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "inference" {
  name                 = "${local.project_name}-${local.environment}-inference"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# Weekly Training Pipeline
module "training_pipeline" {
  source = "../../module/sagemaker-training-jobs"

  project_name = local.project_name
  environment  = local.environment

  # Training configuration
  training_image_uri     = local.training_image_uri
  input_data_s3_path     = local.input_data_s3_path
  output_data_s3_path    = local.model_output_s3_path
  s3_bucket_arn         = local.s3_bucket_arn

  # Instance configuration
  instance_type     = local.training_instance_type
  instance_count    = 1
  volume_size_gb    = 30
  max_runtime_seconds = 3600

  # MLflow integration
  mlflow_tracking_uri = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url

  # Hyperparameters
  hyperparameters = local.training_hyperparameters

  # Environment variables
  environment_variables = {
    MLFLOW_TRACKING_URI = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
    AWS_DEFAULT_REGION  = local.aws_region
    ENVIRONMENT         = local.environment
    OWNER              = local.owner
  }

  # Networking
  vpc_config = {
    security_group_ids = [aws_security_group.sagemaker.id]
    subnet_ids        = aws_subnet.private[*].id
  }

  # Weekly scheduling
  enable_scheduling   = true
  schedule_expression = local.training_schedule_expression
  schedule_enabled    = false  # Start disabled for testing

  tags = local.common_tags
}

# Daily Scoring Pipeline
module "inference_pipeline" {
  source = "../../module/sagemaker-processing-jobs"

  project_name = local.project_name
  environment  = local.environment

  # Processing configuration
  processing_image_uri   = local.inference_image_uri
  input_data_s3_path     = local.inference_input_s3_path
  output_data_s3_path    = local.inference_output_s3_path
  s3_bucket_arn         = local.s3_bucket_arn
  enable_s3_audit_output = true

  # Instance configuration
  instance_type     = local.inference_instance_type
  instance_count    = 1
  volume_size_gb    = 30
  max_runtime_seconds = 1800  # 30 minutes

  # MLflow integration
  mlflow_tracking_uri = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
  mlflow_model_uri   = "models:/poem-model/Production"

  # Kafka configuration
  kafka_bootstrap_servers = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
  kafka_topic            = local.kafka_topic
  msk_cluster_arn        = aws_msk_cluster.kafka.arn

  # Environment variables
  environment_variables = {
    MLFLOW_TRACKING_URI = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
    MLFLOW_MODEL_URI   = "models:/poem-model/Production"
    INPUT_S3_PREFIX    = local.inference_input_s3_path
    KAFKA_BOOTSTRAP    = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
    KAFKA_TOPIC        = local.kafka_topic
    AWS_DEFAULT_REGION = local.aws_region
    ENVIRONMENT        = local.environment
  }

  # Networking
  vpc_config = {
    security_group_ids = [aws_security_group.sagemaker.id]
    subnet_ids        = aws_subnet.private[*].id
  }

  # Daily scheduling
  enable_scheduling   = true
  schedule_expression = local.inference_schedule_expression
  schedule_enabled    = false  # Start disabled for testing

  tags = local.common_tags
}