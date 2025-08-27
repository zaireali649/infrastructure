# Quick Setup Guide - SageMaker Studio Staging

This guide will help you set up the repository for automated SageMaker Studio deployment using GitHub Actions.

## 🚀 Quick Start Checklist

### ✅ Step 1: Repository Secrets Setup

Navigate to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add:

#### Required Secrets
```
AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: your-secret-key
```

#### Optional Secrets (with defaults)
```
# VPC_ID: Optional - defaults to vpc-0a9ee577 in staging
# SUBNET_IDS: Optional - will auto-discover from VPC if not provided
BUCKET_NAME_SUFFIX: zali-staging
TF_BACKEND_BUCKET: your-terraform-state-bucket
```

### ✅ Step 2: Create AWS IAM User

Create an IAM user with programmatic access and the necessary permissions.

Attach this policy to the user:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sagemaker:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "s3:*",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Resource": "*"
    }
  ]
}
```

### ✅ Step 3: Update Configuration

Edit `terraform.tfvars` to match your environment:

```hcl
# Update these values
aws_region = "your-preferred-region"
vpc_id     = "vpc-xxxxxxxxx"
bucket_name_suffix = "your-unique-suffix"
```

### ✅ Step 4: Deploy!

#### Option A: Automatic Deployment
```bash
git add .
git commit -m "Setup SageMaker Studio for zali"
git push origin main
```

#### Option B: Manual Deployment
1. Go to **Actions** tab in GitHub
2. Select **Deploy SageMaker Studio (Staging)**
3. Click **Run workflow** → **apply**

## 🔍 Verification

After deployment, verify everything works:

1. **Check GitHub Actions**: Ensure the workflow completed successfully
2. **AWS Console**: Verify SageMaker Studio domain is created
3. **Access Studio**: Use the output URL to access SageMaker Studio

## 🔐 Security Note

The current setup uses AWS access keys for simplicity. For enhanced security in production environments, consider:

1. Using AWS OIDC authentication
2. Implementing least-privilege IAM policies
3. Rotating access keys regularly
4. Using AWS Organizations SCPs for additional guardrails

## 📞 Need Help?

- Check the [main README](README.md) for detailed troubleshooting
- Review the GitHub Actions logs for specific error messages
- Ensure your VPC and subnets are properly configured

---

**Estimated Setup Time**: 15-30 minutes  
**Deployment Time**: 15-20 minutes
