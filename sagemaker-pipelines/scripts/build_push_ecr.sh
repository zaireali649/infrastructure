#!/bin/bash
# Build and push Docker images to ECR for SageMaker Pipelines

set -e

# Configuration
PROJECT_NAME="ml-platform"
ENVIRONMENT="staging"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Image tags
TRAINING_TAG="${TRAINING_TAG:-v1.0.0}"
INFERENCE_TAG="${INFERENCE_TAG:-v1.0.0}"

# ECR repository names
TRAINING_REPO="${PROJECT_NAME}-${ENVIRONMENT}-training"
INFERENCE_REPO="${PROJECT_NAME}-${ENVIRONMENT}-inference"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if ECR repository exists
check_ecr_repo() {
    local repo_name=$1
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create ECR repository if it doesn't exist
create_ecr_repo() {
    local repo_name=$1
    print_status "Creating ECR repository: $repo_name"
    
    aws ecr create-repository \
        --repository-name "$repo_name" \
        --region "$AWS_REGION" \
        --image-scanning-configuration scanOnPush=true \
        --tags Key=Project,Value="$PROJECT_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="terraform"
    
    # Set lifecycle policy to keep only last 10 images
    aws ecr put-lifecycle-policy \
        --repository-name "$repo_name" \
        --region "$AWS_REGION" \
        --lifecycle-policy-text '{
            "rules": [{
                "rulePriority": 1,
                "description": "Keep last 10 images",
                "selection": {
                    "tagStatus": "tagged",
                    "tagPrefixList": ["v"],
                    "countType": "imageCountMoreThan",
                    "countNumber": 10
                },
                "action": {
                    "type": "expire"
                }
            }]
        }'
}

# Function to build and push Docker image
build_and_push() {
    local service=$1
    local repo_name=$2
    local tag=$3
    local dockerfile_path=$4
    
    print_status "Building and pushing $service image..."
    
    # Full image URI
    local image_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${repo_name}:${tag}"
    
    print_status "Building Docker image: $image_uri"
    
    # Change to the service directory
    pushd "src/$service" > /dev/null
    
    # Build the image
    docker build \
        --platform linux/amd64 \
        -t "$repo_name:$tag" \
        -t "$repo_name:latest" \
        -t "$image_uri" \
        -f Dockerfile \
        .
    
    if [ $? -ne 0 ]; then
        print_error "Docker build failed for $service"
        popd > /dev/null
        exit 1
    fi
    
    print_success "Docker build completed for $service"
    
    # Push the image
    print_status "Pushing image to ECR: $image_uri"
    docker push "$image_uri"
    
    if [ $? -ne 0 ]; then
        print_error "Docker push failed for $service"
        popd > /dev/null
        exit 1
    fi
    
    # Also push latest tag
    local latest_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${repo_name}:latest"
    docker push "$latest_uri"
    
    print_success "Image pushed successfully: $image_uri"
    
    popd > /dev/null
    
    echo "$image_uri"
}

# Function to update terraform.tfvars with new image URIs
update_terraform_vars() {
    local training_uri=$1
    local inference_uri=$2
    
    print_status "Updating terraform.tfvars with new image URIs..."
    
    local tfvars_file="terraform/staging/terraform.tfvars"
    
    if [ -f "$tfvars_file" ]; then
        # Create backup
        cp "$tfvars_file" "${tfvars_file}.backup.$(date +%Y%m%d-%H%M%S)"
        
        # Update image URIs
        sed -i.tmp "s|training_image_uri.*=.*|training_image_uri = \"$training_uri\"|" "$tfvars_file"
        sed -i.tmp "s|inference_image_uri.*=.*|inference_image_uri = \"$inference_uri\"|" "$tfvars_file"
        
        # Remove backup file created by sed
        rm -f "${tfvars_file}.tmp"
        
        print_success "Updated $tfvars_file with new image URIs"
    else
        print_warning "terraform.tfvars not found at $tfvars_file"
    fi
}

# Main execution
main() {
    print_status "Starting ECR build and push process"
    print_status "Project: $PROJECT_NAME, Environment: $ENVIRONMENT"
    print_status "AWS Account: $AWS_ACCOUNT_ID, Region: $AWS_REGION"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Login to ECR
    print_status "Logging in to ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    if [ $? -ne 0 ]; then
        print_error "ECR login failed"
        exit 1
    fi
    
    print_success "ECR login successful"
    
    # Check and create ECR repositories
    for repo in "$TRAINING_REPO" "$INFERENCE_REPO"; do
        if check_ecr_repo "$repo"; then
            print_status "ECR repository already exists: $repo"
        else
            create_ecr_repo "$repo"
            print_success "Created ECR repository: $repo"
        fi
    done
    
    # Build and push training image
    print_status "Processing training image..."
    training_uri=$(build_and_push "training" "$TRAINING_REPO" "$TRAINING_TAG")
    
    # Build and push inference image
    print_status "Processing inference image..."
    inference_uri=$(build_and_push "inference" "$INFERENCE_REPO" "$INFERENCE_TAG")
    
    # Update terraform.tfvars
    update_terraform_vars "$training_uri" "$inference_uri"
    
    print_success "All images built and pushed successfully!"
    echo
    print_status "Image URIs:"
    echo "Training:  $training_uri"
    echo "Inference: $inference_uri"
    echo
    print_status "Next steps:"
    echo "1. Review updated terraform/staging/terraform.tfvars"
    echo "2. Run 'cd terraform/staging && terraform plan' to see changes"
    echo "3. Run 'terraform apply' to deploy with new images"
}

# Handle script arguments
case "${1:-}" in
    "training")
        print_status "Building training image only..."
        aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        if ! check_ecr_repo "$TRAINING_REPO"; then
            create_ecr_repo "$TRAINING_REPO"
        fi
        training_uri=$(build_and_push "training" "$TRAINING_REPO" "$TRAINING_TAG")
        echo "Training image: $training_uri"
        ;;
    "inference")
        print_status "Building inference image only..."
        aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        if ! check_ecr_repo "$INFERENCE_REPO"; then
            create_ecr_repo "$INFERENCE_REPO"
        fi
        inference_uri=$(build_and_push "inference" "$INFERENCE_REPO" "$INFERENCE_TAG")
        echo "Inference image: $inference_uri"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [training|inference]"
        echo
        echo "Build and push Docker images to ECR for SageMaker Pipelines"
        echo
        echo "Options:"
        echo "  training   Build and push only the training image"
        echo "  inference  Build and push only the inference image"
        echo "  (no args)  Build and push both images"
        echo
        echo "Environment variables:"
        echo "  AWS_REGION      AWS region (default: us-east-1)"
        echo "  TRAINING_TAG    Training image tag (default: v1.0.0)"
        echo "  INFERENCE_TAG   Inference image tag (default: v1.0.0)"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown argument: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
