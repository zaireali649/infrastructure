# GitHub Actions Workflows for ML Platform

This directory contains the GitHub Actions workflows for deploying and managing the ML Platform infrastructure, including SageMaker Studio and MLflow.

## Workflow Structure

### 🚀 Main Workflows

| Workflow | Purpose | Trigger | Description |
|----------|---------|---------|-------------|
| **ml-platform-deploy.yml** | Main deployment workflow | Push to main, Manual | Matrix-based deployment of all services |
| **on-pull-request.yml** | PR validation and staging | Pull requests | Plans and deploys to staging for testing |

### 🔧 Reusable Workflows

| Workflow | Purpose | Used By |
|----------|---------|---------|
| **terraform-plan.yml** | Terraform planning | All deployment workflows |
| **terraform-deploy.yml** | Terraform deployment | All deployment workflows |

### 🗃️ Legacy Workflows

| Workflow | Status | Replacement |
|----------|--------|-------------|
| **sagemaker-studio-deploy-legacy.yml** | ⚠️ Deprecated | ml-platform-deploy.yml |

## Services Supported

- **SageMaker Studio**: Managed Jupyter notebooks and ML development environment
- **MLflow**: Managed experiment tracking and model registry

## Quick Start

### For Pull Requests (Automatic)

When you create a pull request that modifies infrastructure code, the workflow will:

1. **Detect changes** in SageMaker Studio or MLflow modules
2. **Plan** the changes using Terraform
3. **Deploy to staging** for testing
4. **Comment on PR** with deployment results and links

### For Production Deployment (Manual)

1. **Navigate to Actions** in your GitHub repository
2. **Select "ML Platform Deploy (Matrix)"** workflow
3. **Click "Run workflow"** and configure:
   - **Services**: Choose specific services or "all"
   - **Action**: plan, apply, or destroy
   - **Environment**: staging or prod

### For Emergency or Legacy (Manual)

Use the legacy workflow if needed:
1. **Navigate to Actions** → "Deploy SageMaker Studio (Legacy)"
2. **Follow deprecation notice** to migrate to new workflows

## Workflow Features

### 🎯 Change Detection

The workflows automatically detect which services have changed:

```yaml
# Monitors these paths for changes:
- 'sagemaker-studio/terraform/staging/**'
- 'terraform/module/sagemaker-studio/**'
- 'mlflow/terraform/staging/**'
- 'terraform/module/mlflow/**'
- '.github/workflows/**'
```

### 📊 Matrix Strategy

Deploys multiple services in parallel or sequentially:

```yaml
strategy:
  matrix:
    service: 
      - name: sagemaker-studio
        directory: ./sagemaker-studio/terraform/staging
      - name: mlflow
        directory: ./mlflow/terraform/staging
  fail-fast: false
  max-parallel: 1  # Sequential for safety
```

### 🛡️ Environment Protection

- **Staging**: Automatic deployment for testing
- **Production**: Manual approval required (configured in GitHub)

### 📝 Rich Reporting

- **Plan summaries** in PR comments
- **Deployment status** in workflow summaries
- **Direct links** to deployed services
- **Error details** for troubleshooting

## Required Secrets

Configure these secrets in your GitHub repository:

| Secret | Description | Required |
|--------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | ✅ Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | ✅ Yes |
| `TF_BACKEND_BUCKET` | S3 bucket for Terraform state | 🔶 Recommended |
| `BUCKET_NAME_SUFFIX` | Unique suffix for resource naming | 🔶 Recommended |
| `SUBNET_IDS` | Comma-separated subnet IDs | ⚪ Optional |

### Setting Up Secrets

1. **Go to** your repository → Settings → Secrets and variables → Actions
2. **Add repository secrets** with the values above
3. **Test** with a manual workflow run

## Environment Variables

The workflows use these environment variables:

```yaml
env:
  AWS_REGION: us-east-1                # Can be customized per workflow
  TERRAFORM_VERSION: 1.6.0            # Terraform version to use
  TF_VAR_aws_region: us-east-1         # Passed to Terraform
```

## Example Outputs

### Pull Request Comment

```markdown
## 🚀 ML Platform Deployment Results

### 📝 Changes Detected
- **SageMaker Studio**: ✅ Changes detected
- **MLflow**: ➖ No changes
- **Workflows**: ➖ No changes

### 🏢 SageMaker Studio
- **Plan**: `success`
- **Deploy**: `success`
- **🔗 Studio URL**: [Access SageMaker Studio](https://studio-url)

### 📊 Summary
- **Environment**: `staging`
- **Region**: `us-east-1`
- **Triggered by**: Pull Request #123
```

