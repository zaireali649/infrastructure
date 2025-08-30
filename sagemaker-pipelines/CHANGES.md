# ECR Repository Management Changes

## Summary

Modified the SageMaker Pipelines infrastructure to use existing ECR repositories instead of creating them automatically. This change ensures better control over ECR repository lifecycle and prevents the infrastructure from creating resources it doesn't need to manage.

## Changes Made

### 1. Build Script (`scripts/build_push_ecr.sh`)

**Before**: Script would create ECR repositories if they didn't exist
**After**: Script verifies ECR repositories exist and fails with helpful error message if they don't

- Replaced `create_ecr_repo()` function with `verify_ecr_repo()` function
- Updated main logic to verify instead of create repositories
- Updated help text to clarify prerequisites
- Added clear error messages with creation commands

### 2. GitHub Workflow (`.github/workflows/deploy-sagemaker-pipelines.yml`)

**Before**: Workflow would create ECR repositories during CI/CD if they didn't exist
**After**: Workflow verifies ECR repositories exist and fails with helpful error message if they don't

- Replaced ECR creation logic with verification logic
- Added clear error messages for missing repositories

### 3. Terraform Module (`terraform/module/sagemaker-pipelines/`)

**Status**: No changes needed
- The Terraform module already correctly expects existing ECR repository URIs as input variables
- No ECR resources were being created in the module itself

### 4. Documentation Updates

**Module README** (`terraform/module/sagemaker-pipelines/README.md`):
- Clarified that ECR repositories must exist before using the module
- Added section explaining ECR repository management approach
- Updated prerequisites section

**Main README** (`sagemaker-pipelines/README.md`):
- Added ECR repository creation step to Quick Start guide
- Updated prerequisite list to include ECR repositories
- Added troubleshooting section for missing ECR repositories
- Provided CLI commands for creating repositories

## Prerequisites Now Required

Before using this infrastructure, you must create the following ECR repositories:

```bash
# Create training repository
aws ecr create-repository \
  --repository-name ml-platform-staging-training \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Create inference repository
aws ecr create-repository \
  --repository-name ml-platform-staging-inference \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true
```

## Benefits of This Change

1. **Separation of Concerns**: ECR repository lifecycle is managed separately from SageMaker pipeline infrastructure
2. **Better Control**: Teams can manage ECR repositories with their own policies, tags, and lifecycle rules
3. **Prevents Resource Conflicts**: Avoids potential conflicts when multiple environments or teams might create the same repositories
4. **Clearer Error Messages**: When repositories are missing, users get clear guidance on how to create them
5. **Infrastructure Consistency**: Aligns with the pattern of using existing resources (VPC, S3, etc.)

## Migration Guide

If you're migrating from the previous version:

1. **Create ECR repositories** if they don't exist (see commands above)
2. **Update your CI/CD pipelines** to create ECR repositories as a separate step if needed
3. **Run the build scripts** - they will now verify repositories exist instead of creating them
4. **No Terraform changes needed** - the module already expects existing repository URIs

## Files Modified

- `sagemaker-pipelines/scripts/build_push_ecr.sh`
- `.github/workflows/deploy-sagemaker-pipelines.yml`
- `terraform/module/sagemaker-pipelines/README.md`
- `sagemaker-pipelines/README.md`

## Files Created

- `sagemaker-pipelines/CHANGES.md` (this file)
