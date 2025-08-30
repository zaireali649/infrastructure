# SageMaker Managed MLflow Terraform Module

This Terraform module deploys Amazon SageMaker's fully managed MLflow tracking server. This is a serverless, fully managed service that handles scaling, maintenance, and integration with other AWS services automatically.

## Architecture

```
┌─────────────────────────────────────┐
│     Amazon SageMaker Service       │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   MLflow Tracking Server    │   │
│  │   (Fully Managed)           │   │
│  │                             │   │
│  │   • Automatic Scaling       │   │
│  │   • Maintenance Handled     │   │
│  │   • Built-in Security       │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
                  │
        ┌─────────────────┐
        │   S3 Bucket     │
        │   Artifacts     │ 
        └─────────────────┘
```

## Features

- **Fully Managed**: AWS handles all infrastructure, scaling, and maintenance
- **Serverless**: No servers to manage or provision
- **Built-in Security**: Integrated with AWS IAM and VPC
- **Auto-scaling**: Automatically scales based on usage
- **Cost-effective**: Pay only for what you use
- **SageMaker Integration**: Native integration with SageMaker Studio and other AWS services

## Usage

### Basic Example

```hcl
module "mlflow" {
  source = "../../terraform/module/mlflow"

  project_name       = "my-ml-project"
  environment        = "staging"
  bucket_name_suffix = "alice"

  # MLflow configuration
  mlflow_version = "3.0"
  automatic_model_registration = true

  tags = {
    Owner = "data-team"
    Cost  = "ml-platform"
  }
}
```

### Production Example

```hcl
module "mlflow" {
  source = "../../terraform/module/mlflow"

  project_name       = "ml-platform"
  environment        = "prod"
  bucket_name_suffix = "production"

  # MLflow configuration
  mlflow_version = "3.0"
  automatic_model_registration = true
  weekly_maintenance_window_start = "SUN:03:00"

  # Use existing S3 bucket
  create_s3_bucket = false
  artifact_store_uri = "s3://existing-ml-artifacts-bucket"

  # Security
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  # Additional IAM permissions
  additional_role_policies = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  ]

  tags = {
    Environment = "production"
    Owner       = "data-team"
    Cost        = "ml-platform"
  }
}
```

### Using Existing S3 Bucket

```hcl
module "mlflow" {
  source = "../../terraform/module/mlflow"

  project_name       = "my-project"
  environment        = "staging"
  bucket_name_suffix = "staging"

  # Use existing bucket (e.g., from SageMaker Studio module)
  create_s3_bucket = false
  artifact_store_uri = "s3://sagemaker-studio-staging-ml-bucket-alice-staging"

  tags = {
    SharedWith = "sagemaker-studio"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | ~> 5.31.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.31.0 |

## Resources

### Core Resources
- `aws_sagemaker_mlflow_tracking_server` - SageMaker managed MLflow tracking server
- `aws_iam_role` - IAM role for MLflow service
- `aws_iam_role_policy` - IAM policies for S3 and service access

### Optional Resources
- `aws_s3_bucket` - S3 bucket for artifacts (if `create_s3_bucket = true`)
- `aws_s3_bucket_versioning` - S3 bucket versioning
- `aws_s3_bucket_server_side_encryption_configuration` - S3 encryption
- `aws_s3_bucket_public_access_block` - S3 public access blocking

## Inputs

### Core Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project (used for resource naming) | `string` | n/a | yes |
| environment | Environment name (e.g., staging, prod) | `string` | `"staging"` | no |
| bucket_name_suffix | Unique suffix for S3 bucket naming | `string` | n/a | yes |

### MLflow Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tracking_server_name | Name for the MLflow tracking server | `string` | `null` | no |
| mlflow_version | MLflow version for the tracking server | `string` | `"3.0"` | no |
| automatic_model_registration | Whether to enable automatic model registration | `bool` | `true` | no |
| weekly_maintenance_window_start | Weekly maintenance window start time | `string` | `"TUE:03:30"` | no |

### S3 Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_s3_bucket | Whether to create a new S3 bucket for MLflow artifacts | `bool` | `true` | no |
| artifact_store_uri | S3 URI for artifact storage (required if create_s3_bucket is false) | `string` | `null` | no |
| kms_key_id | KMS key ID for S3 bucket encryption | `string` | `null` | no |

### IAM Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| mlflow_role_name | Custom name for the MLflow IAM role | `string` | `null` | no |
| additional_role_policies | Additional IAM policy ARNs to attach to the MLflow role | `list(string)` | `[]` | no |

## Outputs

### Service Information

| Name | Description |
|------|-------------|
| tracking_server_url | URL of the MLflow tracking server |
| tracking_server_arn | ARN of the MLflow tracking server |
| tracking_server_name | Name of the MLflow tracking server |
| mlflow_version | MLflow version running on the tracking server |

### Storage Information

| Name | Description |
|------|-------------|
| artifacts_bucket_name | Name of the S3 bucket for MLflow artifacts |
| artifacts_bucket_arn | ARN of the S3 bucket for MLflow artifacts |
| artifact_store_uri | S3 URI for MLflow artifacts |

### Security Information

| Name | Description |
|------|-------------|
| mlflow_role_arn | ARN of the MLflow IAM role |
| mlflow_role_name | Name of the MLflow IAM role |

### Client Configuration

| Name | Description |
|------|-------------|
| mlflow_tracking_uri | MLflow tracking URI for client configuration |

## Post-Deployment Configuration

### 1. Access MLflow UI

After deployment, access the MLflow web interface through SageMaker Studio or directly via the URL:

```bash
# Get the tracking server URL
MLFLOW_URL=$(terraform output -raw tracking_server_url)
echo "MLflow UI: $MLFLOW_URL"
```

### 2. Configure MLflow Client

Set up your MLflow client to use the managed tracking server:

```python
import mlflow

