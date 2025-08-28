# SageMaker Pipelines Terraform Module

This module creates SageMaker ML pipelines with EventBridge scheduling, using existing infrastructure for networking and ECR repositories. Both training and processing pipelines are optional.

## Features

- **Optional SageMaker Training Pipeline**: Configurable training jobs with MLflow integration
- **Optional SageMaker Processing Pipeline**: Inference/scoring jobs (Kafka output handled in Python)
- **EventBridge Scheduling**: Automated pipeline execution (weekly training, daily scoring)
- **IAM Roles**: Least-privilege permissions for all components
- **Existing Infrastructure Integration**: Uses existing VPC and ECR resources
- **Flexible Configuration**: Enable only the pipelines you need

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Existing Infrastructure                      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Existing VPC  │    │    Existing     │    │ Existing    │ │
│  │   & Subnets     │    │   S3 Bucket     │    │ ECR Repos   │ │
│  │   & Security    │    │                 │    │             │ │
│  │   Groups        │    │                 │    │             │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                            ▲
                            │ (references)
┌─────────────────────────────────────────────────────────────────┐
│                      This Module Creates                       │
│  ┌─────────────────┐                   ┌─────────────────┐     │
│  │   SageMaker     │                   │   EventBridge   │     │
│  │   Training      │◄─────────────────►│   Schedules     │     │
│  │   Pipeline      │                   │                 │     │
│  │   (Optional)    │                   │ • Weekly Train  │     │
│  └─────────────────┘                   │ • Daily Score   │     │
│  ┌─────────────────┐                   │                 │     │
│  │   SageMaker     │                   │                 │     │
│  │   Processing    │                   │                 │     │
│  │   Pipeline      │                   │                 │     │
│  │   (Optional)    │                   │                 │     │
│  └─────────────────┘                   └─────────────────┘     │
│  ┌─────────────────┐                                           │
│  │   IAM Roles     │   Note: Kafka output is handled          │
│  │   & Policies    │   in Python code, not infrastructure     │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Both Training and Processing Pipelines

```hcl
module "sagemaker_pipelines" {
  source = "../../module/sagemaker-pipelines"

  # Core configuration
  project_name = "ml-platform"
  environment  = "staging"

  # Enable both pipelines
  enable_training_pipeline   = true
  enable_processing_pipeline = true

  # Existing infrastructure
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-12345678"]

  # S3 configuration (existing bucket)
  s3_bucket_arn           = "arn:aws:s3:::my-ml-bucket"
  input_data_s3_path      = "s3://my-ml-bucket/datasets/training/"
  model_output_s3_path    = "s3://my-ml-bucket/models/"
  inference_input_s3_path = "s3://my-ml-bucket/inference/input/"
  inference_output_s3_path = "s3://my-ml-bucket/inference/output/"

  # Container images (existing ECR repositories)
  training_image_uri  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ml-training:latest"
  inference_image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ml-inference:latest"

  # Environment variables
  training_environment_variables = {
    MLFLOW_TRACKING_URI = "https://mlflow.example.com"
    ENVIRONMENT         = "staging"
  }

  processing_environment_variables = {
    MLFLOW_TRACKING_URI = "https://mlflow.example.com"
    MLFLOW_MODEL_URI   = "models:/poem-model/Production"
    KAFKA_TOPIC        = "predictions"  # Used in Python code
  }

  tags = {
    Project     = "ml-platform"
    Environment = "staging"
    Team        = "ml-engineering"
  }
}
```

### Training Pipeline Only

```hcl
module "sagemaker_pipelines" {
  source = "../../module/sagemaker-pipelines"

  # Core configuration
  project_name = "ml-platform"
  environment  = "dev"

  # Enable only training pipeline
  enable_training_pipeline   = true
  enable_processing_pipeline = false

  # Existing infrastructure
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678"]
  security_group_ids = ["sg-12345678"]

  # S3 configuration (only training paths needed)
  s3_bucket_arn        = "arn:aws:s3:::dev-ml-bucket"
  input_data_s3_path   = "s3://dev-ml-bucket/datasets/training/"
  model_output_s3_path = "s3://dev-ml-bucket/models/"

  # Container images (only training image needed)
  training_image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ml-training:dev"

  # Disable scheduling for development
  enable_training_schedule = false

  tags = {
    Project     = "ml-platform"
    Environment = "dev"
    Team        = "ml-engineering"
  }
}
```

### Processing Pipeline Only

```hcl
module "sagemaker_pipelines" {
  source = "../../module/sagemaker-pipelines"

  # Core configuration
  project_name = "ml-platform"
  environment  = "prod"

  # Enable only processing pipeline
  enable_training_pipeline   = false
  enable_processing_pipeline = true

  # Existing infrastructure
  vpc_id             = data.aws_vpc.existing.id
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [data.aws_security_group.sagemaker.id]

  # S3 configuration (only inference paths needed)
  s3_bucket_arn           = data.aws_s3_bucket.ml_bucket.arn
  inference_input_s3_path = "s3://ml-bucket/inference/input/"
  inference_output_s3_path = "s3://ml-bucket/inference/output/"

  # Container images (only inference image needed)
  inference_image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/ml-inference:latest"

  # Processing configuration
  processing_environment_variables = {
    MLFLOW_TRACKING_URI = data.aws_sagemaker_mlflow_tracking_server.existing.tracking_server_url
    MLFLOW_MODEL_URI   = "models:/poem-model/Production"
    KAFKA_TOPIC        = "production-predictions"
  }

  # Enable scheduling for production
  enable_processing_schedule = true
  processing_schedule_enabled = true

  tags = {
    Project      = "ml-platform"
    Environment  = "prod"
    Team         = "ml-engineering"
    CostCenter   = "engineering"
  }
}
```

