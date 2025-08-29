# SageMaker Pipelines Module
# Creates ML training and/or inference pipelines with scheduling, using existing infrastructure

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Data sources for existing infrastructure (only if VPC integration is needed)
data "aws_vpc" "existing" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnets" "private" {
  count = var.vpc_id != "" ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

data "aws_security_group" "sagemaker" {
  count = var.sagemaker_security_group_id != "" ? 1 : 0
  id    = var.sagemaker_security_group_id
}

# IAM Role for SageMaker Training Jobs (conditional)
resource "aws_iam_role" "training_role" {
  count = var.enable_training_pipeline ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-training-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Training execution policy
resource "aws_iam_role_policy" "training_policy" {
  count = var.enable_training_pipeline ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-training-policy"
  role = aws_iam_role.training_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          [var.s3_bucket_arn],
          formatlist("%s/*", [var.s3_bucket_arn])
        )
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
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
          "iam:PassRole"
        ]
        Resource = aws_iam_role.training_role[0].arn
      }
    ]
  })
}

# Add VPC permissions for training if subnets are provided
resource "aws_iam_role_policy" "training_vpc_policy" {
  count = var.enable_training_pipeline && length(var.subnet_ids) > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-training-vpc-policy"
  role = aws_iam_role.training_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# IAM Role for SageMaker Processing Jobs (conditional)
resource "aws_iam_role" "processing_role" {
  count = var.enable_processing_pipeline ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-processing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Processing execution policy
resource "aws_iam_role_policy" "processing_policy" {
  count = var.enable_processing_pipeline ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-processing-policy"
  role = aws_iam_role.processing_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          [var.s3_bucket_arn],
          formatlist("%s/*", [var.s3_bucket_arn])
        )
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.processing_role[0].arn
      }
    ]
  })
}

