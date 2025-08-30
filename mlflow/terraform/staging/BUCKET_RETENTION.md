# MLflow S3 Bucket Retention Guide

This guide explains how to handle S3 bucket retention and import scenarios for the MLflow infrastructure.

## Problem Solved

Previously, when running `terraform destroy` on MLflow infrastructure, you would encounter this error:
```
Error: deleting S3 Bucket (mlflow-staging-mlflow-artifacts-zali-staging): operation error S3: DeleteBucket, 
https response error StatusCode: 409, RequestID: JDRZ595G643378DQ, HostID: nmm+ezBH51RtXkr2Vu21QbSlCH8S3RubyCT5/1kSryCGtaM/+YzHVzoZBLiFZRfCuq8ro8/OBa0=, 
api error BucketNotEmpty: The bucket you tried to delete is not empty. You must delete all versions in the bucket.
```

## Solution

We've implemented CloudFormation-like bucket retention functionality using Terraform lifecycle rules.

## Configuration Approach

### Hardcoded Bucket Protection
- S3 bucket retention is now **hardcoded** with `prevent_destroy = true`
- Applied to the bucket and all its configuration resources (versioning, encryption, public access block)
- This approach is required because Terraform's `prevent_destroy` doesn't accept variables

### Why Hardcoded?
Terraform's lifecycle rules require literal boolean values, not variables:
```hcl
lifecycle {
  prevent_destroy = true  # ✅ Works
  prevent_destroy = var.retain_bucket  # ❌ Error: Variables not allowed
}
```

## Usage Scenarios

### Scenario 1: Current Error Resolution
If you're currently experiencing the bucket deletion error:

1. **The protection is now built-in** - no configuration changes needed

2. **Apply the updated module**:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Now you can safely destroy without bucket deletion**:
   ```bash
   terraform destroy
   ```
   The S3 bucket and its contents will remain intact.

### Scenario 2: Working with Existing Buckets
If you have an existing bucket that needs to be managed by Terraform:

1. **Import the existing bucket**:
   ```bash
   terraform import 'module.mlflow.aws_s3_bucket.mlflow_artifacts[0]' mlflow-staging-mlflow-artifacts-zali-staging
   ```

2. **Import bucket configuration resources** (if they exist):
   ```bash
   terraform import 'module.mlflow.aws_s3_bucket_versioning.mlflow_artifacts[0]' mlflow-staging-mlflow-artifacts-zali-staging
   terraform import 'module.mlflow.aws_s3_bucket_server_side_encryption_configuration.mlflow_artifacts[0]' mlflow-staging-mlflow-artifacts-zali-staging
   terraform import 'module.mlflow.aws_s3_bucket_public_access_block.mlflow_artifacts[0]' mlflow-staging-mlflow-artifacts-zali-staging
   ```

3. **Run terraform plan** to verify no unwanted changes

### Scenario 3: Force Bucket Deletion (if needed)
If you really need to delete the bucket and its contents:

1. **Edit the module directly** in `terraform/module/mlflow/main.tf`:
   ```hcl
   lifecycle {
     prevent_destroy = false  # Change from true to false
   }
   ```
   Do this for all S3 bucket resources (4 total).

2. **Empty the bucket first** (either manually or with AWS CLI):
   ```bash
   aws s3 rm s3://mlflow-staging-mlflow-artifacts-zali-staging --recursive
   aws s3api delete-bucket --bucket mlflow-staging-mlflow-artifacts-zali-staging
   ```

3. **Run destroy**:
   ```bash
   terraform destroy
   ```

4. **Remember to revert the changes** for future deployments.

## Best Practices

1. **Bucket protection is now automatic** - no configuration needed
2. **Import existing buckets** using the terraform import commands shown above
3. **Backup important artifacts** before any destroy operations
4. **Use versioning** (enabled by default) to protect against accidental overwrites
5. **Monitor bucket costs** as retained buckets will continue to incur charges

## Technical Implementation

The solution uses Terraform's `lifecycle` block with `prevent_destroy = true`:

```hcl
resource "aws_s3_bucket" "mlflow_artifacts" {
  # ... other configuration ...
  
  lifecycle {
    prevent_destroy = var.retain_bucket_on_destroy
  }
}
```

This approach:
- Prevents accidental bucket deletion
- Maintains artifact history
- Allows infrastructure recreation without data loss
- Follows infrastructure-as-code best practices
