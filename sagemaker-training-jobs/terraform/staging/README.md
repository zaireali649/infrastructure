# SageMaker Training Jobs - Staging Environment

This directory contains the Terraform configuration for deploying scheduled SageMaker training jobs in the staging environment with MLflow integration for experiment tracking and automated model registration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   EventBridge Scheduler                     │
│               (Cron: Daily at 3 AM UTC)                    │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              SageMaker Training Job                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  • sklearn-learn container                         │   │
│  │  • ml.m5.large instance                           │   │
│  │  • Input: S3 training data                        │   │
│  │  │  Output: S3 model artifacts                    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                MLflow Integration                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  • Experiment tracking                             │   │
│  │  │  Model registration                             │   │
│  │  │  Artifact storage in S3                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

1. **AWS CLI configured** with staging account credentials
2. **Terraform >= 1.5** installed
3. **Existing infrastructure** from SageMaker Studio and MLflow modules deployed
4. **S3 bucket** with training data and proper permissions

### Deploy Training Jobs

1. **Navigate to staging directory:**
   ```bash
   cd sagemaker-training-jobs/terraform/staging
   ```

2. **Review and customize configuration:**
   ```bash
   cat terraform.tfvars
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan deployment:**
   ```bash
   terraform plan
   ```

5. **Deploy:**
   ```bash
   terraform apply
   ```

## Configuration

### Current Setup

- **Training Image**: Built-in SageMaker sklearn-learn container
- **Instance Type**: ml.m5.large (cost-effective for staging)
- **Schedule**: Daily at 3 AM UTC (disabled initially)
- **Runtime**: 1 hour maximum
- **Storage**: 30 GB EBS volume

### Data Configuration

The training job expects:
- **Input Data**: CSV files in `s3://ml-platform-staging-ml-bucket/datasets/training/`
- **Output**: Model artifacts saved to `s3://ml-platform-staging-ml-bucket/training-outputs/`

### Hyperparameters

Default sklearn RandomForest configuration:
```hcl
hyperparameters = {
  max_depth     = "5"
  n_estimators  = "100"
  random_state  = "42"
  criterion     = "gini"
  max_features  = "auto"
}
```

## Integration with Existing Infrastructure

### SageMaker Studio Integration

The training jobs integrate with your existing SageMaker Studio setup:
- Uses the same S3 bucket for data and artifacts
- Compatible with Studio notebooks for data preparation
- Shares IAM permissions with Studio execution role

### MLflow Integration

Automatic experiment tracking and model registration:
- All training runs logged to MLflow tracking server
- Models automatically registered upon successful completion
- Artifacts stored in S3 with MLflow metadata

## Customization

### Changing the Training Image

To use a custom training image:

1. **Update terraform.tfvars:**
   ```hcl
   training_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-custom-image:latest"
   ```

2. **Ensure your ECR image includes:**
   - Training script in `/opt/ml/code/`
   - MLflow client libraries for logging
   - Proper S3 permissions

### Modifying the Schedule

To change the training schedule:

1. **Update terraform.tfvars:**
   ```hcl
   schedule_expression = "cron(0 6 * * ? *)"  # 6 AM daily
   # or
   schedule_expression = "rate(12 hours)"     # Every 12 hours
   ```

2. **Enable the schedule:**
   ```hcl
   schedule_enabled = true
   ```

### Adding More Instance Power

For larger datasets or more complex models:

1. **Update terraform.tfvars:**
   ```hcl
   instance_type    = "ml.m5.xlarge"  # More CPU/memory
   # or
   instance_type    = "ml.p3.2xlarge" # GPU for deep learning
   instance_count   = 2               # Distributed training
   volume_size_gb   = 100             # More storage
   ```

### Custom Data Channels

For multiple data sources:

```hcl
input_data_config = [
  {
    ChannelName = "training"
    DataSource = {
      S3DataSource = {
        S3DataType = "S3Prefix"
        S3Uri      = "s3://your-bucket/training/"
      }
    }
    ContentType = "text/csv"
  },
  {
    ChannelName = "validation"
    DataSource = {
      S3DataSource = {
        S3DataType = "S3Prefix"
        S3Uri      = "s3://your-bucket/validation/"
      }
    }
    ContentType = "text/csv"
  }
]
```

## Monitoring and Troubleshooting

### Check Training Job Status

```bash
# List recent training jobs
aws sagemaker list-training-jobs --max-results 10 --sort-by CreationTime --sort-order Descending

# Describe specific training job
aws sagemaker describe-training-job --training-job-name <job-name>
```

### View Logs

```bash
# CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/sagemaker/TrainingJobs

# Specific training job logs
aws logs get-log-events --log-group-name /aws/sagemaker/TrainingJobs --log-stream-name <job-name>/algo-1-<timestamp>
```

### Check EventBridge Schedule

```bash
# List EventBridge rules
aws events list-rules --name-prefix ml-platform-staging

# Check rule targets
aws events list-targets-by-rule --rule <rule-name>
```

### MLflow Integration

- **MLflow UI**: Access through your MLflow tracking server URL
- **Experiments**: Look for experiments named after your training jobs
- **Models**: Check the model registry for automatically registered models

## Cost Optimization

### Enable Spot Training

For cost savings (reduces costs by up to 90%):

```hcl
enable_spot_training = true
checkpoint_config = {
  S3Uri = "s3://ml-platform-staging-ml-bucket/checkpoints/"
}
```

### Right-size Instances

- **Development/Testing**: ml.m5.large
- **Production Training**: ml.m5.xlarge or larger
- **Deep Learning**: ml.p3.x instances
- **Large Datasets**: ml.c5.x instances with more storage

## Security Considerations

### Data Access

- Training jobs can only access the configured S3 bucket
- IAM roles follow least privilege principle
- Network isolation available for sensitive workloads

### Secrets Management

For API keys or credentials:

```hcl
environment_variables = {
  SECRET_ARN = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret"
}
```

Then retrieve in your training code using AWS SDK.

## Common Issues

### Training Job Fails to Start

1. **Check IAM permissions**: Ensure training role can access S3 and ECR
2. **Verify image URI**: Confirm ECR image exists and is accessible
3. **Check S3 paths**: Ensure input data exists at specified location

### MLflow Integration Issues

1. **Verify tracking server**: Ensure MLflow server is running and accessible
2. **Check environment variables**: Confirm MLFLOW_TRACKING_URI is set
3. **Review IAM permissions**: Training role needs MLflow API access

### Scheduling Problems

1. **Verify EventBridge rule**: Check rule is enabled and has proper targets
2. **Check scheduler role**: Ensure role can create training jobs
3. **Validate cron expression**: Use AWS cron expression syntax

## Next Steps

1. **Test the deployment** with sample data
2. **Enable scheduling** once testing is complete
3. **Monitor costs** and adjust instance types as needed
4. **Scale to production** using the production environment configuration
5. **Add custom training images** for your specific use cases

## Support

For issues and questions:
- Check AWS SageMaker documentation
- Review CloudWatch logs
- Contact the ML platform team