### No VPC Integration (Public Subnets)

```hcl
module "sagemaker_pipelines" {
  source = "../../module/sagemaker-pipelines"

  # Core configuration
  project_name = "ml-platform"
  environment  = "sandbox"

  # Enable both pipelines
  enable_training_pipeline   = true
  enable_processing_pipeline = true

  # No VPC integration (runs in public subnets)
  vpc_id             = ""
  subnet_ids         = []
  security_group_ids = []

  # S3 configuration
  s3_bucket_arn           = "arn:aws:s3:::sandbox-ml-bucket"
  input_data_s3_path      = "s3://sandbox-ml-bucket/datasets/training/"
  model_output_s3_path    = "s3://sandbox-ml-bucket/models/"
  inference_input_s3_path = "s3://sandbox-ml-bucket/inference/input/"
  inference_output_s3_path = "s3://sandbox-ml-bucket/inference/output/"

  # Container images
  training_image_uri  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ml-training:sandbox"
  inference_image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ml-inference:sandbox"

  tags = {
    Project     = "ml-platform"
    Environment = "sandbox"
    Team        = "ml-engineering"
  }
}
```

## Prerequisites

This module requires the following existing infrastructure:

### Required
- **S3 Bucket**: Existing S3 bucket for data and model storage
- **ECR Repositories**: Existing ECR repositories with training and/or inference images (must be created before using this module)

### Optional
- **VPC**: Existing VPC with appropriate networking setup (leave empty for public subnets)
- **Subnets**: Private subnets for SageMaker jobs (if VPC integration needed)
- **Security Groups**: Security groups with appropriate rules for SageMaker
- **MLflow Tracking Server**: For experiment tracking (referenced in environment variables)

## Important Notes

### Kafka Integration
- **Kafka output is handled in Python code**, not in this module
- The module does **not** create or manage Kafka infrastructure
- Pass Kafka configuration (topics, bootstrap servers, etc.) via environment variables
- Your Python code should handle Kafka connectivity and authentication

### Pipeline Flexibility
- **Both pipelines are optional** - you can enable training only, processing only, or both
- **Scheduling is optional** - can be disabled for manual execution
- **VPC integration is optional** - can run in public subnets if no VPC specified

### ECR Repository Management
- **This module does NOT create ECR repositories** - they must exist before use
- ECR repositories should be created via separate infrastructure or manually
- Repository naming convention: typically `{project_name}-{environment}-{service}` (e.g., `ml-platform-staging-training`)
- Build scripts will verify repository existence and fail if repositories don't exist

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project/application | `string` | n/a | yes |
| environment | Environment name (staging, prod, dev) | `string` | n/a | yes |
| s3_bucket_arn | ARN of existing S3 bucket | `string` | n/a | yes |
| enable_training_pipeline | Enable training pipeline | `bool` | `true` | no |
| enable_processing_pipeline | Enable processing pipeline | `bool` | `false` | no |
| vpc_id | ID of existing VPC (empty for no VPC) | `string` | `""` | no |
| subnet_ids | List of subnet IDs for SageMaker jobs | `list(string)` | `[]` | no |
| security_group_ids | List of security group IDs | `list(string)` | `[]` | no |
| training_image_uri | Training container image URI | `string` | `""` | no* |
| inference_image_uri | Inference container image URI | `string` | `""` | no* |
| enable_training_schedule | Enable training schedule | `bool` | `false` | no |
| enable_processing_schedule | Enable processing schedule | `bool` | `false` | no |

*Required if respective pipeline is enabled

See [variables.tf](./variables.tf) for the complete list of configurable options.

## Outputs

| Name | Description |
|------|-------------|
| training_pipeline_arn | Training pipeline ARN |
| processing_pipeline_arn | Processing pipeline ARN |
| training_role_arn | Training IAM role ARN |
| processing_role_arn | Processing IAM role ARN |
| training_schedule_rule_arn | Training schedule rule ARN |
| processing_schedule_rule_arn | Processing schedule rule ARN |
| module_configuration | Summary of module configuration |

See [outputs.tf](./outputs.tf) for the complete list of outputs.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | ~> 5.73.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.73.0 |

## Resources Created

### SageMaker (Conditional)
- Training pipeline with configurable hyperparameters (if `enable_training_pipeline = true`)
- Processing pipeline for batch inference (if `enable_processing_pipeline = true`)
- IAM roles with least-privilege permissions for enabled pipelines

### Scheduling (Optional)
- EventBridge rules for automated execution (if scheduling enabled)
- EventBridge targets for pipeline triggering
- IAM roles for scheduler permissions

## Data Sources Used

The module references existing infrastructure through data sources:

- `aws_vpc` - Existing VPC lookup (if VPC ID provided)
- `aws_subnets` - Existing subnet lookup (if VPC ID provided)
- `aws_security_group` - Existing security group lookup (if security group ID provided)

## Common Use Cases

1. **Training Only**: Development environments, model experimentation
2. **Processing Only**: Inference-only deployments, serving existing models
3. **Full Pipeline**: Complete ML workflows with training and inference
4. **No Scheduling**: Manual execution for testing and development
5. **Public Deployment**: Simple setups without VPC integration

## Migration from Infrastructure-Heavy Module

If migrating from a module that created VPC/Kafka/ECR:

1. Ensure existing infrastructure exists and is properly configured
2. Remove infrastructure creation variables from module calls
3. Add data sources to reference existing resources
4. Handle Kafka integration in your Python application code
5. Update module calls with existing infrastructure IDs

## License

This module is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.