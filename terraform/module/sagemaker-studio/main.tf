# Local values for resource naming
locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  domain_name         = var.domain_name != null ? var.domain_name : "${local.name_prefix}-studio-domain"
  execution_role_name = var.execution_role_name != null ? var.execution_role_name : "${local.name_prefix}-execution-role"
  bucket_name         = var.s3_bucket_name != null ? var.s3_bucket_name : "${local.name_prefix}-ml-bucket-${var.bucket_name_suffix}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}

# S3 Bucket for ML artifacts (optional)
resource "aws_s3_bucket" "ml_artifacts" {
  count  = var.enable_s3_bucket ? 1 : 0
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "ml_artifacts" {
  count  = var.enable_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.ml_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_artifacts" {
  count  = var.enable_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.ml_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ml_artifacts" {
  count  = var.enable_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.ml_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for SageMaker execution
resource "aws_iam_role" "sagemaker_execution_role" {
  name = local.execution_role_name
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

# Basic SageMaker execution policy
resource "aws_iam_role_policy" "sagemaker_basic_access" {
  name = "SageMakerBasicAccess"
  role = aws_iam_role.sagemaker_execution_role.id

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
          "s3:GetBucketLocation",
          "s3:ListAllMyBuckets"
        ]
        Resource = var.enable_s3_bucket ? [
          aws_s3_bucket.ml_artifacts[0].arn,
          "${aws_s3_bucket.ml_artifacts[0].arn}/*"
        ] : ["*"]
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
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteNetworkInterfacePermission",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = length(var.additional_execution_role_policies)
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = var.additional_execution_role_policies[count.index]
}

# SageMaker Studio Domain
resource "aws_sagemaker_domain" "studio_domain" {
  domain_name             = local.domain_name
  auth_mode               = var.auth_mode
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids
  app_network_access_type = var.app_network_access_type
  tags                    = local.common_tags

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution_role.arn

    dynamic "sharing_settings" {
      for_each = var.sharing_settings.notebook_output_option != null ? [1] : []
      content {
        notebook_output_option = var.sharing_settings.notebook_output_option
        s3_output_path         = var.sharing_settings.s3_output_path
        s3_kms_key_id          = var.sharing_settings.s3_kms_key_id
      }
    }

    dynamic "jupyter_server_app_settings" {
      for_each = length(var.jupyter_server_app_settings) > 0 ? [var.jupyter_server_app_settings] : []
      content {
        dynamic "default_resource_spec" {
          for_each = jupyter_server_app_settings.value.default_resource_spec != null ? [jupyter_server_app_settings.value.default_resource_spec] : []
          content {
            instance_type               = default_resource_spec.value.instance_type
            lifecycle_config_arn        = default_resource_spec.value.lifecycle_config_arn
            sagemaker_image_arn         = default_resource_spec.value.sagemaker_image_arn
            sagemaker_image_version_arn = default_resource_spec.value.sagemaker_image_version_arn
          }
        }
        lifecycle_config_arns = jupyter_server_app_settings.value.lifecycle_config_arns
      }
    }

    dynamic "kernel_gateway_app_settings" {
      for_each = length(var.kernel_gateway_app_settings) > 0 ? [var.kernel_gateway_app_settings] : []
      content {
        dynamic "default_resource_spec" {
          for_each = kernel_gateway_app_settings.value.default_resource_spec != null ? [kernel_gateway_app_settings.value.default_resource_spec] : []
          content {
            instance_type               = default_resource_spec.value.instance_type
            lifecycle_config_arn        = default_resource_spec.value.lifecycle_config_arn
            sagemaker_image_arn         = default_resource_spec.value.sagemaker_image_arn
            sagemaker_image_version_arn = default_resource_spec.value.sagemaker_image_version_arn
          }
        }
        lifecycle_config_arns = kernel_gateway_app_settings.value.lifecycle_config_arns
      }
    }

    dynamic "tensor_board_app_settings" {
      for_each = length(var.tensor_board_app_settings) > 0 ? [var.tensor_board_app_settings] : []
      content {
        dynamic "default_resource_spec" {
          for_each = tensor_board_app_settings.value.default_resource_spec != null ? [tensor_board_app_settings.value.default_resource_spec] : []
          content {
            instance_type               = default_resource_spec.value.instance_type
            lifecycle_config_arn        = default_resource_spec.value.lifecycle_config_arn
            sagemaker_image_arn         = default_resource_spec.value.sagemaker_image_arn
            sagemaker_image_version_arn = default_resource_spec.value.sagemaker_image_version_arn
          }
        }
      }
    }
  }

  retention_policy {
    home_efs_file_system = "Delete"
  }
}

# Default User Profile
resource "aws_sagemaker_user_profile" "default_user" {
  domain_id         = aws_sagemaker_domain.studio_domain.id
  user_profile_name = var.user_profile_name
  tags              = local.common_tags

  user_settings {
    execution_role = aws_iam_role.sagemaker_execution_role.arn

    dynamic "sharing_settings" {
      for_each = var.sharing_settings.notebook_output_option != null ? [1] : []
      content {
        notebook_output_option = var.sharing_settings.notebook_output_option
        s3_output_path         = var.sharing_settings.s3_output_path
        s3_kms_key_id          = var.sharing_settings.s3_kms_key_id
      }
    }

    dynamic "jupyter_server_app_settings" {
      for_each = length(var.jupyter_server_app_settings) > 0 ? [var.jupyter_server_app_settings] : []
      content {
        dynamic "default_resource_spec" {
          for_each = jupyter_server_app_settings.value.default_resource_spec != null ? [jupyter_server_app_settings.value.default_resource_spec] : []
          content {
            instance_type               = default_resource_spec.value.instance_type != null ? default_resource_spec.value.instance_type : var.default_instance_type
            lifecycle_config_arn        = default_resource_spec.value.lifecycle_config_arn
            sagemaker_image_arn         = default_resource_spec.value.sagemaker_image_arn
            sagemaker_image_version_arn = default_resource_spec.value.sagemaker_image_version_arn
          }
        }
        lifecycle_config_arns = jupyter_server_app_settings.value.lifecycle_config_arns
      }
    }

    dynamic "kernel_gateway_app_settings" {
      for_each = length(var.kernel_gateway_app_settings) > 0 ? [var.kernel_gateway_app_settings] : []
      content {
        dynamic "default_resource_spec" {
          for_each = kernel_gateway_app_settings.value.default_resource_spec != null ? [kernel_gateway_app_settings.value.default_resource_spec] : []
          content {
            instance_type               = default_resource_spec.value.instance_type != null ? default_resource_spec.value.instance_type : var.default_instance_type
            lifecycle_config_arn        = default_resource_spec.value.lifecycle_config_arn
            sagemaker_image_arn         = default_resource_spec.value.sagemaker_image_arn
            sagemaker_image_version_arn = default_resource_spec.value.sagemaker_image_version_arn
          }
        }
        lifecycle_config_arns = kernel_gateway_app_settings.value.lifecycle_config_arns
      }
    }

    dynamic "tensor_board_app_settings" {
      for_each = length(var.tensor_board_app_settings) > 0 ? [var.tensor_board_app_settings] : []
      content {
        dynamic "default_resource_spec" {
          for_each = tensor_board_app_settings.value.default_resource_spec != null ? [tensor_board_app_settings.value.default_resource_spec] : []
          content {
            instance_type               = default_resource_spec.value.instance_type != null ? default_resource_spec.value.instance_type : var.default_instance_type
            lifecycle_config_arn        = default_resource_spec.value.lifecycle_config_arn
            sagemaker_image_arn         = default_resource_spec.value.sagemaker_image_arn
            sagemaker_image_version_arn = default_resource_spec.value.sagemaker_image_version_arn
          }
        }
      }
    }
  }
}
