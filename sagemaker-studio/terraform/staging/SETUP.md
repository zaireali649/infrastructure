# Quick Setup Guide - SageMaker Studio Staging

This guide will help you set up the repository for automated SageMaker Studio deployment using GitHub Actions.

## 🚀 Quick Start Checklist

### ✅ Step 1: Repository Secrets Setup

Navigate to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add:

#### Required Secret
```
AWS_ROLE_ARN: arn:aws:iam::YOUR-ACCOUNT-ID:role/github-actions-role
```

#### Optional Secrets (with defaults)
```
VPC_NAME: staging-vpc
BUCKET_NAME_SUFFIX: zali-staging
TF_BACKEND_BUCKET: your-terraform-state-bucket
```

### ✅ Step 2: AWS OIDC Provider Setup

Create an OIDC provider in AWS IAM if you haven't already:

```bash
# Using AWS CLI
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### ✅ Step 3: Create GitHub Actions IAM Role

Create a role that GitHub Actions can assume:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR-ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR-USERNAME/infrastructure:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Attach this policy to the role:

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

### ✅ Step 4: Update Configuration

Edit `terraform.tfvars` to match your environment:

```hcl
# Update these values
aws_region = "your-preferred-region"
vpc_name   = "your-vpc-name"
bucket_name_suffix = "your-unique-suffix"
```

### ✅ Step 5: Deploy!

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

## 🛠️ Alternative Setup (Access Keys)

If you prefer using access keys instead of OIDC:

1. Create an IAM user with the necessary permissions
2. Generate access keys
3. Add these secrets:
   ```
   AWS_ACCESS_KEY_ID: AKIA...
   AWS_SECRET_ACCESS_KEY: your-secret-key
   ```
4. Comment out the OIDC configuration in the workflow file

## 📞 Need Help?

- Check the [main README](README.md) for detailed troubleshooting
- Review the GitHub Actions logs for specific error messages
- Ensure your VPC and subnets are properly configured

---

**Estimated Setup Time**: 15-30 minutes  
**Deployment Time**: 15-20 minutes