### Workflow Summary

```markdown
## 🚀 ML Platform Deployment Summary

### 📊 Deployment Information
- **Event**: `push`
- **Environment**: `staging`
- **Region**: `us-east-1`
- **Action**: `apply`

### 🔧 Services Status
- **sagemaker-studio**: Plan: success, Deploy: success
- **mlflow**: Plan: success, Deploy: success

### 🔗 Quick Links
- [AWS SageMaker Console](https://console.aws.amazon.com/sagemaker/)
- [AWS S3 Console](https://console.aws.amazon.com/s3/)
```

## Advanced Configuration

### Custom Service Configuration

Add new services by modifying the matrix in `ml-platform-deploy.yml`:

```yaml
strategy:
  matrix:
    service: 
      - name: sagemaker-studio
        directory: ./sagemaker-studio/terraform/staging
      - name: mlflow
        directory: ./mlflow/terraform/staging
      - name: new-service
        directory: ./new-service/terraform/staging
```

### Environment-Specific Deployment

Create environment-specific workflows:

```yaml
# .github/workflows/deploy-production.yml
on:
  workflow_dispatch:
    inputs:
      environment:
        default: 'prod'
        type: choice
        options: ['prod']
```

### Custom Terraform Backend

Configure different backends per environment:

```yaml
terraform init \
  -backend-config="bucket=${{ secrets.PROD_TF_BACKEND_BUCKET }}" \
  -backend-config="key=${{ inputs.service_name }}/prod/terraform.tfstate"
```

## Troubleshooting

### Common Issues

1. **"No changes detected"**
   - Check file paths in workflow triggers
   - Ensure changes are in monitored directories
   - Verify git diff is working correctly

2. **"Plan failed"**
   - Check AWS credentials and permissions
   - Verify Terraform configuration syntax
   - Review variable values and defaults

3. **"Deploy failed"**
   - Check AWS resource limits and quotas
   - Verify network configuration (VPC, subnets)
   - Review CloudWatch logs for detailed errors

4. **"Workflow not triggered"**
   - Check branch protection rules
   - Verify file path patterns in triggers
   - Ensure workflow has required permissions

### Debug Steps

1. **Check workflow logs** in GitHub Actions
2. **Review Terraform plan** output in artifacts
3. **Verify AWS permissions** using AWS CLI
4. **Test locally** with same Terraform configuration
5. **Check AWS CloudTrail** for API call errors

### Getting Help

1. **Review this README** for configuration guidance
2. **Check individual workflow files** for specific requirements
3. **Examine workflow run logs** for detailed error messages
4. **Test with simplified configuration** to isolate issues
5. **Use manual workflow dispatch** for debugging

## Migration Guide

### From Legacy SageMaker Workflow

If you're migrating from the old `sagemaker-studio-deploy.yml`:

1. **Switch to new workflows**:
   - Use `ml-platform-deploy.yml` for main deployments
   - Use `on-pull-request.yml` for PR testing

2. **Update automation**:
   - Remove references to old workflow
   - Update any external CI/CD dependencies

3. **Test thoroughly**:
   - Run manual deployments first
   - Verify all secrets and variables work
   - Test both plan and apply operations

### Adding New Services

To add a new service to the platform:

1. **Create Terraform module** in `terraform/module/service-name/`
2. **Create environment implementation** in `service-name/terraform/staging/`
3. **Add to matrix** in `ml-platform-deploy.yml`
4. **Add path monitoring** in workflow triggers
5. **Update this README** with new service information

## Best Practices

### Workflow Management

1. **Use descriptive commit messages** to trigger appropriate workflows
2. **Test in pull requests** before merging to main
3. **Monitor workflow runs** for failures and performance
4. **Keep secrets up to date** and rotate regularly

### Terraform Best Practices

1. **Use remote state** with S3 backend
2. **Lock state** with DynamoDB table
3. **Plan before apply** in all environments
4. **Use consistent naming** across resources

### Security Best Practices

1. **Use least privilege** IAM policies
2. **Rotate AWS credentials** regularly
3. **Enable CloudTrail** for audit logging
4. **Use environment protection** for production

## Support

For issues with workflows:

1. **Check this documentation** first
2. **Review workflow run logs** for specific errors
3. **Test Terraform locally** to isolate issues
4. **File an issue** in the infrastructure repository

For infrastructure issues:

1. **Check AWS console** for resource status
2. **Review Terraform state** for inconsistencies
3. **Check AWS service health** status
4. **Contact AWS support** for service-specific issues
