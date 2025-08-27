# SageMaker Training Jobs Terraform Module

This Terraform module creates AWS SageMaker training jobs with scheduled execution, MLflow integration for experiment tracking and model registration, and optional custom Lambda launchers for advanced workflows.

## Features

- **Automated Training Jobs**: Scheduled SageMaker training jobs using EventBridge (cron-based)
- **MLflow Integration**: Automatic experiment tracking and model registration
- **Flexible Instance Configuration**: Support for various instance types and distributed training
- **Cost Optimization**: Optional managed spot training support
- **Custom Launchers**: Optional Lambda function for complex training logic
- **Network Isolation**: VPC support for secure training environments
- **Monitoring**: Built-in profiling and debugging configuration
- **Checkpoint Support**: Automatic checkpointing for fault tolerance

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EventBridge Scheduler                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Cron Expression                          │   │
│  │       (e.g., daily at 2 AM UTC)                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              SageMaker Training Job                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  • Docker Container (ECR Image)                   │   │
│  │  • Instance Configuration                          │   │
│  │  • Hyperparameters                                 │   │
│  │  • Data Input/Output                               │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  MLflow Integration                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  • Experiment Tracking                             │   │
│  │  • Model Registration                              │   │
│  │  • Artifact Storage                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "sagemaker_training" {
  source = "../../terraform/module/sagemaker-training-jobs"

  project_name    = "ml-pipeline"
  environment     = "staging"
  
  # Training configuration
  training_image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-training-image:latest"
  instance_type       = "ml.m5.large"
  instance_count      = 1
  volume_size_gb      = 50
  max_runtime_seconds = 3600  # 1 hour

  # Data configuration
  input_data_config = [
    {
      ChannelName = "training"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = "s3://my-ml-bucket/training-data/"
        }
      }
      ContentType = "application/x-parquet"
      InputMode   = "File"
    }
  ]
  
  output_data_s3_path = "s3://my-ml-bucket/model-artifacts/"
  s3_bucket_arn       = "arn:aws:s3:::my-ml-bucket"

  # Scheduling
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
  schedule_enabled    = true

  # MLflow integration
  mlflow_tracking_server_arn = "arn:aws:sagemaker:us-east-1:123456789012:mlflow-tracking-server/my-mlflow"
  mlflow_tracking_uri        = "https://mlflow.us-east-1.amazonaws.com/tracking-server/my-mlflow"
  enable_mlflow_integration  = true

  # Hyperparameters
  hyperparameters = {
    epochs        = "10"
    learning_rate = "0.001"
    batch_size    = "32"
  }

  # Environment variables
  environment_variables = {
    MODEL_NAME = "my-model"
    VERSION    = "1.0"
  }

  tags = {
    Team        = "ML-Engineering"
    Environment = "staging"
    Project     = "ml-pipeline"
  }
}
```

### Advanced Example with Custom Launcher

```hcl
module "sagemaker_training_advanced" {
  source = "../../terraform/module/sagemaker-training-jobs"

  project_name    = "advanced-ml"
  environment     = "prod"
  
  # Training configuration
  training_image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/advanced-training:v2.0"
  instance_type       = "ml.p3.2xlarge"  # GPU instance
  instance_count      = 2               # Distributed training
  volume_size_gb      = 100
  max_runtime_seconds = 7200           # 2 hours

