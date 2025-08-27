# Local values for resource naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  tracking_server_name = var.tracking_server_name != null ? var.tracking_server_name : "${local.name_prefix}-mlflow"
  role_name           = var.mlflow_role_name != null ? var.mlflow_role_name : "${local.name_prefix}-mlflow-role"
  
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Service     = "mlflow"
  })
}

# S3 Bucket for MLflow artifacts (optional - can use existing bucket)
resource "aws_s3_bucket" "mlflow_artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = var.artifact_store_uri != null ? null : "${local.name_prefix}-mlflow-artifacts-${var.bucket_name_suffix}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.mlflow_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.mlflow_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mlflow_artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.mlflow_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for MLflow Tracking Server
resource "aws_iam_role" "mlflow_role" {
  name = local.role_name
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Basic policy for MLflow tracking server
resource "aws_iam_role_policy" "mlflow_basic_policy" {
  name = "MLflowBasicAccess"
  role = aws_iam_role.mlflow_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.create_s3_bucket ? [
          aws_s3_bucket.mlflow_artifacts[0].arn,
          "${aws_s3_bucket.mlflow_artifacts[0].arn}/*"
        ] : [
          "arn:aws:s3:::${var.artifact_store_uri}",
          "arn:aws:s3:::${var.artifact_store_uri}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Additional policy for KMS access if KMS key is provided
resource "aws_iam_role_policy" "mlflow_kms_policy" {
  count = var.kms_key_id != null ? 1 : 0
  name  = "MLflowKMSAccess"
  role  = aws_iam_role.mlflow_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = var.kms_key_id
      }
    ]
  })
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = length(var.additional_role_policies)
  role       = aws_iam_role.mlflow_role.name
  policy_arn = var.additional_role_policies[count.index]
}

# SageMaker MLflow Tracking Server
resource "aws_sagemaker_mlflow_tracking_server" "mlflow" {
  tracking_server_name = local.tracking_server_name
  role_arn            = aws_iam_role.mlflow_role.arn
  
  # Use created S3 bucket or provided URI
  artifact_store_uri = var.create_s3_bucket ? "s3://${aws_s3_bucket.mlflow_artifacts[0].bucket}" : var.artifact_store_uri
  
  # MLflow version
  mlflow_version = var.mlflow_version
  
  # Instance configuration
  automatic_model_registration = var.automatic_model_registration
  weekly_maintenance_window_start = var.weekly_maintenance_window_start
  
  tags = local.common_tags
}
