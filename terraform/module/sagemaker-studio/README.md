# SageMaker Studio Terraform Module

This Terraform module creates an Amazon SageMaker Studio Domain with associated IAM roles, S3 bucket, and user profiles for machine learning development and experimentation.

## Features

- **SageMaker Studio Domain**: Fully configured domain with customizable settings
- **IAM Role**: Pre-configured execution role with necessary permissions for SageMaker operations
- **S3 Bucket**: Optional ML artifacts bucket with versioning and encryption
- **User Profile**: Default user profile with customizable settings
- **Security**: Best practices for IAM permissions and S3 bucket security
- **Flexibility**: Configurable app settings for Jupyter, Kernel Gateway, and TensorBoard

## Architecture

The module creates the following AWS resources:

- `aws_sagemaker_domain`: SageMaker Studio Domain
- `aws_sagemaker_user_profile`: Default user profile
- `aws_iam_role`: SageMaker execution role
- `aws_iam_role_policy`: Basic SageMaker permissions
- `aws_s3_bucket`: ML artifacts storage (optional)
- `aws_s3_bucket_*`: S3 security and configuration resources

## Usage

### Basic Usage

```hcl
module "sagemaker_studio" {
  source = "./terraform/module/sagemaker-studio"

  project_name        = "my-ml-project"
  environment         = "staging"
  bucket_name_suffix  = "team-alpha"
  vpc_id              = "vpc-12345678"
  subnet_ids          = ["subnet-12345678", "subnet-87654321"]

  tags = {
    Team        = "ML-Engineering"
    Environment = "staging"
    Project     = "my-ml-project"
  }
}
```

### Advanced Usage with Custom Settings

```hcl
module "sagemaker_studio" {
  source = "./terraform/module/sagemaker-studio"

  # Required parameters
  project_name        = "advanced-ml-project"
  environment         = "prod"
  bucket_name_suffix  = "prod-team"
  vpc_id              = "vpc-12345678"
  subnet_ids          = ["subnet-12345678", "subnet-87654321"]

  # Optional customizations
  domain_name            = "my-custom-domain"
  user_profile_name      = "ml-engineer"
  auth_mode             = "IAM"
  app_network_access_type = "VpcOnly"
  default_instance_type  = "ml.m5.large"

  # Custom S3 bucket
  s3_bucket_name = "my-custom-ml-bucket"

  # App settings
  jupyter_server_app_settings = {
    default_resource_spec = {
      instance_type = "ml.t3.medium"
    }
    lifecycle_config_arns = []
  }

  kernel_gateway_app_settings = {
    default_resource_spec = {
      instance_type = "ml.t3.medium"
    }
  }

  # Sharing settings
  sharing_settings = {
    notebook_output_option = "Allowed"
    s3_output_path        = "s3://my-custom-ml-bucket/notebook-outputs/"
  }

  # Additional IAM policies
  additional_execution_role_policies = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]

  tags = {
    Team        = "ML-Engineering"
    Environment = "prod"
    Project     = "advanced-ml-project"
    CostCenter  = "ML-Operations"
  }
}
```

### Using in a Staging Environment

