# GitHub Actions Workflows for ML Platform

This directory contains the GitHub Actions workflows for deploying and managing the ML Platform infrastructure, including SageMaker Studio and MLflow.

## Workflow Structure

### 📁 Workflow Files (3 Total)

| Workflow | Purpose | Type |
|----------|---------|------|
| **on-pull-request.yml** | Main workflow with matrix strategy | Main |
| **terraform-plan.yml** | Terraform planning | Reusable |
| **terraform-deploy.yml** | Terraform deployment | Reusable |

## Services Supported

- **SageMaker Studio**: Managed Jupyter notebooks and ML development environment
- **MLflow**: Managed experiment tracking and model registry

## How It Works

### Matrix Strategy

The main workflow uses a matrix to deploy multiple services:

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - project: ml
        terraform-environment: staging
        project-folder: sagemaker-studio
      - project: ml
        terraform-environment: staging
        project-folder: mlflow
```

### Workflow Flow

1. **Pull Request** triggers `on-pull-request.yml`
2. **Matrix creates jobs** for each service (SageMaker Studio, MLflow)
3. **Plan phase** runs `terraform-plan.yml` for each service
4. **Deploy phase** runs `terraform-deploy.yml` for each service
5. **Artifacts shared** between plan and deploy phases

## Directory Structure

```
sagemaker-studio/terraform/staging/  # SageMaker Studio Terraform files
mlflow/terraform/staging/             # MLflow Terraform files
```

## Required Secrets

Configure these secrets in your GitHub repository:

| Secret | Description | Required |
|--------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | ✅ Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | ✅ Yes |
| `TF_BACKEND_BUCKET` | S3 bucket for Terraform state | 🔶 Recommended |
| `BUCKET_NAME_SUFFIX` | Unique suffix for resource naming | 🔶 Recommended |
| `SUBNET_IDS` | Comma-separated subnet IDs | ⚪ Optional |

## Usage

### Automatic (Pull Requests)

When you create a pull request, the workflow automatically:

1. Plans both SageMaker Studio and MLflow deployments
2. Deploys both services to staging for testing
3. Provides Terraform outputs as artifacts

### Parameters

Each reusable workflow accepts these parameters:

- `environment`: GitHub environment protection name (e.g., "sagemaker-studio-staging")
- `terraform-environment`: Terraform environment (staging, prod)
- `terraform-working-directory`: Path to Terraform files
- `aws-environment`: AWS environment
- `project`: Project name (ml)
- `aws-role-name`: IAM role for OIDC (mlops-github)

## Adding New Services

To add a new service to the matrix:

1. **Create Terraform files** in `new-service/terraform/staging/`
2. **Add to matrix** in `on-pull-request.yml`:

```yaml
- project: ml
  terraform-environment: staging
  project-folder: new-service
```

## Environment Variables

The workflows use these environment variables:

```yaml
env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.6.0
  TF_VAR_aws_region: us-east-1
```

## Troubleshooting

### Common Issues

1. **Plan failed**
   - Check AWS credentials and permissions
   - Verify Terraform configuration syntax
   - Review variable values and defaults

2. **Deploy failed**
   - Check AWS resource limits and quotas
   - Verify network configuration (VPC, subnets)
   - Review Terraform outputs in artifacts

3. **Workflow not triggered**
   - Ensure pull request has changes
   - Check workflow file syntax
   - Verify repository permissions

### Debug Steps

1. Check workflow logs in GitHub Actions
2. Download and review Terraform plan artifacts
3. Verify AWS permissions using AWS CLI
4. Test Terraform locally with same configuration

## Best Practices

### Workflow Management

1. Test in pull requests before merging
2. Monitor workflow runs for failures
3. Keep secrets up to date and rotate regularly

### Terraform Best Practices

1. Use remote state with S3 backend
2. Plan before apply in all environments
3. Use consistent naming across resources

## Support

For issues with workflows:

1. Check workflow run logs for specific errors
2. Test Terraform locally to isolate issues
3. File an issue in the infrastructure repository