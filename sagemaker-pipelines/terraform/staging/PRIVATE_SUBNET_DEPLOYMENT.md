# Private Subnet Deployment Guide

This guide covers deploying SageMaker pipelines in private subnets for enhanced security and compliance.

## Overview

Private subnet deployment ensures that your ML training and inference jobs run without direct internet access, providing:

- **Enhanced Security**: No direct internet exposure
- **Compliance**: Meets strict network isolation requirements  
- **Data Protection**: All traffic stays within your VPC
- **Audit Trail**: Centralized network monitoring

## Prerequisites

### 1. VPC Infrastructure

You need:
- **VPC** with private subnets
- **Private subnets** in multiple AZs (recommended for HA)
- **Internet connectivity** via VPC endpoints OR NAT Gateway
- **Security groups** with appropriate rules

### 2. Required Network Connectivity

SageMaker jobs need access to these AWS services:

| Service | Purpose | Endpoint Type |
|---------|---------|---------------|
| **S3** | Model artifacts, data | Gateway Endpoint |
| **SageMaker API** | Pipeline operations | Interface Endpoint |
| **SageMaker Runtime** | Job execution | Interface Endpoint |
| **ECR API** | Container metadata | Interface Endpoint |
| **ECR DKR** | Container images | Interface Endpoint |
| **CloudWatch Logs** | Job logging | Interface Endpoint |
| **MLflow/SageMaker** | Model tracking | Interface Endpoint |

## Configuration

### 1. Basic Configuration

Copy and customize the example configuration:

```bash
cd sagemaker-pipelines/terraform/staging
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Your VPC and subnet configuration
vpc_id = "vpc-1234567890abcdef0"
subnet_ids = [
  "subnet-1234567890abcdef0",  # Private subnet 1
  "subnet-0987654321fedcba0"   # Private subnet 2
]
security_group_ids = ["sg-1234567890abcdef0"]
```

### 2. Security Group Configuration

Your security group needs these rules:

#### Outbound Rules (Required)
```hcl
# HTTPS to AWS services
{
  type        = "egress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # Or VPC endpoint IPs
}

# VPC communication
{
  type        = "egress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # Your VPC CIDR
}

# Self-communication (multi-instance jobs)
{
  type      = "egress"
  from_port = 0
  to_port   = 65535
  protocol  = "tcp"
  self      = true
}
```

#### Inbound Rules (Required)
```hcl
# Self-communication
{
  type      = "ingress"
  from_port = 0
  to_port   = 65535
  protocol  = "tcp"
  self      = true
}

# VPC communication
{
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # Your VPC CIDR
}
```

## Internet Connectivity Options

### Option 1: VPC Endpoints (Recommended)

More secure - traffic never leaves AWS backbone:

```hcl
# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

# SageMaker API Interface Endpoint
resource "aws_vpc_endpoint" "sagemaker_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ECR DKR Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# SageMaker Runtime Interface Endpoint
resource "aws_vpc_endpoint" "sagemaker_runtime" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.sagemaker.runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
```

### Option 2: NAT Gateway (Alternative)

Simpler but less secure - traffic goes through internet:

```hcl
# NAT Gateway in public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

# Associate route table with private subnets
resource "aws_route_table_association" "private" {
  count          = length(var.subnet_ids)
  subnet_id      = var.subnet_ids[count.index]
  route_table_id = aws_route_table.private.id
}
```

## Deployment

1. **Configure variables**:
   ```bash
   vim terraform.tfvars
   ```

2. **Plan deployment**:
   ```bash
   terraform plan
   ```

3. **Apply configuration**:
   ```bash
   terraform apply
   ```

## Verification

### 1. Check VPC Endpoints (if using)
```bash
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxx
```

### 2. Test Network Connectivity
```bash
# From a test instance in the same subnets
curl -I https://api.sagemaker.us-east-1.amazonaws.com
curl -I https://s3.us-east-1.amazonaws.com
```

### 3. Monitor Pipeline Execution
```bash
# Check pipeline status
aws sagemaker describe-pipeline --pipeline-name iris-ml-staging-training

# Check logs
aws logs describe-log-groups --log-group-name-prefix /aws/sagemaker
```

## Troubleshooting

### Common Issues

1. **Job fails with network timeout**:
   - Check VPC endpoints are created
   - Verify security group rules
   - Ensure DNS resolution works

2. **Container pull failures**:
   - Verify ECR endpoints exist
   - Check ECR permissions
   - Test ECR connectivity

3. **S3 access denied**:
   - Check S3 VPC endpoint
   - Verify bucket policies
   - Test S3 connectivity

### Debug Commands

```bash
# Check VPC endpoints
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=vpc-xxx

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Check route tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-xxx

# Test DNS resolution (from instance in VPC)
nslookup api.sagemaker.us-east-1.amazonaws.com
nslookup s3.us-east-1.amazonaws.com
```

## Security Benefits

Private subnet deployment provides:

- **Network Isolation**: Jobs can't access internet directly
- **Attack Surface Reduction**: No public IP addresses
- **Traffic Monitoring**: All traffic flows through VPC
- **Audit Compliance**: Meets strict security requirements
- **Enterprise Ready**: Suitable for regulated industries

## Cost Considerations

| Option | Setup Cost | Ongoing Cost | Security Level |
|--------|------------|--------------|----------------|
| **VPC Endpoints** | Medium | $22-45/month per endpoint | Highest |
| **NAT Gateway** | Low | $32-45/month | Medium |
| **Public Subnets** | None | None | Lowest |

VPC endpoints have higher ongoing costs but provide better security and compliance posture.