  # Data configuration with multiple channels
  input_data_config = [
    {
      ChannelName = "training"
      DataSource = {
        S3DataSource = {
          S3DataType             = "S3Prefix"
          S3Uri                  = "s3://advanced-ml-bucket/training/"
          S3DataDistributionType = "ShardedByS3Key"
        }
      }
      ContentType = "application/x-parquet"
      InputMode   = "File"
    },
    {
      ChannelName = "validation"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = "s3://advanced-ml-bucket/validation/"
        }
      }
      ContentType = "application/x-parquet"
      InputMode   = "File"
    }
  ]
  
  output_data_s3_path = "s3://advanced-ml-bucket/models/"
  s3_bucket_arn       = "arn:aws:s3:::advanced-ml-bucket"

  # Advanced scheduling with custom launcher
  enable_custom_launcher = true
  lambda_zip_path        = "./lambda/training_launcher.zip"
  lambda_handler         = "training_launcher.handler"
  lambda_runtime         = "python3.9"
  lambda_timeout         = 300

  # Custom Lambda environment variables
  lambda_environment_variables = {
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    MONITORING_ENABLED = "true"
  }

  # Cost optimization
  enable_spot_training = true
  checkpoint_config = {
    S3Uri     = "s3://advanced-ml-bucket/checkpoints/"
    LocalPath = "/opt/ml/checkpoints"
  }

  # Network configuration
  vpc_config = {
    SecurityGroupIds = ["sg-12345678"]
    Subnets          = ["subnet-12345678", "subnet-87654321"]
  }
  enable_network_isolation = true

  # Monitoring and debugging
  profiler_config = {
    S3OutputPath                    = "s3://advanced-ml-bucket/profiler/"
    ProfilingIntervalInMilliseconds = 500
    ProfilingParameters = {
      ProfilerConfig_DataloaderProfilingConfig_DisableFramework = "false"
    }
  }

  debugger_hook_config = {
    S3OutputPath = "s3://advanced-ml-bucket/debugger/"
    LocalPath    = "/opt/ml/output/tensors"
    HookParameters = {
      save_interval = "100"
    }
  }

  # MLflow integration
  mlflow_tracking_server_arn = module.mlflow.tracking_server_arn
  mlflow_tracking_uri        = module.mlflow.tracking_server_url
  enable_mlflow_integration  = true

  # Weekly schedule
  schedule_expression = "cron(0 6 ? * SUN *)"  # Every Sunday at 6 AM UTC
  schedule_enabled    = true

  tags = {
    Team               = "Data-Science"
    Environment        = "prod"
    Project            = "advanced-ml"
    CostCenter         = "ML-Research"
    DataClassification = "Internal"
  }
}
```

### Integration with Existing Infrastructure

```hcl
# Use outputs from existing SageMaker Studio and MLflow modules
module "sagemaker_training" {
  source = "../../terraform/module/sagemaker-training-jobs"

  project_name    = var.project_name
  environment     = var.environment
  
  training_image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-training:latest"
  instance_type       = "ml.m5.xlarge"
  output_data_s3_path = "s3://${module.sagemaker_studio.s3_bucket_name}/training-outputs/"
  s3_bucket_arn       = module.sagemaker_studio.s3_bucket_arn

  # Use the same execution role as SageMaker Studio
  additional_training_role_policies = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  ]

  # MLflow integration using existing tracking server
  mlflow_tracking_server_arn = module.mlflow.tracking_server_arn
  mlflow_tracking_uri        = module.mlflow.tracking_server_url
  enable_mlflow_integration  = true

  # Input data configuration
  input_data_config = [
    {
      ChannelName = "training"
      DataSource = {
        S3DataSource = {
          S3DataType = "S3Prefix"
          S3Uri      = "s3://${module.sagemaker_studio.s3_bucket_name}/datasets/training/"
        }
      }
    }
  ]

  tags = local.common_tags
}
```

## Input Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `project_name` | Name of the project | `string` |
| `training_image` | Docker image URI for training | `string` |
| `output_data_s3_path` | S3 path for training outputs | `string` |

### Training Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `environment` | Environment name | `string` | `"staging"` |
| `instance_type` | EC2 instance type | `string` | `"ml.m5.large"` |
| `instance_count` | Number of instances | `number` | `1` |
| `volume_size_gb` | EBS volume size in GB | `number` | `30` |
| `max_runtime_seconds` | Maximum runtime in seconds | `number` | `86400` |
| `training_input_mode` | Input mode for training | `string` | `"File"` |

### Scheduling Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_scheduling` | Enable EventBridge scheduling | `bool` | `true` |
| `schedule_expression` | EventBridge schedule expression | `string` | `"cron(0 2 * * ? *)"` |
| `schedule_enabled` | Whether schedule is enabled | `bool` | `true` |

