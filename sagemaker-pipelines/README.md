# SageMaker ML Pipelines

Production-ready ML pipelines using SageMaker with MLflow tracking and Kafka integration for real-time predictions.

## 🏗️ Architecture

This project implements a complete ML platform with:

- **Training Pipeline**: Automated model training with MLflow experiment tracking
- **Inference Pipeline**: Daily batch processing that sends predictions to Kafka
- **Infrastructure as Code**: Terraform modules for reproducible deployments
- **Containerized Applications**: Docker containers with uv dependency management

## 📁 Project Structure

```
sagemaker-pipelines/
├── terraform/                    # Infrastructure configuration
│   ├── staging/
│   │   ├── main.tf              # Compose remote modules via ?ref=tag
│   │   ├── variables.tf         # Input variables
│   │   └── terraform.tfvars     # Environment-specific values
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
│
├── src/                         # Application source code
│   ├── training/                # ML training pipeline
│   │   ├── app/
│   │   │   ├── train.py         # Main training script
│   │   │   ├── utils.py         # Utility functions
│   │   │   └── __init__.py      # Package initialization
│   │   ├── pyproject.toml       # uv project configuration
│   │   ├── uv.lock              # Locked dependencies
│   │   └── Dockerfile           # Container definition
│   └── inference/               # Daily processing → Kafka
│       ├── app/
│       │   ├── score_to_kafka.py # Main inference script
│       │   ├── model_io.py      # MLflow model loading
│       │   ├── kafka_io.py      # Kafka producer client
│       │   └── __init__.py      # Package initialization
│       ├── pyproject.toml       # uv project configuration
│       ├── uv.lock              # Locked dependencies
│       └── Dockerfile           # Container definition
│
├── scripts/                     # Automation scripts
│   ├── build_push_ecr.sh        # Build and push containers to ECR
│   └── generate_params_json.py  # Generate pipeline parameters
├── .editorconfig               # Editor configuration
├── .gitignore                  # Git ignore patterns
└── README.md                   # This file
```

## 🚀 Quick Start

### 1. Prerequisites

- **AWS CLI** configured with appropriate permissions
- **Docker** installed and running
- **Terraform** >= 1.5
- **uv** for Python dependency management
- **Existing MLflow tracking server** (deployed via your existing mlflow module)

### 2. Build and Push Container Images

```bash
# Build and push both training and inference images
./scripts/build_push_ecr.sh

# Or build individually
./scripts/build_push_ecr.sh training
./scripts/build_push_ecr.sh inference
```

### 3. Configure Environment

Edit `terraform/staging/terraform.tfvars`:

```hcl
# Update these values for your environment
kafka_bootstrap_servers = "your-kafka-cluster.amazonaws.com:9092"
mlflow_tracking_server_name = "your-mlflow-server-name"

# Image URIs will be auto-updated by build script
training_image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/..."
inference_image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/..."
```

### 4. Deploy Infrastructure

```bash
cd terraform/staging
terraform init
terraform plan
terraform apply
```

### 5. Upload Training Data

Upload your training data to the configured S3 bucket:

```bash
aws s3 cp your-dataset.parquet s3://mlflow-staging-mlflow-artifacts-zali-staging/datasets/training/
```

### 6. Test Pipeline Execution

```bash
# Generate parameters for manual testing
python scripts/generate_params_json.py --pipeline-type training --environment staging

# Execute training pipeline manually
aws sagemaker start-pipeline-execution \
  --pipeline-name ml-platform-staging-training \
  --cli-input-json file://parameters/training-staging-*.json
```

## 🔧 Configuration

### Training Pipeline

The training pipeline is configured via `terraform.tfvars`:

```hcl
# Training configuration
training_instance_type = "ml.m5.large"
training_schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
training_hyperparameters = {
  n_estimators = "100"
  max_depth = "10"
  model_name = "staging-classifier"
  experiment_name = "staging-experiments"
}
```