# Set the tracking URI to your managed MLflow server
mlflow.set_tracking_uri("https://your-tracking-server-url")

# Test the connection
print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")

# Start logging experiments
with mlflow.start_run():
    mlflow.log_param("algorithm", "random_forest")
    mlflow.log_metric("accuracy", 0.95)
```

### 3. SageMaker Studio Integration

The managed MLflow service integrates seamlessly with SageMaker Studio:

```python
# In SageMaker Studio notebook
import mlflow
import sagemaker

# The tracking URI is automatically configured in SageMaker Studio
# when using the managed MLflow service
print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")

# Log experiments as usual
with mlflow.start_run():
    # Your ML code here
    mlflow.log_param("algorithm", "xgboost")
    mlflow.log_metric("rmse", 0.123)
    
    # Models are automatically registered if automatic_model_registration = true
    mlflow.xgboost.log_model(model, "model")
```

## Advantages of SageMaker Managed MLflow

### Compared to Self-Hosted MLflow

| Feature | SageMaker Managed | Self-Hosted |
|---------|-------------------|-------------|
| **Infrastructure Management** | Fully managed | You manage ECS, RDS, ALB |
| **Scaling** | Automatic | Manual configuration |
| **Maintenance** | AWS handles updates | You handle updates |
| **Security** | Built-in best practices | You configure security |
| **Cost (small scale)** | Pay per use | Fixed infrastructure costs |
| **SageMaker Integration** | Native integration | Manual configuration |
| **Customization** | Limited | Full control |

## Cost Optimization

The managed MLflow service follows a pay-per-use model:

- **No fixed infrastructure costs** - only pay for actual usage
- **Automatic scaling** - scales down to zero when not in use
- **No management overhead** - no ECS, RDS, or ALB charges
- **Shared infrastructure** - AWS manages efficiency at scale

Typical costs for staging environments:
- **Light usage**: $5-20/month
- **Medium usage**: $20-50/month
- **Heavy usage**: $50-100/month

## Security Considerations

### Built-in Security Features

1. **IAM Integration**: Uses AWS IAM for authentication and authorization
2. **VPC Support**: Can be deployed within your VPC
3. **Encryption**: Supports encryption at rest and in transit
4. **Audit Logging**: Integrated with AWS CloudTrail

### Best Practices

1. **Use KMS encryption** for sensitive artifacts:
   ```hcl
   kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/..."
   ```

2. **Apply least privilege** IAM policies
3. **Use separate tracking servers** for different environments
4. **Enable CloudTrail** for audit logging

## Integration Examples

### With SageMaker Studio

```hcl
# Use the same S3 bucket as SageMaker Studio
module "mlflow" {
  source = "../../terraform/module/mlflow"

  project_name       = "sagemaker-studio"
  environment        = "staging"
  bucket_name_suffix = "alice-staging"

  create_s3_bucket = false
  artifact_store_uri = "s3://sagemaker-studio-staging-ml-bucket-alice-staging"

  tags = {
    IntegratedWith = "sagemaker-studio"
  }
}
```

### With Multiple Environments

```hcl
# Staging
module "mlflow_staging" {
  source = "../../terraform/module/mlflow"
  
  project_name = "ml-platform"
  environment  = "staging"
  bucket_name_suffix = "staging"
  
  mlflow_version = "3.0"
}

# Production
module "mlflow_prod" {
  source = "../../terraform/module/mlflow"
  
  project_name = "ml-platform"
  environment  = "prod"
  bucket_name_suffix = "prod"
  
  mlflow_version = "3.0"
  weekly_maintenance_window_start = "SUN:03:00"
  
  # Enhanced security for production
  kms_key_id = aws_kms_key.ml_key.arn
}
```

## Troubleshooting

### Common Issues

1. **Cannot access tracking server:**
   - Verify IAM permissions for your user/role
   - Check if the tracking server is in the correct region
   - Ensure VPC configuration allows access

2. **S3 access denied:**
   - Verify the MLflow role has S3 permissions
   - Check bucket policies and IAM policies
   - Ensure KMS permissions if using encryption

3. **Model registration fails:**
   - Verify `automatic_model_registration = true`
   - Check IAM permissions for SageMaker model registry
   - Ensure proper MLflow client configuration

### Monitoring

- **CloudWatch Metrics**: Monitor usage and performance
- **CloudTrail Logs**: Track API calls and access
- **SageMaker Console**: View tracking server status and configuration

## Migration from Self-Hosted

If migrating from a self-hosted MLflow deployment:

1. **Export existing experiments** using MLflow APIs
2. **Deploy managed tracking server** with this module
3. **Import experiments** to the new tracking server
4. **Update client configurations** to use new tracking URI
5. **Migrate artifacts** to new S3 location if needed

## Examples

See the `examples/` directory for:
- Basic staging deployment
- Production deployment with enhanced security
- Integration with existing SageMaker Studio
- Multi-environment setup

## Contributing

When contributing to this module:

1. Test with multiple MLflow versions
2. Verify IAM permissions are minimal but sufficient
3. Test integration with SageMaker Studio
4. Update documentation for any new features
5. Ensure backwards compatibility

## Support

For issues or questions:

1. Check AWS SageMaker MLflow documentation
2. Review IAM permissions and resource configurations
3. Consult CloudWatch logs and CloudTrail
4. File an issue in the infrastructure repository
