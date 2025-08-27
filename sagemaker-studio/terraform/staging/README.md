# SageMaker Studio - Staging Environment

This directory contains the Terraform configuration for deploying SageMaker Studio in the staging environment for user **zali**.

## 🏗️ Architecture

This configuration deploys:
- **SageMaker Studio Domain** with IAM authentication
- **User Profile** for "zali"
- **IAM Execution Role** with ML-specific permissions
- **S3 Bucket** for ML artifacts and model storage
- **VPC Integration** for secure networking

## 📋 Prerequisites

### AWS Infrastructure
- ✅ AWS Account with appropriate permissions
- ✅ VPC with private subnets (tagged as `Type: private`)
- ✅ VPC named `staging-vpc` (or update `vpc_name` in terraform.tfvars)
- ✅ Internet connectivity (NAT Gateway or VPC Endpoints)

### GitHub Repository Setup
- ✅ Repository secrets configured (see [GitHub Secrets](#github-secrets) section)
- ✅ AWS OIDC provider configured (recommended) or AWS access keys

## 🚀 Deployment Methods

### Method 1: GitHub Actions (Recommended)

The repository includes a GitHub Actions workflow that automatically deploys on push to `main` branch.

#### Automatic Deployment
```bash
# Push changes to main branch
git add .
git commit -m "Deploy SageMaker Studio for zali"
git push origin main
```

#### Manual Deployment
1. Go to **Actions** tab in GitHub
2. Select **Deploy SageMaker Studio (Staging)** workflow
3. Click **Run workflow**
4. Choose action: `plan`, `apply`, or `destroy`

### Method 2: Local Deployment

```bash
# Navigate to staging directory
cd sagemaker-studio/terraform/staging

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure
terraform apply

# Clean up (when needed)
terraform destroy
```

## ⚙️ Configuration

### Current Configuration (terraform.tfvars)

```hcl
# AWS Settings
aws_region = "us-east-1"
vpc_name   = "staging-vpc"

# User Configuration
user_profile_name  = "zali"
bucket_name_suffix = "zali-staging"

# Instance Types (cost-optimized for staging)
default_instance_type         = "ml.t3.medium"
jupyter_instance_type        = "ml.t3.medium"
kernel_gateway_instance_type = "ml.t3.medium"
tensorboard_instance_type    = "ml.t3.medium"

# Network Settings
auth_mode               = "IAM"
app_network_access_type = "PublicInternetOnly"
```

### Customization

To customize the deployment, modify `terraform.tfvars`:

```hcl
# Change AWS region
aws_region = "us-west-2"

# Use different VPC
vpc_name = "my-custom-vpc"

# Upgrade instance types for better performance
jupyter_instance_type = "ml.m5.large"

# Enable VPC-only mode for enhanced security
app_network_access_type = "VpcOnly"
```

## 🔐 GitHub Secrets

Configure these repository secrets for GitHub Actions deployment:

### Required Secrets

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key ID | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `your-secret-key` |

### Optional Secrets

| Secret Name | Description | Default Value |
|-------------|-------------|---------------|
| `VPC_NAME` | Name of the VPC to deploy into | `staging-vpc` |
| `BUCKET_NAME_SUFFIX` | Unique suffix for S3 bucket | `zali-staging` |
| `TF_BACKEND_BUCKET` | S3 bucket for Terraform state | Uses local state |

### AWS Authentication

Using AWS access keys for authentication:

```yaml
AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: your-secret-key
```

**Note**: For enhanced security in production, consider using OIDC authentication instead.

## 📦 Outputs

After successful deployment, you'll get:

```hcl
# SageMaker Studio Access
sagemaker_domain_id   = "d-xxxxxxxxxxxx"
sagemaker_domain_url  = "https://d-xxxxxxxxxxxx.studio.us-east-1.sagemaker.aws/"
sagemaker_user_profile_name = "zali"

# IAM Role
sagemaker_execution_role_arn = "arn:aws:iam::123456789012:role/sagemaker-studio-staging-execution-role"

# S3 Storage
ml_artifacts_bucket_name = "sagemaker-studio-staging-ml-bucket-zali-staging"

# CloudFormation Compatibility
BucketName     = "sagemaker-studio-staging-ml-bucket-zali-staging"
RoleArn        = "arn:aws:iam::123456789012:role/sagemaker-studio-staging-execution-role"
DomainId       = "d-xxxxxxxxxxxx"
StudioUserName = "zali"
```

## 🔗 Accessing SageMaker Studio

### Via AWS Console
1. Go to [SageMaker Console](https://console.aws.amazon.com/sagemaker/)
2. Click **Studio** in left navigation
3. Select domain: `sagemaker-studio-staging-domain`
4. Launch Studio for user: `zali`

### Via CLI
```bash
# Get domain ID
aws sagemaker list-domains --region us-east-1

# Create presigned URL
aws sagemaker create-presigned-domain-url \
  --domain-id d-xxxxxxxxxxxx \
  --user-profile-name zali \
  --region us-east-1
```

### Direct URL
Use the `sagemaker_domain_url` output to access Studio directly.

## 🏷️ Resource Naming Convention

All resources follow this naming pattern:

| Resource | Name Pattern | Example |
|----------|--------------|---------|
| Domain | `{project}-{env}-studio-domain` | `sagemaker-studio-staging-studio-domain` |
| IAM Role | `{project}-{env}-execution-role` | `sagemaker-studio-staging-execution-role` |
| S3 Bucket | `{project}-{env}-ml-bucket-{suffix}` | `sagemaker-studio-staging-ml-bucket-zali-staging` |
| User Profile | `{user}` | `zali` |

## 🏷️ Resource Tags

All resources are tagged with:

```hcl
Project     = "sagemaker-studio"
Environment = "staging"
ManagedBy   = "terraform"
Owner       = "zali"
Repository  = "infrastructure"
Team        = "ML-Engineering"
```

## 📊 Cost Optimization

Current configuration is optimized for staging costs:

- **Instance Types**: `ml.t3.medium` (burstable performance)
- **Network**: `PublicInternetOnly` (no VPC endpoints needed)
- **S3**: Standard storage with lifecycle policies
- **Auto-scaling**: Enabled to minimize idle costs

### Estimated Monthly Cost
- SageMaker Studio Domain: ~$0 (no charge for domain)
- Compute instances: ~$50-100 (based on usage)
- S3 storage: ~$5-20 (based on data volume)
- **Total**: ~$55-120/month (usage-dependent)

## 🔧 Troubleshooting

### Common Issues

#### 1. VPC Not Found
```
Error: no matching VPC found
```
**Solution**: Update `vpc_name` in terraform.tfvars or create VPC with correct name tag.

#### 2. Subnet Issues
```
Error: no matching subnet found
```
**Solution**: Ensure private subnets are tagged with `Type: private`.

#### 3. IAM Permissions
```
Error: AccessDenied
```
**Solution**: Verify GitHub Actions role has necessary permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sagemaker:*",
        "iam:*",
        "s3:*",
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 4. Domain Creation Timeout
```
Error: timeout while waiting for domain to become active
```
**Solution**: Domain creation can take 10-20 minutes. Increase timeout or check AWS console.

### Debug Commands

```bash
# Check domain status
aws sagemaker describe-domain --domain-id $(terraform output -raw sagemaker_domain_id)

# List user profiles
aws sagemaker list-user-profiles --domain-id-equals $(terraform output -raw sagemaker_domain_id)

# Check IAM role
aws iam get-role --role-name $(terraform output -raw sagemaker_execution_role_name)

# Test S3 access
aws s3 ls s3://$(terraform output -raw ml_artifacts_bucket_name)
```

## 🔄 State Management

### Local State (Default)
Terraform state is stored locally. **Not recommended for team environments.**

### Remote State (Recommended)
Configure S3 backend by adding to `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "sagemaker-studio/staging/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Set `TF_BACKEND_BUCKET` secret in GitHub for automatic configuration.

## 🔐 Security Considerations

### Current Security Posture
- ✅ IAM-based authentication
- ✅ VPC deployment with private subnets
- ✅ S3 encryption at rest
- ✅ Least privilege IAM policies
- ✅ Public access blocked on S3

### Production Recommendations
- 🔒 Switch to `app_network_access_type = "VpcOnly"`
- 🔒 Enable VPC Flow Logs
- 🔒 Use AWS SSO for user authentication
- 🔒 Implement S3 bucket policies
- 🔒 Enable CloudTrail logging

## 📚 Next Steps

1. **Access SageMaker Studio** using the provided URL
2. **Test ML workloads** with sample notebooks
3. **Set up MLflow integration** (see mlflow module)
4. **Configure lifecycle configurations** for custom environments
5. **Set up monitoring** with CloudWatch

## 🤝 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Check AWS CloudFormation events
4. Contact the ML Engineering team

---

**Last Updated**: $(date)  
**Terraform Version**: >= 1.5  
**AWS Provider Version**: >= 5.0
