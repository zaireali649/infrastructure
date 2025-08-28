# SageMaker Processing Jobs Module
# Supports custom Docker containers for daily scoring with Kafka output

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = merge(var.tags, {
    Module      = "sagemaker-processing-jobs"
    Environment = var.environment
    Project     = var.project_name
  })
}

# IAM Role for SageMaker Processing Jobs
resource "aws_iam_role" "processing_role" {
  name = "${local.name_prefix}-processing-role"

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

  tags = local.common_tags
}

# Custom policy for processing jobs
resource "aws_iam_role_policy" "processing_policy" {
  name = "${local.name_prefix}-processing-policy"
  role = aws_iam_role.processing_role.id

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
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.kafka_secret_arn != null ? [var.kafka_secret_arn] : []
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = var.msk_cluster_arn != null ? [var.msk_cluster_arn] : []
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = var.msk_cluster_arn != null ? ["${var.msk_cluster_arn}/*"] : []
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

# SageMaker Pipeline for processing/scoring
resource "aws_sagemaker_pipeline" "processing_pipeline" {
  pipeline_name         = "${local.name_prefix}-processing-pipeline"
  pipeline_display_name = "${var.project_name} ${var.environment} Daily Scoring Pipeline"
  role_arn             = aws_iam_role.pipeline_role.arn

  pipeline_definition = jsonencode({
    Version = "2020-12-01"
    Metadata = {
      Version = 1
    }
    Parameters = [
      {
        Name         = "ProcessingImage"
        Type         = "String"
        DefaultValue = var.processing_image_uri
      },
      {
        Name         = "InputDataPath"
        Type         = "String"
        DefaultValue = var.input_data_s3_path
      },
      {
        Name         = "OutputPath"
        Type         = "String"
        DefaultValue = var.output_data_s3_path
      },
      {
        Name         = "InstanceType"
        Type         = "String"
        DefaultValue = var.instance_type
      }
    ]
    Steps = [
      {
        Name = "ProcessingStep"
        Type = "Processing"
        Arguments = {
          ProcessingJobName = "${local.name_prefix}-processing-{execution-id}"
          RoleArn          = aws_iam_role.processing_role.arn
          AppSpecification = {
            ImageUri = { Get = "Parameters.ProcessingImage" }
          }
          ProcessingInputs = [
            {
              InputName = "input"
              S3Input = {
                S3Uri                = { Get = "Parameters.InputDataPath" }
                LocalPath           = "/opt/ml/processing/input"
                S3DataType          = "S3Prefix"
                S3InputMode         = "File"
                S3DataDistributionType = "FullyReplicated"
                S3CompressionType   = "None"
              }
            }
          ]
          ProcessingOutputConfig = var.enable_s3_audit_output ? {
            Outputs = [
              {
                OutputName = "output"
                S3Output = {
                  S3Uri           = { Get = "Parameters.OutputPath" }
                  LocalPath       = "/opt/ml/processing/output"
                  S3UploadMode    = "EndOfJob"
                }
              }
            ]
          } : null
          ProcessingResources = {
            ClusterConfig = {
              InstanceType   = { Get = "Parameters.InstanceType" }
              InstanceCount  = var.instance_count
              VolumeSizeInGB = var.volume_size_gb
            }
          }
          StoppingCondition = {
            MaxRuntimeInSeconds = var.max_runtime_seconds
          }
          Environment = merge(var.environment_variables, {
            MLFLOW_TRACKING_URI = var.mlflow_tracking_uri
            MLFLOW_MODEL_URI   = var.mlflow_model_uri
            INPUT_S3_PREFIX    = var.input_data_s3_path
            KAFKA_BOOTSTRAP    = var.kafka_bootstrap_servers
            KAFKA_TOPIC        = var.kafka_topic
            KAFKA_SECRET_ARN   = var.kafka_secret_arn
          })
          NetworkConfig = var.vpc_config != null ? {
            VpcConfig = {
              SecurityGroupIds = var.vpc_config.security_group_ids
              Subnets         = var.vpc_config.subnet_ids
            }
          } : null
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role for SageMaker Pipeline
resource "aws_iam_role" "pipeline_role" {
  name = "${local.name_prefix}-processing-pipeline-role"

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

  tags = local.common_tags
}

# Pipeline execution policy
resource "aws_iam_role_policy" "pipeline_policy" {
  name = "${local.name_prefix}-processing-pipeline-policy"
  role = aws_iam_role.pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateProcessingJob",
          "sagemaker:DescribeProcessingJob",
          "sagemaker:StopProcessingJob"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.processing_role.arn
      }
    ]
  })
}

# EventBridge Rule for scheduling (daily)
resource "aws_cloudwatch_event_rule" "processing_schedule" {
  count = var.enable_scheduling ? 1 : 0

  name                = "${local.name_prefix}-processing-schedule"
  description         = "Daily processing pipeline schedule"
  schedule_expression = var.schedule_expression
  state              = var.schedule_enabled ? "ENABLED" : "DISABLED"

  tags = local.common_tags
}

# IAM Role for EventBridge
resource "aws_iam_role" "scheduler_role" {
  count = var.enable_scheduling ? 1 : 0
  name  = "${local.name_prefix}-processing-scheduler-role"

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

  tags = local.common_tags
}

# Scheduler policy
resource "aws_iam_role_policy" "scheduler_policy" {
  count = var.enable_scheduling ? 1 : 0
  name  = "${local.name_prefix}-processing-scheduler-policy"
  role  = aws_iam_role.scheduler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:StartPipelineExecution"
        ]
        Resource = aws_sagemaker_pipeline.processing_pipeline.arn
      }
    ]
  })
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "processing_target" {
  count = var.enable_scheduling ? 1 : 0

  rule      = aws_cloudwatch_event_rule.processing_schedule[0].name
  target_id = "SageMakerProcessingPipelineTarget"
  arn       = aws_sagemaker_pipeline.processing_pipeline.arn
  role_arn  = aws_iam_role.scheduler_role[0].arn

  sagemaker_pipeline_target {
    pipeline_parameter_list = {
      ProcessingImage = var.processing_image_uri
      InputDataPath   = var.input_data_s3_path
      OutputPath      = var.output_data_s3_path
      InstanceType    = var.instance_type
    }
  }
}
