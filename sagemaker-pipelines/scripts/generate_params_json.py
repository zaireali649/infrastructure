#!/usr/bin/env python3
"""
Generate SageMaker Pipeline parameters JSON for EventBridge Scheduler
This script creates parameter files for pipeline execution with dynamic values
"""

import json
import argparse
from datetime import datetime
from typing import Dict, Any
import boto3
from pathlib import Path


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Generate SageMaker Pipeline parameters JSON"
    )

    parser.add_argument(
        "--pipeline-type",
        choices=["training", "inference"],
        required=True,
        help="Type of pipeline to generate parameters for",
    )
    parser.add_argument(
        "--environment",
        default="staging",
        choices=["staging", "prod"],
        help="Environment (staging or prod)",
    )
    parser.add_argument(
        "--output-file", type=str, help="Output file path (default: auto-generated)"
    )
    parser.add_argument("--project-name", default="ml-platform", help="Project name")
    parser.add_argument("--aws-region", default="us-east-1", help="AWS region")

    # Training-specific parameters
    parser.add_argument(
        "--training-data-path",
        type=str,
        help="S3 path for training data (training pipeline only)",
    )
    parser.add_argument(
        "--model-output-path",
        type=str,
        help="S3 path for model output (training pipeline only)",
    )

    # Inference-specific parameters
    parser.add_argument(
        "--inference-input-path",
        type=str,
        help="S3 path for inference input (inference pipeline only)",
    )
    parser.add_argument(
        "--kafka-topic",
        type=str,
        help="Kafka topic for output (inference pipeline only)",
    )

    # Common parameters
    parser.add_argument(
        "--instance-type", default="ml.m5.large", help="SageMaker instance type"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print parameters without writing file"
    )

    return parser.parse_args()


def get_aws_account_id() -> str:
    """Get current AWS account ID"""
    try:
        sts = boto3.client("sts")
        return sts.get_caller_identity()["Account"]
    except Exception as e:
        print(f"Warning: Could not get AWS account ID: {e}")
        return "123456789012"  # Default placeholder


def generate_training_parameters(
    args: argparse.Namespace, account_id: str
) -> Dict[str, Any]:
    """Generate parameters for training pipeline"""
    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")

    # Default S3 paths if not provided
    bucket_name = f"mlflow-{args.environment}-mlflow-artifacts-zali-{args.environment}"
    training_data_path = (
        args.training_data_path or f"s3://{bucket_name}/datasets/training/"
    )
    model_output_path = args.model_output_path or f"s3://{bucket_name}/models/"

    parameters = {
        "TrainingJobName": f"{args.project_name}-{args.environment}-training-{timestamp}",
        "RoleArn": f"arn:aws:iam::{account_id}:role/{args.project_name}-{args.environment}-training-role",
        "AlgorithmSpecification": {
            "TrainingImage": f"{account_id}.dkr.ecr.{args.aws_region}.amazonaws.com/{args.project_name}-{args.environment}-training:latest",
            "TrainingInputMode": "File",
        },
        "InputDataConfig": [
            {
                "ChannelName": "training",
                "DataSource": {
                    "S3DataSource": {
                        "S3DataType": "S3Prefix",
                        "S3Uri": training_data_path,
                        "S3DataDistributionType": "FullyReplicated",
                    }
                },
                "ContentType": "application/x-parquet",
                "InputMode": "File",
            }
        ],
        "OutputDataConfig": {"S3OutputPath": model_output_path},
        "ResourceConfig": {
            "InstanceType": args.instance_type,
            "InstanceCount": 1,
            "VolumeSizeInGB": 30,
        },
        "StoppingCondition": {"MaxRuntimeInSeconds": 3600},
        "HyperParameters": {
            "n_estimators": "100",
            "max_depth": "10",
            "random_state": "42",
            "test_size": "0.2",
            "model_name": f"{args.environment}-classifier",
            "experiment_name": f"{args.environment}-experiments",
        },
        "Environment": {
            "MLFLOW_TRACKING_URI": f"https://mlflow.{args.aws_region}.amazonaws.com/tracking-server/mlflow-{args.environment}-mlflow",
            "AWS_DEFAULT_REGION": args.aws_region,
            "ENVIRONMENT": args.environment,
            "OWNER": "zali",
        },
        "Tags": [
            {"Key": "Project", "Value": args.project_name},
            {"Key": "Environment", "Value": args.environment},
            {"Key": "Type", "Value": "training"},
            {"Key": "ManagedBy", "Value": "eventbridge"},
            {"Key": "Timestamp", "Value": timestamp},
        ],
    }

    return parameters


