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

# EventBridge scheduler policy
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
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:ListTrainingJobs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.training_role.arn
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

# Default Lambda function for training job launching (when custom launcher is not provided)
resource "aws_lambda_function" "default_training_launcher" {
  count         = var.enable_scheduling && !var.enable_custom_launcher ? 1 : 0
  function_name = "${local.name_prefix}-default-training-launcher"
  role          = aws_iam_role.lambda_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 300
  tags          = local.common_tags

  filename = "${path.module}/lambda/default_launcher.zip"

  environment {
    variables = {
      TRAINING_ROLE_ARN       = aws_iam_role.training_role.arn
      PROJECT_NAME            = var.project_name
      ENVIRONMENT             = var.environment
      TRAINING_IMAGE          = var.training_image
      TRAINING_INPUT_MODE     = var.training_input_mode
      INSTANCE_TYPE           = var.instance_type
      INSTANCE_COUNT          = tostring(var.instance_count)
      VOLUME_SIZE_GB          = tostring(var.volume_size_gb)
      MAX_RUNTIME_SECONDS     = tostring(var.max_runtime_seconds)
      OUTPUT_DATA_S3_PATH     = var.output_data_s3_path
      HYPERPARAMETERS         = jsonencode(var.hyperparameters)
      ENVIRONMENT_VARIABLES   = jsonencode(merge(
        var.environment_variables,
        var.mlflow_tracking_server_arn != null ? {
          MLFLOW_TRACKING_URI = var.mlflow_tracking_uri
        } : {}
      ))
      INPUT_DATA_CONFIG       = jsonencode(var.input_data_config)
      TRAINING_JOB_NAME_PREFIX = var.training_job_name_prefix != null ? var.training_job_name_prefix : "${local.name_prefix}-training"
    }
  }

  depends_on = [data.archive_file.default_launcher_zip]
}

# Create default Lambda function code if custom launcher is not enabled
data "archive_file" "default_launcher_zip" {
  count       = var.enable_scheduling && !var.enable_custom_launcher ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/lambda/default_launcher.zip"
  
  source {
    content = templatefile("${path.module}/lambda/default_launcher.py", {
      # Template variables if needed
    })
    filename = "index.py"
  }
}

# EventBridge target for default Lambda launcher
resource "aws_cloudwatch_event_target" "default_lambda_target" {
  count     = var.enable_scheduling && !var.enable_custom_launcher ? 1 : 0
  rule      = aws_cloudwatch_event_rule.training_schedule[0].name
  target_id = "DefaultLambdaTrainingJobLauncher"
  arn       = aws_lambda_function.default_training_launcher[0].arn
}

# Lambda permission for EventBridge (default launcher)
resource "aws_lambda_permission" "allow_eventbridge_default" {
  count         = var.enable_scheduling && !var.enable_custom_launcher ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.default_training_launcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.training_schedule[0].arn
}

# Lambda function for custom training job logic (optional)
resource "aws_lambda_function" "training_job_launcher" {
  count         = var.enable_custom_launcher ? 1 : 0
  filename      = var.lambda_zip_path
  function_name = "${local.name_prefix}-training-launcher"
  role          = aws_iam_role.lambda_role[0].arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  tags          = local.common_tags

  environment {
    variables = merge(
      var.lambda_environment_variables,
      {
        TRAINING_ROLE_ARN = aws_iam_role.training_role.arn
        PROJECT_NAME      = var.project_name
        ENVIRONMENT       = var.environment
      },
      var.mlflow_tracking_server_arn != null ? {
        MLFLOW_TRACKING_URI = var.mlflow_tracking_uri
      } : {}
    )
  }
}

# IAM Role for Lambda function (created when scheduling is enabled)
resource "aws_iam_role" "lambda_role" {
  count = var.enable_scheduling ? 1 : 0
  name  = "${local.name_prefix}-lambda-role"
  tags  = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count      = var.enable_scheduling ? 1 : 0
  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda SageMaker execution policy
resource "aws_iam_role_policy" "lambda_sagemaker_policy" {
  count = var.enable_scheduling ? 1 : 0
  name  = "LambdaSageMakerAccess"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:ListTrainingJobs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.training_role.arn
      }
    ]
  })
}

# EventBridge target for Lambda (when using custom launcher)
resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = var.enable_custom_launcher && var.enable_scheduling ? 1 : 0
  rule      = aws_cloudwatch_event_rule.training_schedule[0].name
  target_id = "LambdaTrainingJobLauncher"
  arn       = aws_lambda_function.training_job_launcher[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_custom_launcher && var.enable_scheduling ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.training_job_launcher[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.training_schedule[0].arn
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
