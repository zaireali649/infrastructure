# Selective MLflow Destroy - Keep S3 Bucket

This guide shows how to destroy MLflow compute resources while preserving the S3 bucket and all experiment data.

## What Gets Destroyed
- ✅ SageMaker MLflow Tracking Server (compute)
- ✅ IAM Role and Policies (can be recreated)
- ✅ IAM Role Policy Attachments

## What Gets Preserved
- 🛡️ S3 Bucket (`mlflow-staging-mlflow-artifacts-zali-staging`)
- 🛡️ S3 Bucket Versioning Configuration
- 🛡️ S3 Bucket Encryption Configuration  
- 🛡️ S3 Bucket Public Access Block
- 🛡️ All MLflow Experiment Data and Artifacts

## Destroy Commands

### Option 1: Individual Targeted Destroys (Recommended)

```bash
# Destroy the MLflow tracking server first
terraform destroy -target=module.mlflow.aws_sagemaker_mlflow_tracking_server.mlflow

# Destroy IAM role policy attachments (if any exist)
terraform destroy -target=module.mlflow.aws_iam_role_policy_attachment.additional_policies

# Destroy KMS policy (if it exists)
terraform destroy -target=module.mlflow.aws_iam_role_policy.mlflow_kms_policy

# Destroy the basic IAM policy
terraform destroy -target=module.mlflow.aws_iam_role_policy.mlflow_basic_policy

# Destroy the IAM role last
terraform destroy -target=module.mlflow.aws_iam_role.mlflow_role
```

### Option 2: Multi-Target Destroy (Faster)

```bash
terraform destroy \
  -target=module.mlflow.aws_sagemaker_mlflow_tracking_server.mlflow \
  -target=module.mlflow.aws_iam_role_policy_attachment.additional_policies \
  -target=module.mlflow.aws_iam_role_policy.mlflow_kms_policy \
  -target=module.mlflow.aws_iam_role_policy.mlflow_basic_policy \
  -target=module.mlflow.aws_iam_role.mlflow_role
```

### Option 3: PowerShell/Windows (for local development)

```powershell
# Individual commands
terraform destroy -target="module.mlflow.aws_sagemaker_mlflow_tracking_server.mlflow"
terraform destroy -target="module.mlflow.aws_iam_role_policy_attachment.additional_policies"
terraform destroy -target="module.mlflow.aws_iam_role_policy.mlflow_kms_policy"
terraform destroy -target="module.mlflow.aws_iam_role_policy.mlflow_basic_policy"
terraform destroy -target="module.mlflow.aws_iam_role.mlflow_role"
```

## Verification

After selective destroy, verify what remains:

```bash
# Check remaining resources
terraform state list

# Should show only S3 bucket related resources:
# module.mlflow.aws_s3_bucket.mlflow_artifacts[0]
# module.mlflow.aws_s3_bucket_versioning.mlflow_artifacts[0]
# module.mlflow.aws_s3_bucket_server_side_encryption_configuration.mlflow_artifacts[0]
# module.mlflow.aws_s3_bucket_public_access_block.mlflow_artifacts[0]
```

## Recreating MLflow Later

When you want to recreate the MLflow tracking server:

```bash
# The S3 bucket will be imported automatically since it exists
terraform plan   # Should show creation of tracking server and IAM resources only
terraform apply  # Recreates compute resources, reuses existing bucket
```

## Benefits of This Approach

- 💰 **Cost Savings**: No compute charges for tracking server
- 🛡️ **Data Preservation**: All experiments and models remain intact
- ⚡ **Fast Recreation**: When needed, only compute resources need to be recreated
- 🔄 **Reversible**: Can easily bring back the tracking server later