# Add VPC permissions for processing if subnets are provided
resource "aws_iam_role_policy" "processing_vpc_policy" {
  count = var.enable_processing_pipeline && length(var.subnet_ids) > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-processing-vpc-policy"
  role = aws_iam_role.processing_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# SageMaker Pipeline for training (conditional)
resource "aws_sagemaker_pipeline" "training_pipeline" {
  count = var.enable_training_pipeline ? 1 : 0

  pipeline_name         = "${var.project_name}-${var.environment}-training"
  pipeline_display_name = var.training_pipeline_display_name
  role_arn             = aws_iam_role.training_role[0].arn

  pipeline_definition = jsonencode({
    Version = "2020-12-01"
    Parameters = [
      {
        Name         = "TrainingImage"
        Type         = "String"
        DefaultValue = var.training_image_uri
      }
    ]
    Steps = [
      {
        Name = "TrainingStep"
        Type = "Training"
        Arguments = merge({
          TrainingJobName = "${substr(var.project_name, 0, 8)}-train"
          RoleArn        = aws_iam_role.training_role[0].arn
          AlgorithmSpecification = {
            TrainingImage     = { Get = "Parameters.TrainingImage" }
            TrainingInputMode = "NoInput"
          }
          OutputDataConfig = {
            S3OutputPath = var.model_output_s3_path
          }
          ResourceConfig = {
            InstanceType   = var.training_instance_type
            InstanceCount  = var.training_instance_count
            VolumeSizeInGB = var.training_volume_size
          }
          StoppingCondition = {
            MaxRuntimeInSeconds = var.training_max_runtime_seconds
          }
          HyperParameters = var.training_hyperparameters
          Environment = merge(var.training_environment_variables, {
            SM_MODEL_DIR       = "/opt/ml/model"
            SM_OUTPUT_DATA_DIR = "/opt/ml/output"
          })
        }, length(var.subnet_ids) > 0 ? {
          VpcConfig = {
            SecurityGroupIds = var.security_group_ids
            Subnets         = var.subnet_ids
          }
        } : {})
      }
    ]
  })

  tags = var.tags
}

# SageMaker Pipeline for processing (conditional)
resource "aws_sagemaker_pipeline" "processing_pipeline" {
  count = var.enable_processing_pipeline ? 1 : 0

  pipeline_name         = "${var.project_name}-${var.environment}-processing"
  pipeline_display_name = var.processing_pipeline_display_name
  role_arn             = aws_iam_role.processing_role[0].arn

  pipeline_definition = jsonencode({
    Version = "2020-12-01"
    Parameters = [
      {
        Name         = "ProcessingImage"
        Type         = "String"
        DefaultValue = var.inference_image_uri
      }
    ]
    Steps = [
      {
        Name = "ProcessingStep"
        Type = "Processing"
        Arguments = merge({
          ProcessingJobName = "${substr(var.project_name, 0, 8)}-proc"
          RoleArn          = aws_iam_role.processing_role[0].arn
          AppSpecification = {
            ImageUri = { Get = "Parameters.ProcessingImage" }
          }
          ProcessingInputs = [
            {
              InputName = "input"
              S3Input = {
                S3Uri                = var.inference_input_s3_path
                LocalPath           = "/opt/ml/processing/input"
                S3DataType          = "S3Prefix"
                S3InputMode         = "File"
                S3DataDistributionType = "FullyReplicated"
              }
            }
          ]
          ProcessingOutputConfig = {
            Outputs = [
              {
                OutputName = "output"
                S3Output = {
                  S3Uri           = var.inference_output_s3_path
                  LocalPath       = "/opt/ml/processing/output"
                  S3UploadMode    = "EndOfJob"
                }
              }
            ]
          }
          ProcessingResources = {
            ClusterConfig = {
              InstanceType   = var.inference_instance_type
              InstanceCount  = var.inference_instance_count
              VolumeSizeInGB = var.inference_volume_size
            }
          }
          StoppingCondition = {
            MaxRuntimeInSeconds = var.inference_max_runtime_seconds
          }
          Environment = var.processing_environment_variables
        }, length(var.subnet_ids) > 0 ? {
          NetworkConfig = {
            VpcConfig = {
              SecurityGroupIds = var.security_group_ids
              Subnets         = var.subnet_ids
            }
          }
        } : {})
      }
    ]
  })

  tags = var.tags
}

# EventBridge Rule for training (conditional)
resource "aws_cloudwatch_event_rule" "training_schedule" {
  count = var.enable_training_schedule && var.enable_training_pipeline ? 1 : 0

  name                = "${var.project_name}-${var.environment}-training-schedule"
  description         = "Training pipeline schedule"
  schedule_expression = var.training_schedule_expression
  state              = var.training_schedule_enabled ? "ENABLED" : "DISABLED"

  tags = var.tags
}

# EventBridge Rule for processing (conditional)
resource "aws_cloudwatch_event_rule" "processing_schedule" {
  count = var.enable_processing_schedule && var.enable_processing_pipeline ? 1 : 0

  name                = "${var.project_name}-${var.environment}-processing-schedule"
  description         = "Processing pipeline schedule"
  schedule_expression = var.processing_schedule_expression
  state              = var.processing_schedule_enabled ? "ENABLED" : "DISABLED"

  tags = var.tags
}

# IAM Role for EventBridge
resource "aws_iam_role" "scheduler_role" {
  count = (var.enable_training_schedule && var.enable_training_pipeline) || (var.enable_processing_schedule && var.enable_processing_pipeline) ? 1 : 0

  name = "${var.project_name}-${var.environment}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Scheduler policy
resource "aws_iam_role_policy" "scheduler_policy" {
  count = (var.enable_training_schedule && var.enable_training_pipeline) || (var.enable_processing_schedule && var.enable_processing_pipeline) ? 1 : 0

  name = "${var.project_name}-${var.environment}-scheduler-policy"
  role = aws_iam_role.scheduler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:StartPipelineExecution"
        ]
        Resource = compact([
          var.enable_training_pipeline ? aws_sagemaker_pipeline.training_pipeline[0].arn : "",
          var.enable_processing_pipeline ? aws_sagemaker_pipeline.processing_pipeline[0].arn : ""
        ])
      }
    ]
  })
}

# EventBridge Target for training
resource "aws_cloudwatch_event_target" "training_target" {
  count = var.enable_training_schedule && var.enable_training_pipeline ? 1 : 0

  rule      = aws_cloudwatch_event_rule.training_schedule[0].name
  target_id = "SageMakerTrainingPipelineTarget"
  arn       = aws_sagemaker_pipeline.training_pipeline[0].arn
  role_arn  = aws_iam_role.scheduler_role[0].arn

  sagemaker_pipeline_target {
    pipeline_parameter_list {
      name  = "TrainingImage"
      value = var.training_image_uri
    }
  }
}

# EventBridge Target for processing
resource "aws_cloudwatch_event_target" "processing_target" {
  count = var.enable_processing_schedule && var.enable_processing_pipeline ? 1 : 0

  rule      = aws_cloudwatch_event_rule.processing_schedule[0].name
  target_id = "SageMakerProcessingPipelineTarget"
  arn       = aws_sagemaker_pipeline.processing_pipeline[0].arn
  role_arn  = aws_iam_role.scheduler_role[0].arn

  sagemaker_pipeline_target {
    pipeline_parameter_list {
      name  = "ProcessingImage"
      value = var.inference_image_uri
    }
  }
}