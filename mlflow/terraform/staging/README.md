# SageMaker Managed MLflow Staging Environment

This directory contains the Terraform configuration for deploying Amazon SageMaker's fully managed MLflow tracking server in the staging environment. This is a serverless, fully managed service that handles all infrastructure, scaling, and maintenance automatically.

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│           Amazon SageMaker Service          │
│                                             │
│   ┌─────────────────────────────────────┐   │
│   │     MLflow Tracking Server          │   │
│   │        (Fully Managed)              │   │
│   │                                     │   │
│   │  • Auto-scaling                     │   │
│   │  • Maintenance handled by AWS       │   │
│   │  • Built-in security & monitoring   │   │
│   │  • Native SageMaker integration     │   │
│   └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                        │
              ┌─────────────────┐
              │   S3 Bucket     │
              │   Artifacts     │
              └─────────────────┘
```

## Quick Start

### Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform >= 1.5** installed
3. **SageMaker permissions** for MLflow tracking server

### Deploy Managed MLflow

1. **Navigate to staging directory:**
   ```bash
   cd mlflow/terraform/staging
   ```

2. **Review configuration:**
   ```bash
   cat terraform.tfvars
   ```

3. **Initialize and deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Get MLflow URL:**
   ```bash
   terraform output mlflow_tracking_uri
   ```

## Configuration Options

### Key Variables

| Variable | Description | Default | Staging Value |
|----------|-------------|---------|---------------|
| `bucket_name_suffix` | Unique suffix for S3 bucket | - | `"zali-staging"` |
| `mlflow_version` | MLflow version | `"3.0"` | `"3.0"` |
| `automatic_model_registration` | Auto-register models | `true` | `true` |
| `create_s3_bucket` | Create new S3 bucket | `true` | `true` |

### S3 Configuration Options

#### Option 1: Create New S3 Bucket (Default)
```hcl
create_s3_bucket = true
# Bucket will be auto-named: mlflow-staging-mlflow-artifacts-zali-staging
```

#### Option 2: Use Existing S3 Bucket (e.g., from SageMaker Studio)
```hcl
create_s3_bucket = false
artifact_store_uri = "s3://sagemaker-studio-staging-ml-bucket-zali-staging"
```

## Usage

### Access MLflow UI

The managed MLflow service can be accessed in multiple ways:

#### Through SageMaker Studio (Recommended)
1. Open SageMaker Studio
2. Navigate to MLflow in the left sidebar
3. Access your tracking server directly

#### Direct URL Access
```bash
# Get the tracking server URL
MLFLOW_URL=$(terraform output -raw mlflow_tracking_uri)
echo "MLflow UI: $MLFLOW_URL"
open $MLFLOW_URL  # Open in browser
```

### Configure MLflow Client

#### Automatic Configuration (SageMaker Studio)
In SageMaker Studio, the MLflow tracking URI is often automatically configured:

```python
import mlflow

# Check if already configured
print(f"Current tracking URI: {mlflow.get_tracking_uri()}")

# Start logging experiments
with mlflow.start_run():
    mlflow.log_param("algorithm", "xgboost")
    mlflow.log_metric("accuracy", 0.95)
```

#### Manual Configuration
```python
import mlflow

# Set tracking URI manually
mlflow.set_tracking_uri("https://your-tracking-server-url")

# Verify connection
print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")

# Log experiments
with mlflow.start_run():
    mlflow.log_param("model_type", "random_forest")
    mlflow.log_metric("rmse", 0.123)
    
    # Models are automatically registered if enabled
    mlflow.sklearn.log_model(model, "model")
```

#### Environment Variable Configuration
```bash
export MLFLOW_TRACKING_URI="https://your-tracking-server-url"
```

## Integration with SageMaker Studio

The managed MLflow service provides seamless integration with SageMaker Studio:

### In SageMaker Studio Notebooks

```python
import mlflow
import sagemaker
from sagemaker.sklearn.estimator import SKLearn

# MLflow is often pre-configured in SageMaker Studio
print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")

# Example: Track a SageMaker training job
with mlflow.start_run():
    # Log hyperparameters
    mlflow.log_param("instance_type", "ml.m5.large")
    mlflow.log_param("estimator_type", "sklearn")
    
    # Create and train SageMaker estimator
    sklearn_estimator = SKLearn(
        entry_point='train.py',
        role=sagemaker.get_execution_role(),
        instance_type='ml.m5.large',
        framework_version='0.23-1'
    )
    
    # Train the model
    sklearn_estimator.fit(training_data)
    
    # Log the trained model
    mlflow.log_param("training_job_name", sklearn_estimator.latest_training_job.job_name)
    
    # Automatic model registration happens if enabled
```

### SageMaker Experiments Integration

```python
from sagemaker.experiments import experiment

# Create SageMaker experiment
my_experiment = experiment.Experiment.create(
    experiment_name="my-ml-experiment",
    description="Integrated MLflow and SageMaker experiment"
)

# MLflow automatically tracks SageMaker experiments
with mlflow.start_run():
    # Your training code here
    pass
```

## Monitoring and Management

### View Tracking Server Status

```bash
# Check tracking server details
aws sagemaker describe-mlflow-tracking-server \
  --tracking-server-name $(terraform output -raw tracking_server_name)