### Inference Pipeline

The inference pipeline processes data daily and sends predictions to Kafka:

```hcl
# Inference configuration
inference_instance_type = "ml.m5.large"
inference_schedule_expression = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
kafka_output_topic = "ml-predictions-staging"
kafka_bootstrap_servers = "your-kafka-cluster.amazonaws.com:9092"
```

## 🐍 Development

### Training Application

The training application (`src/training/`) includes:

- **MLflow Integration**: Automatic experiment tracking and model registration
- **Data Validation**: Comprehensive input data validation and preprocessing
- **Error Handling**: Robust error handling with detailed logging
- **Artifact Management**: Feature importance, metrics, and model artifacts

### Inference Application

The inference application (`src/inference/`) includes:

- **Model Loading**: Automatic MLflow model loading by stage or version
- **Batch Processing**: Configurable batch sizes for large datasets
- **Kafka Integration**: Reliable message publishing with retries
- **Monitoring**: Comprehensive metrics and health checks

### Local Development

```bash
# Install dependencies for training
cd src/training
uv pip install -e .

# Install dependencies for inference
cd src/inference
uv pip install -e .

# Run tests
pytest tests/

# Code formatting
black app/
isort app/
flake8 app/
```

## 🔄 CI/CD Workflow

1. **Code Changes**: Push to feature branch
2. **Build Images**: `./scripts/build_push_ecr.sh` in CI
3. **Update Configuration**: Auto-update `terraform.tfvars` with new image URIs
4. **Deploy**: `terraform apply` in CD pipeline
5. **Test**: Execute pipeline with test data
6. **Monitor**: Check CloudWatch logs and MLflow experiments

## 📊 Monitoring

### CloudWatch Logs

- Training logs: `/aws/sagemaker/TrainingJobs`
- Inference logs: `/aws/sagemaker/ProcessingJobs`
- EventBridge logs: `/aws/events/rule/{rule-name}`

### MLflow Tracking

- Experiments: Check MLflow UI for training runs
- Models: Monitor registered models and their versions
- Metrics: Track accuracy, precision, recall across runs

### Kafka Monitoring

- Message throughput: Monitor Kafka topic metrics
- Consumer lag: Check downstream consumer performance
- Error rates: Monitor failed message deliveries

## 🔒 Security

- **IAM Roles**: Principle of least privilege for each service
- **VPC**: Network isolation for SageMaker jobs
- **Encryption**: Data encrypted in transit and at rest
- **Container Security**: Non-root users and minimal base images

## 🌍 Multi-Environment Support

The project supports multiple environments:

- **Staging**: `terraform/staging/` - For development and testing
- **Production**: `terraform/prod/` - For production workloads

Each environment has its own:
- Terraform configuration
- Container image tags
- MLflow tracking server
- Kafka topics
- S3 buckets

## 🆘 Troubleshooting

### Common Issues

1. **ECR Push Fails**: Ensure AWS CLI is configured and Docker is running
2. **Terraform Apply Fails**: Check IAM permissions and resource limits
3. **Training Job Fails**: Check CloudWatch logs and data format
4. **Kafka Connection Fails**: Verify bootstrap servers and security settings

### Debug Commands

```bash
# Check ECR repositories
aws ecr describe-repositories --region us-east-1

# View SageMaker pipeline executions
aws sagemaker list-pipeline-executions --pipeline-name ml-platform-staging-training

# Check EventBridge rules
aws events list-rules --name-prefix ml-platform

# Test Kafka connectivity
python -c "from src.inference.app.kafka_io import KafkaHealthChecker; print(KafkaHealthChecker.check_connectivity('your-servers'))"
```

## 📚 Additional Resources

- [SageMaker Pipelines Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/pipelines.html)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [Confluent Kafka Python Client](https://docs.confluent.io/kafka-clients/python/current/overview.html)
- [uv Documentation](https://github.com/astral-sh/uv)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test locally
4. Update documentation
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details.