def generate_inference_parameters(
    args: argparse.Namespace, account_id: str
) -> Dict[str, Any]:
    """Generate parameters for inference pipeline"""
    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")

    # Default S3 paths if not provided
    bucket_name = f"mlflow-{args.environment}-mlflow-artifacts-zali-{args.environment}"
    inference_input_path = (
        args.inference_input_path or f"s3://{bucket_name}/inference/input/"
    )
    inference_output_path = f"s3://{bucket_name}/inference/output/"

    # Default Kafka topic if not provided
    kafka_topic = args.kafka_topic or f"ml-predictions-{args.environment}"

    parameters = {
        "ProcessingJobName": f"{args.project_name}-{args.environment}-inference-{timestamp}",
        "RoleArn": f"arn:aws:iam::{account_id}:role/{args.project_name}-{args.environment}-processing-role",
        "AppSpecification": {
            "ImageUri": f"{account_id}.dkr.ecr.{args.aws_region}.amazonaws.com/{args.project_name}-{args.environment}-inference:latest"
        },
        "ProcessingInputs": [
            {
                "InputName": "input",
                "S3Input": {
                    "S3Uri": inference_input_path,
                    "LocalPath": "/opt/ml/input/data/input",
                    "S3DataType": "S3Prefix",
                    "S3InputMode": "File",
                },
            }
        ],
        "ProcessingOutputConfig": {
            "Outputs": [
                {
                    "OutputName": "output",
                    "S3Output": {
                        "S3Uri": inference_output_path,
                        "LocalPath": "/opt/ml/output",
                        "S3UploadMode": "EndOfJob",
                    },
                }
            ]
        },
        "ProcessingResources": {
            "ClusterConfig": {
                "InstanceType": args.instance_type,
                "InstanceCount": 1,
                "VolumeSizeInGB": 30,
            }
        },
        "StoppingCondition": {
            "MaxRuntimeInSeconds": 1800  # 30 minutes for inference
        },
        "Environment": {
            "KAFKA_TOPIC": kafka_topic,
            "KAFKA_BOOTSTRAP_SERVERS": "your-kafka-cluster.us-east-1.amazonaws.com:9092",
            "KAFKA_SECURITY_PROTOCOL": "SASL_SSL",
            "MLFLOW_TRACKING_URI": f"https://mlflow.{args.aws_region}.amazonaws.com/tracking-server/mlflow-{args.environment}-mlflow",
            "MODEL_NAME": f"{args.environment}-classifier",
            "MODEL_STAGE": "Production",
            "BATCH_SIZE": "1000",
            "AWS_DEFAULT_REGION": args.aws_region,
            "ENVIRONMENT": args.environment,
        },
        "Tags": [
            {"Key": "Project", "Value": args.project_name},
            {"Key": "Environment", "Value": args.environment},
            {"Key": "Type", "Value": "inference"},
            {"Key": "ManagedBy", "Value": "eventbridge"},
            {"Key": "Timestamp", "Value": timestamp},
        ],
    }

    return parameters


def save_parameters(parameters: Dict[str, Any], output_file: str) -> None:
    """Save parameters to JSON file"""
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(parameters, f, indent=2, default=str)

    print(f"Parameters saved to: {output_file}")


def generate_eventbridge_rule_json(
    args: argparse.Namespace, parameters: Dict[str, Any]
) -> Dict[str, Any]:
    """Generate EventBridge rule configuration"""
    schedule_expression = (
        "cron(0 2 * * ? *)" if args.pipeline_type == "training" else "cron(0 6 * * ? *)"
    )

    rule_config = {
        "Name": f"{args.project_name}-{args.environment}-{args.pipeline_type}-schedule",
        "Description": f"Scheduled {args.pipeline_type} pipeline for {args.project_name} {args.environment}",
        "ScheduleExpression": schedule_expression,
        "State": "DISABLED",  # Start disabled for safety
        "Targets": [
            {
                "Id": "1",
                "Arn": f"arn:aws:sagemaker:{args.aws_region}:{get_aws_account_id()}:pipeline/{args.project_name}-{args.environment}-{args.pipeline_type}",
                "RoleArn": f"arn:aws:iam::{get_aws_account_id()}:role/{args.project_name}-{args.environment}-scheduler-role",
                "SageMakerPipelineParameters": {
                    "PipelineParameterList": {
                        k: str(v)
                        for k, v in parameters.items()
                        if isinstance(v, (str, int, float))
                    }
                },
            }
        ],
        "Tags": [
            {"Key": "Project", "Value": args.project_name},
            {"Key": "Environment", "Value": args.environment},
            {"Key": "Type", "Value": args.pipeline_type},
            {"Key": "ManagedBy", "Value": "terraform"},
        ],
    }

    return rule_config


def main():
    """Main function"""
    args = parse_arguments()

    print(f"Generating {args.pipeline_type} pipeline parameters for {args.environment}")

    # Get AWS account ID
    account_id = get_aws_account_id()

    # Generate parameters based on pipeline type
    if args.pipeline_type == "training":
        parameters = generate_training_parameters(args, account_id)
    else:
        parameters = generate_inference_parameters(args, account_id)

    # Generate output filename if not provided
    if not args.output_file:
        timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
        args.output_file = (
            f"parameters/{args.pipeline_type}-{args.environment}-{timestamp}.json"
        )

    # Print or save parameters
    if args.dry_run:
        print("\nGenerated parameters:")
        print(json.dumps(parameters, indent=2, default=str))
    else:
        save_parameters(parameters, args.output_file)

        # Also generate EventBridge rule configuration
        rule_config = generate_eventbridge_rule_json(args, parameters)
        rule_file = args.output_file.replace(".json", "-eventbridge-rule.json")
        save_parameters(rule_config, rule_file)

        print("\nFiles generated:")
        print(f"  Parameters: {args.output_file}")
        print(f"  EventBridge Rule: {rule_file}")

        print("\nTo use these parameters:")
        print("1. Review and customize the generated JSON files")
        print(
            f"2. Use with AWS CLI: aws sagemaker start-pipeline-execution --cli-input-json file://{args.output_file}"
        )
        print("3. Or deploy via Terraform using the rule configuration")


if __name__ == "__main__":
    main()