```

### Monitor Usage and Costs

- **CloudWatch Metrics**: Automatic metrics for API calls and usage
- **AWS Cost Explorer**: Track costs for the managed service
- **SageMaker Console**: View tracking server status and configuration

### Maintenance

The managed service handles all maintenance automatically:

- **Automatic Updates**: MLflow updates are managed by AWS
- **Scaling**: Automatic scaling based on usage
- **Backups**: Built-in backup and disaster recovery
- **Security Patches**: Automatic security updates

## Advantages over Self-Hosted

| Feature | Managed MLflow | Self-Hosted MLflow |
|---------|----------------|-------------------|
| **Infrastructure** | Zero management | Manage ECS, RDS, ALB |
| **Scaling** | Automatic | Manual configuration |
| **Maintenance** | AWS handles all updates | You handle updates |
| **Security** | Built-in best practices | Configure security |
| **Monitoring** | Built-in CloudWatch | Set up monitoring |
| **Costs (light usage)** | Pay-per-use ($5-20/month) | Fixed costs (~$50/month) |
| **SageMaker Integration** | Native, seamless | Manual setup required |
| **High Availability** | Built-in | Configure yourself |

## Cost Information

The managed MLflow service uses a pay-per-use pricing model:

### Typical Staging Costs
- **Light usage** (few experiments): $5-15/month
- **Medium usage** (regular experiments): $15-35/month  
- **Heavy usage** (continuous experimentation): $35-60/month

### Cost Factors
- **API calls** to tracking server
- **Data transfer** for artifacts
- **Storage** in S3 (separate charge)

### Cost Optimization Tips
1. **Use existing S3 bucket** to share storage costs
2. **Clean up old experiments** periodically
3. **Monitor usage** through AWS Cost Explorer
4. **Use lifecycle policies** on S3 artifacts

## Security Features

### Built-in Security
- **IAM Integration**: Native AWS IAM authentication
- **VPC Support**: Can be deployed within your VPC
- **Encryption**: At-rest and in-transit encryption
- **Audit Logging**: Integrated with AWS CloudTrail

### Security Best Practices
1. **Use IAM roles** instead of access keys
2. **Enable CloudTrail** for audit logging
3. **Use KMS encryption** for sensitive artifacts
4. **Apply least privilege** IAM policies

## Troubleshooting

### Common Issues

1. **Cannot access tracking server:**
   ```bash
   # Check IAM permissions
   aws sts get-caller-identity
   
   # Verify tracking server status
   aws sagemaker describe-mlflow-tracking-server \
     --tracking-server-name $(terraform output -raw tracking_server_name)
   ```

2. **S3 permissions errors:**
   ```bash
   # Check S3 bucket permissions
   aws s3 ls $(terraform output -raw artifact_store_uri)
   
   # Verify IAM role permissions
   aws iam get-role-policy \
     --role-name $(terraform output -raw mlflow_role_name) \
     --policy-name MLflowBasicAccess
   ```

3. **Model registration fails:**
   - Verify `automatic_model_registration = true` in configuration
   - Check IAM permissions for SageMaker model registry
   - Ensure proper MLflow client version compatibility

### Debug Steps

1. **Check CloudWatch logs** for the tracking server
2. **Verify IAM permissions** for your user/role
3. **Test S3 access** directly
4. **Check regional availability** for SageMaker MLflow

## Migration from Self-Hosted

If you have an existing self-hosted MLflow deployment:

1. **Export experiments** from existing MLflow:
   ```python
   import mlflow
   
   # Connect to old MLflow
   mlflow.set_tracking_uri("http://old-mlflow-server")
   
   # Export experiments (implement your export logic)
   experiments = mlflow.list_experiments()
   ```

2. **Deploy managed MLflow** using this module

3. **Import experiments** to managed service:
   ```python
   # Connect to new managed MLflow
   mlflow.set_tracking_uri("https://new-managed-mlflow-url")
   
   # Import experiments (implement your import logic)
   ```

4. **Update client configurations** across your team

5. **Migrate S3 artifacts** if using different bucket

## Examples

### Basic Usage
```hcl
module "mlflow" {
  source = "../../../terraform/module/mlflow"
  
  project_name       = "mlflow"
  environment        = "staging"
  bucket_name_suffix = "alice-staging"
}
```

### Use Existing S3 Bucket
```hcl
module "mlflow" {
  source = "../../../terraform/module/mlflow"
  
  project_name       = "mlflow"
  environment        = "staging" 
  bucket_name_suffix = "alice-staging"
  
  create_s3_bucket = false
  artifact_store_uri = "s3://existing-sagemaker-bucket"
}
```

### Enhanced Security
```hcl
module "mlflow" {
  source = "../../../terraform/module/mlflow"
  
  project_name       = "mlflow"
  environment        = "prod"
  bucket_name_suffix = "production"
  
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/..."
  
  additional_role_policies = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  ]
}
```

## Next Steps

After successful deployment:

1. **Access MLflow UI** through SageMaker Studio or direct URL
2. **Configure team workflows** to use the managed tracking server
3. **Set up model registry** workflows with automatic registration
4. **Integrate with CI/CD** pipelines for automated ML workflows
5. **Train team** on SageMaker + MLflow best practices

## Support

For issues or questions:

1. Check [AWS SageMaker MLflow documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/mlflow.html)
2. Review the [troubleshooting section](#troubleshooting)
3. Consult AWS Support for service-specific issues
4. File infrastructure issues in the repository
