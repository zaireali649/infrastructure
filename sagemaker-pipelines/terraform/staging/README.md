# SageMaker Pipelines - Staging Environment

This Terraform configuration deploys a complete MLOps pipeline for Iris classification with weekly training and daily inference using SageMaker managed MLflow.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Training      │    │   SageMaker      │    │   Inference     │
│   Pipeline      │    │   Managed        │    │   Pipeline      │
│   (Weekly)      │────│   MLflow         │────│   (Daily)       │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
    ┌────▼────┐             ┌────▼────┐             ┌────▼────┐
    │ ECR     │             │ Model   │             │ S3      │
    │ Training│             │ Registry│             │ Results │
    │ Image   │             │         │             │ Storage │
    └─────────┘             └─────────┘             └─────────┘
```

## Components

### 1. Training Pipeline
- **Schedule**: Weekly (Sundays at 2 AM UTC)
- **Function**: Trains RandomForest model on Iris dataset
- **Output**: Registers model in SageMaker managed MLflow
- **Instance**: ml.m5.large
- **Runtime**: 30 minutes max

### 2. Inference Pipeline
- **Schedule**: Daily (6 AM UTC)
- **Function**: Generates predictions on random Iris-like data
- **Input**: Model from MLflow registry
- **Output**: Prediction results to S3
- **Instance**: ml.m5.large
- **Runtime**: 20 minutes max

### 3. MLflow Integration
- Uses SageMaker managed MLflow server: `mlflow-staging-mlflow`
- Tracking URI: Automatically constructed as `https://mlflow-staging-mlflow.{region}.amazonaws.com`
- Model name: `iris-model`
- Automatic model promotion to Production stage

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform >= 1.5** installed
3. **S3 bucket** for ML data storage
4. **ECR repositories** with training and inference images
5. **SageMaker managed MLflow** instance deployed

## GitHub Repository Secrets

For CI/CD deployment, configure these repository secrets:

| Secret | Description | Required |
|--------|-------------|----------|
| `TF_BACKEND_BUCKET` | S3 bucket for Terraform state | Yes |
| `AWS_ACCESS_KEY_ID` | AWS access key for deployment | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for deployment | Yes |
| `BUCKET_NAME_SUFFIX` | Suffix for S3 bucket naming | Optional |

## Required AWS Permissions

The deploying user/role needs:
- `sagemaker:*` - For creating pipelines and jobs
- `iam:*` - For creating execution roles
- `events:*` - For scheduling pipelines
- `s3:*` - For accessing ML data bucket
- `ecr:*` - For accessing container images

## Quick Start

### 1. Configure Variables
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your actual values
nano terraform.tfvars
```

### 2. Backend Configuration
The backend is configured to use GitHub repository secrets via CI/CD:
- **TF_BACKEND_BUCKET**: S3 bucket for Terraform state
- **State Key**: Automatically set to `sagemaker-pipelines/staging/terraform.tfstate`
- **Region**: `us-east-1`

For local development, you can override with:
```bash
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=sagemaker-pipelines/staging/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

### 3. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 4. Verify Deployment
```bash
# Check pipeline status
aws sagemaker list-pipelines --region us-east-1

# Check scheduled rules
aws events list-rules --region us-east-1
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `s3_bucket_name` | S3 bucket for ML data | `my-ml-bucket-staging` |
| `training_image_uri` | ECR URI for training | `123456789012.dkr.ecr.us-east-1.amazonaws.com/iris-training:latest` |
| `inference_image_uri` | ECR URI for inference | `123456789012.dkr.ecr.us-east-1.amazonaws.com/iris-inference:latest` |
| ~~`mlflow_tracking_uri`~~ | ~~SageMaker managed MLflow server URL~~ | ~~Hardcoded to `mlflow-staging-mlflow`~~ |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `iris-ml` | Project identifier |
| `environment` | `staging` | Environment name |
| `aws_region` | `us-east-1` | AWS region |
| `training_instance_type` | `ml.m5.large` | Training instance type |
| `inference_instance_type` | `ml.m5.large` | Inference instance type |
| `enable_training_schedule` | `true` | Enable weekly training |
| `enable_inference_schedule` | `true` | Enable daily inference |

## Scheduling

### Training Schedule
- **Frequency**: Weekly
- **Time**: Sundays at 2:00 AM UTC
- **Cron**: `cron(0 2 ? * SUN *)`

### Inference Schedule
- **Frequency**: Daily
- **Time**: 6:00 AM UTC
- **Cron**: `cron(0 6 * * ? *)`

## Manual Execution

### Trigger Training Manually
```bash
aws sagemaker start-pipeline-execution \
  --pipeline-name iris-ml-staging-training \
  --region us-east-1
```

### Trigger Inference Manually
```bash
aws sagemaker start-pipeline-execution \
  --pipeline-name iris-ml-staging-processing \
  --region us-east-1
```

## Monitoring

### CloudWatch Logs
- Training logs: `/aws/sagemaker/TrainingJobs`
- Inference logs: `/aws/sagemaker/ProcessingJobs`

### Pipeline Monitoring
```bash
# List recent executions
aws sagemaker list-pipeline-executions \
  --pipeline-name iris-ml-staging-training \
  --region us-east-1

# Get execution details
aws sagemaker describe-pipeline-execution \
  --pipeline-execution-arn <execution-arn> \
  --region us-east-1
```

## Data Flow

### S3 Structure
```
s3://mlflow-staging-mlflow-artifacts-zali-staging/  # Shared with MLflow
├── iris/                    # SageMaker pipeline data
│   ├── models/             # Model artifacts from SageMaker
│   ├── inference-input/    # Inference input data (generated)
│   └── inference-output/   # Daily prediction results
└── mlflow-artifacts/       # MLflow experiment artifacts (managed by MLflow)
    ├── experiments/
    ├── models/
    └── runs/

Note: No iris/input/ directory needed - training uses built-in Iris dataset
```

### Model Flow
1. **Training**: Saves model to MLflow as `iris-model`
2. **Registration**: Auto-registers in model registry
3. **Promotion**: Promotes to Production stage
4. **Inference**: Loads Production model for predictions

## Troubleshooting

### Common Issues

1. **Pipeline Fails to Start**
   - Check IAM permissions
   - Verify ECR image URIs
   - Ensure S3 bucket exists

2. **Training Job Fails**
   - Check MLflow tracking URI
   - Verify container can access MLflow
   - Check CloudWatch logs

3. **Inference Job Fails**
   - Ensure model exists in MLflow
   - Check model loading permissions
   - Verify S3 write permissions

### Debug Commands
```bash
# Check pipeline status
aws sagemaker describe-pipeline --pipeline-name iris-ml-staging-training

# View recent executions
aws sagemaker list-pipeline-executions --pipeline-name iris-ml-staging-training

# Check execution logs
aws logs describe-log-groups --log-group-name-prefix "/aws/sagemaker"
```

## Cost Optimization

- Uses `ml.m5.large` instances (cost-effective for small workloads)
- Training limited to 30 minutes
- Inference limited to 20 minutes
- No persistent endpoints (batch processing only)

## Security

- IAM roles follow principle of least privilege
- S3 access limited to specific bucket
- Container images from private ECR
- CloudWatch logs for audit trail

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Note**: This will delete all pipelines and schedules. Model artifacts in MLflow and S3 will remain.

## Next Steps

1. **Production Deployment**: Replicate in production environment
2. **Model Monitoring**: Add data drift detection
3. **A/B Testing**: Implement model comparison pipelines
4. **Advanced Scheduling**: Add conditional triggers based on data availability
