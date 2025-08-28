# Local values for resource naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Training job configuration
  job_definition_name = var.job_definition_name != null ? var.job_definition_name : "${local.name_prefix}-training-job"
  training_role_name  = var.training_role_name != null ? var.training_role_name : "${local.name_prefix}-training-role"
  scheduler_role_name = var.scheduler_role_name != null ? var.scheduler_role_name : "${local.name_prefix}-scheduler-role"
  
  # EventBridge rule name
  schedule_rule_name = var.schedule_rule_name != null ? var.schedule_rule_name : "${local.name_prefix}-training-schedule"
  
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Service     = "sagemaker-training"
  })
}

# IAM Role for SageMaker Training Jobs
resource "aws_iam_role" "training_role" {
  name = local.training_role_name
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

# Basic SageMaker training policy
resource "aws_iam_role_policy" "training_basic_policy" {
  name = "SageMakerTrainingBasicAccess"
  role = aws_iam_role.training_role.id

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
        Resource = var.s3_bucket_arn != null ? [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
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

# MLflow integration policy
resource "aws_iam_role_policy" "mlflow_integration_policy" {
  count = var.mlflow_tracking_server_arn != null ? 1 : 0
  name  = "MLflowIntegrationAccess"
  role  = aws_iam_role.training_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:DescribeTrackingServer",
          "sagemaker:GetTrackingServerUrl",
          "sagemaker:CreateModel",
          "sagemaker:CreateModelPackage",
          "sagemaker:CreateModelPackageGroup",
          "sagemaker:DescribeModel",
          "sagemaker:DescribeModelPackage",
          "sagemaker:DescribeModelPackageGroup",
          "sagemaker:ListModelPackages",
          "sagemaker:UpdateModelPackage"
        ]
        Resource = [
          var.mlflow_tracking_server_arn,
          "arn:aws:sagemaker:*:*:model/*",
          "arn:aws:sagemaker:*:*:model-package/*",
          "arn:aws:sagemaker:*:*:model-package-group/*"
        ]
      }
    ]
  })
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional_training_policies" {
  count      = length(var.additional_training_role_policies)
  role       = aws_iam_role.training_role.name
  policy_arn = var.additional_training_role_policies[count.index]
}

# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "scheduler_role" {
  count = var.enable_scheduling ? 1 : 0
  name  = local.scheduler_role_name
  tags  = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# EventBridge scheduler policy for SageMaker Pipeline execution
resource "aws_iam_role_policy" "scheduler_policy" {
  count = var.enable_scheduling ? 1 : 0
  name  = "EventBridgeSchedulerAccess"
  role  = aws_iam_role.scheduler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipelineExecution",
          "sagemaker:StopPipelineExecution",
          "sagemaker:ListPipelineExecutions",
          "sagemaker:DescribePipeline"
        ]
        Resource = var.enable_scheduling ? aws_sagemaker_pipeline.training_pipeline[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.training_role.arn,
          var.enable_scheduling ? aws_iam_role.pipeline_role[0].arn : aws_iam_role.training_role.arn
        ]
      }
    ]
  })
}

# EventBridge Rule for scheduling training jobs
resource "aws_cloudwatch_event_rule" "training_schedule" {
  count               = var.enable_scheduling ? 1 : 0
  name                = local.schedule_rule_name
  description         = "Schedule for SageMaker training jobs"
  schedule_expression = var.schedule_expression
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"
  tags                = local.common_tags
}

# SageMaker Pipeline for training jobs
resource "aws_sagemaker_pipeline" "training_pipeline" {
  count               = var.enable_scheduling ? 1 : 0
  pipeline_name       = "${local.name_prefix}-training-pipeline"
  pipeline_display_name = "${local.name_prefix} Training Pipeline"
  pipeline_description = "Automated training pipeline for ${var.project_name} in ${var.environment}"
  role_arn           = aws_iam_role.pipeline_role[0].arn
  
  pipeline_definition = jsonencode({
    Version = "2020-12-01"
    Metadata = {}
    Parameters = [
      {
        Name = "TrainingJobName"
        Type = "String"
        DefaultValue = "${var.training_job_name_prefix != null ? var.training_job_name_prefix : "${local.name_prefix}-training"}-$(aws.events.event.ingestion-time)"
      },
      {
        Name = "InputDataPath"
        Type = "String"
        DefaultValue = length(var.input_data_config) > 0 ? var.input_data_config[0].DataSource.S3DataSource.S3Uri : ""
      }
    ]
    Steps = [
      {
        Name = "TrainingStep"
        Type = "Training"
        Arguments = {
          TrainingJobName = {
            Get = "Parameters.TrainingJobName"
          }
          RoleArn = aws_iam_role.training_role.arn
          AlgorithmSpecification = {
            TrainingImage = var.training_image
            TrainingInputMode = var.training_input_mode
          }
          InputDataConfig = var.input_data_config
          OutputDataConfig = {
            S3OutputPath = var.output_data_s3_path
          }
          ResourceConfig = {
            InstanceType = var.instance_type
            InstanceCount = var.instance_count
            VolumeSizeInGB = var.volume_size_gb
          }
          StoppingCondition = {
            MaxRuntimeInSeconds = var.max_runtime_seconds
          }
          HyperParameters = var.hyperparameters
          Environment = merge(
            var.environment_variables,
            var.mlflow_tracking_server_arn != null ? {
              MLFLOW_TRACKING_URI = var.mlflow_tracking_uri
            } : {}
          )
          Tags = [
            for k, v in local.common_tags : {
              Key = k
              Value = v
            }
          ]
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role for SageMaker Pipeline
resource "aws_iam_role" "pipeline_role" {
  count = var.enable_scheduling ? 1 : 0
  name  = "${local.name_prefix}-pipeline-role"
  tags  = local.common_tags

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

# SageMaker Pipeline execution policy
resource "aws_iam_role_policy" "pipeline_execution_policy" {
  count = var.enable_scheduling ? 1 : 0
  name  = "SageMakerPipelineExecutionAccess"
  role  = aws_iam_role.pipeline_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:ListTrainingJobs",
          "sagemaker:CreateModel",
          "sagemaker:CreateModelPackage",
          "sagemaker:CreateModelPackageGroup",
          "sagemaker:DescribeModel",
          "sagemaker:DescribeModelPackage",
          "sagemaker:DescribeModelPackageGroup",
          "sagemaker:ListModelPackages",
          "sagemaker:UpdateModelPackage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.training_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_bucket_arn != null ? [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
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
      }
    ]
  })
}

# EventBridge target for SageMaker Pipeline
resource "aws_cloudwatch_event_target" "pipeline_target" {
  count     = var.enable_scheduling ? 1 : 0
  rule      = aws_cloudwatch_event_rule.training_schedule[0].name
  target_id = "SageMakerPipelineTarget"
  arn       = aws_sagemaker_pipeline.training_pipeline[0].arn
  role_arn  = aws_iam_role.scheduler_role[0].arn

  sagemaker_pipeline_parameters {
    pipeline_parameter_list = {
      TrainingJobName = "${var.training_job_name_prefix != null ? var.training_job_name_prefix : "${local.name_prefix}-training"}-$(aws.events.event.ingestion-time)"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