### MLflow Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `mlflow_tracking_server_arn` | MLflow server ARN | `string` | `null` |
| `mlflow_tracking_uri` | MLflow tracking URI | `string` | `null` |
| `enable_mlflow_integration` | Enable MLflow integration | `bool` | `true` |

### Advanced Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_custom_launcher` | Use custom Lambda launcher | `bool` | `false` |
| `enable_spot_training` | Enable managed spot training | `bool` | `false` |
| `enable_network_isolation` | Enable network isolation | `bool` | `false` |
| `vpc_config` | VPC configuration | `object` | `null` |

## Outputs

### Primary Outputs

| Name | Description |
|------|-------------|
| `training_role_arn` | ARN of the training IAM role |
| `schedule_rule_arn` | ARN of the EventBridge rule |
| `lambda_function_arn` | ARN of Lambda function (if enabled) |

### Configuration Outputs

| Name | Description |
|------|-------------|
| `training_job_configuration` | Summary of training configuration |
| `mlflow_integration_enabled` | Whether MLflow integration is active |
| `schedule_expression` | Cron expression used for scheduling |

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform >= 1.5** installed
3. **SageMaker permissions** for training jobs
4. **ECR repository** with your training image
5. **S3 bucket** for data and artifacts
6. **MLflow tracking server** (optional, for experiment tracking)

## IAM Permissions

The module creates IAM roles with the following permissions:

### Training Role
- SageMaker training job operations
- S3 bucket access for data and artifacts
- ECR image pulling
- CloudWatch logging
- MLflow integration (if enabled)

### Scheduler Role
- EventBridge rule management
- SageMaker training job creation
- IAM role passing

### Lambda Role (if custom launcher enabled)
- Basic Lambda execution
- SageMaker training job operations
- IAM role passing

## Cost Optimization

### Managed Spot Training
```hcl
enable_spot_training = true
checkpoint_config = {
  S3Uri     = "s3://my-bucket/checkpoints/"
  LocalPath = "/opt/ml/checkpoints"
}
```

### Instance Selection
- Use smaller instances for development: `ml.m5.large`
- Use GPU instances for deep learning: `ml.p3.2xlarge`
- Use distributed training for large datasets: `instance_count > 1`

## Monitoring and Debugging

### Profiler Configuration
```hcl
profiler_config = {
  S3OutputPath                    = "s3://my-bucket/profiler/"
  ProfilingIntervalInMilliseconds = 500
}
```

### Debugger Configuration
```hcl
debugger_hook_config = {
  S3OutputPath = "s3://my-bucket/debugger/"
  LocalPath    = "/opt/ml/output/tensors"
}
```

## Security Best Practices

1. **Use VPC endpoints** for S3 and SageMaker access
2. **Enable network isolation** for sensitive workloads
3. **Use least privilege IAM policies**
4. **Encrypt S3 buckets** with KMS
5. **Use private subnets** for training jobs

## Troubleshooting

### Common Issues

1. **Training job fails to start:**
   - Check IAM role permissions
   - Verify ECR image exists and is accessible
   - Ensure S3 paths are correct

2. **MLflow integration not working:**
   - Verify MLflow tracking server ARN and URI
   - Check training role has MLflow permissions
   - Ensure environment variables are set correctly

3. **Scheduling issues:**
   - Verify EventBridge rule is enabled
   - Check scheduler role permissions
   - Validate cron expression syntax

4. **Spot training interruptions:**
   - Enable checkpointing
   - Use appropriate instance types
   - Monitor spot instance availability

### Monitoring

- **CloudWatch Logs**: Training job logs under `/aws/sagemaker/TrainingJobs`
- **CloudWatch Metrics**: Training job metrics and system metrics
- **MLflow UI**: Experiment tracking and model performance
- **EventBridge**: Scheduling and execution history

## Examples

See the `examples/` directory for:
- Basic training job setup
- Integration with existing infrastructure
- Custom Lambda launcher examples
- Advanced monitoring configuration

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review AWS SageMaker documentation
3. Check MLflow integration guides
4. Contact the ML platform team