```hcl
# staging/main.tf
module "sagemaker_studio" {
  source = "../../terraform/module/sagemaker-studio"

  project_name        = var.project_name
  environment         = "staging"
  bucket_name_suffix  = var.bucket_name_suffix
  vpc_id              = data.aws_vpc.main.id
  subnet_ids          = data.aws_subnets.private.ids

  # Staging-specific settings
  default_instance_type = "ml.t3.medium"
  
  tags = local.common_tags
}

# Output important values for other resources
output "sagemaker_execution_role_arn" {
  value = module.sagemaker_studio.execution_role_arn
}

output "sagemaker_domain_id" {
  value = module.sagemaker_studio.domain_id
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project (used for resource naming) | `string` | n/a | yes |
| environment | Environment name (e.g., staging, prod) | `string` | `"staging"` | no |
| bucket_name_suffix | Unique suffix for S3 bucket naming (e.g., your name or initials) | `string` | n/a | yes |
| vpc_id | VPC ID where SageMaker Studio will be deployed | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for SageMaker Studio (private subnets recommended) | `list(string)` | n/a | yes |
| domain_name | Name for the SageMaker Studio Domain (optional, will be auto-generated if not provided) | `string` | `null` | no |
| user_profile_name | Name for the default SageMaker Studio user profile | `string` | `"default-user"` | no |
| auth_mode | Authentication mode for SageMaker Studio Domain | `string` | `"IAM"` | no |
| app_network_access_type | Network access type for SageMaker Studio apps | `string` | `"PublicInternetOnly"` | no |
| enable_s3_bucket | Whether to create an S3 bucket for ML artifacts | `bool` | `true` | no |
| s3_bucket_name | Custom S3 bucket name (optional, will be auto-generated if not provided) | `string` | `null` | no |
| additional_execution_role_policies | Additional IAM policy ARNs to attach to the SageMaker execution role | `list(string)` | `[]` | no |
| default_instance_type | Default instance type for SageMaker Studio apps | `string` | `"ml.t3.medium"` | no |
| execution_role_name | Custom name for the SageMaker execution role (optional, will be auto-generated if not provided) | `string` | `null` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

### Complex Input Variables

#### sharing_settings

```hcl
sharing_settings = {
  notebook_output_option = "Allowed"  # or "Disabled"
  s3_output_path        = "s3://bucket/path/"  # optional
  s3_kms_key_id         = "alias/aws/s3"       # optional
}
```

#### jupyter_server_app_settings / kernel_gateway_app_settings / tensor_board_app_settings

```hcl
jupyter_server_app_settings = {
  default_resource_spec = {
    instance_type               = "ml.t3.medium"
    lifecycle_config_arn       = "arn:aws:sagemaker:region:account:studio-lifecycle-config/config-name"
    sagemaker_image_arn        = "arn:aws:sagemaker:region:account:image/image-name"
    sagemaker_image_version_arn = "arn:aws:sagemaker:region:account:image-version/image-name/version"
  }
  lifecycle_config_arns = [
    "arn:aws:sagemaker:region:account:studio-lifecycle-config/config-name"
  ]
}
```

## Outputs

| Name | Description |
|------|-------------|
| domain_id | SageMaker Studio Domain ID |
| domain_arn | SageMaker Studio Domain ARN |
| domain_url | SageMaker Studio Domain URL |
| domain_name | SageMaker Studio Domain Name |
| execution_role_arn | SageMaker execution role ARN |
| execution_role_name | SageMaker execution role name |
| user_profile_arn | SageMaker Studio User Profile ARN |
| user_profile_name | SageMaker Studio User Profile Name |
| s3_bucket_name | S3 bucket name for ML artifacts |
| s3_bucket_arn | S3 bucket ARN for ML artifacts |
| s3_bucket_regional_domain_name | S3 bucket regional domain name |

### CloudFormation Compatibility Outputs

For migration from CloudFormation, these outputs match the original template:

| Name | Description |
|------|-------------|
| BucketName | S3 bucket for ML data and model artifacts |
| RoleArn | SageMaker execution role |
| DomainId | SageMaker Studio Domain ID |
| StudioUserName | SageMaker Studio User |

## Network Configuration

### VPC Requirements

- **VPC**: Must have DNS resolution and DNS hostnames enabled
- **Subnets**: Private subnets are recommended for security
- **Internet Access**: Ensure NAT Gateway or VPC endpoints for internet access
- **Security Groups**: Module creates necessary security group rules automatically

### VPC-Only Mode

When using `app_network_access_type = "VpcOnly"`:

1. Create VPC endpoints for SageMaker services:
   - `com.amazonaws.region.sagemaker.api`
   - `com.amazonaws.region.sagemaker.runtime`
   - `com.amazonaws.region.sagemaker.featurestore-runtime`

2. Ensure S3 VPC endpoint exists for artifact storage

## Security Considerations

### IAM Permissions

The module creates an IAM role with the following permissions:
- Full SageMaker access
- S3 access (scoped to created bucket if enabled)
- CloudWatch Logs access
- ECR access for custom images
- EC2 network interface management (for VPC mode)

### S3 Security

When S3 bucket is enabled:
- Server-side encryption with AES-256
- Versioning enabled
- Public access blocked
- Secure bucket policy

## Migration from CloudFormation

This module is designed to be compatible with the existing CloudFormation template. Key differences:

1. **Enhanced Security**: More granular IAM permissions and S3 security
2. **Additional Features**: Support for lifecycle configs, custom images, and app settings
3. **Flexibility**: More configuration options for different environments
4. **Best Practices**: Follows Terraform and AWS best practices

### Migration Steps

1. Export CloudFormation stack outputs
2. Update Terraform configuration with equivalent values
3. Import existing resources (optional)
4. Apply Terraform configuration

## Examples

### Complete Example with Existing VPC

```hcl
# Data sources for existing VPC
data "aws_vpc" "existing" {
  tags = {
    Name = "ml-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  tags = {
    Type = "private"
  }
}

# SageMaker Studio module
module "sagemaker_studio" {
  source = "./terraform/module/sagemaker-studio"

  project_name        = "ml-platform"
  environment         = "staging"
  bucket_name_suffix  = "staging-01"
  vpc_id              = data.aws_vpc.existing.id
  subnet_ids          = data.aws_subnets.private.ids

  # Production-ready settings
  app_network_access_type = "VpcOnly"
  auth_mode              = "IAM"

  tags = {
    Environment = "staging"
    Team        = "ML-Engineering"
    Project     = "ml-platform"
    Owner       = "ml-team@company.com"
  }
}
```

## Troubleshooting

### Common Issues

1. **Domain Creation Fails**: Check VPC and subnet configuration
2. **Access Denied**: Verify IAM permissions for the Terraform execution role
3. **Bucket Name Conflicts**: Ensure bucket_name_suffix is unique globally
4. **Network Issues**: Verify VPC DNS settings and internet access

### Debug Commands

```bash
# Check domain status
aws sagemaker describe-domain --domain-id <domain-id>

# List user profiles
aws sagemaker list-user-profiles --domain-id-equals <domain-id>

# Check execution role
aws iam get-role --role-name <execution-role-name>
```

## Contributing

When contributing to this module:

1. Follow Terraform best practices
2. Update documentation for any new variables
3. Add examples for complex configurations
4. Test with multiple AWS regions
5. Ensure backward compatibility

## License

This module is licensed under the MIT License. See LICENSE file for details.
