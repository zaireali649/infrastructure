#!/usr/bin/env python3
"""
Task automation for SageMaker Pipelines development workflow
Provides common development tasks for building, testing, and deploying ML pipelines
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path
from typing import List, Optional
import json
import time

def run_command(cmd: List[str], cwd: Optional[str] = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command with proper error handling"""
    print(f"Running: {' '.join(cmd)}")
    if cwd:
        print(f"Working directory: {cwd}")
    
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=False)
    
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    
    if check and result.returncode != 0:
        sys.exit(result.returncode)
    
    return result

def setup_project():
    """Setup the project by installing dependencies and creating lock files"""
    print("Setting up project dependencies...")
    
    # Setup training dependencies
    print("\nSetting up training dependencies...")
    run_command(["uv", "sync"], cwd="src/training")
    
    # Setup inference dependencies
    print("\nSetting up inference dependencies...")
    run_command(["uv", "sync"], cwd="src/inference")
    
    print("✅ Project setup complete!")

def lint_code():
    """Run linting on all Python code"""
    print("Running code linting...")
    
    # Training code
    print("\nLinting training code...")
    run_command(["uv", "run", "black", "app/"], cwd="src/training", check=False)
    run_command(["uv", "run", "isort", "app/"], cwd="src/training", check=False)
    run_command(["uv", "run", "flake8", "app/"], cwd="src/training", check=False)
    
    # Inference code
    print("\nLinting inference code...")
    run_command(["uv", "run", "black", "app/"], cwd="src/inference", check=False)
    run_command(["uv", "run", "isort", "app/"], cwd="src/inference", check=False)
    run_command(["uv", "run", "flake8", "app/"], cwd="src/inference", check=False)
    
    print("✅ Code linting complete!")

def test_code():
    """Run tests for the applications"""
    print("Running tests...")
    
    # Training tests
    print("\nTesting training code...")
    run_command(["uv", "run", "pytest", "tests/", "-v"], cwd="src/training", check=False)
    
    # Inference tests
    print("\nTesting inference code...")
    run_command(["uv", "run", "pytest", "tests/", "-v"], cwd="src/inference", check=False)
    
    print("✅ Tests complete!")

def build_images(service: Optional[str] = None):
    """Build Docker images for the services"""
    print("Building Docker images...")
    
    services = ["training", "inference"] if service is None else [service]
    
    for svc in services:
        print(f"\nBuilding {svc} image...")
        image_tag = f"ml-platform-{svc}:dev"
        
        run_command([
            "docker", "build",
            "-t", image_tag,
            "-f", "Dockerfile",
            "."
        ], cwd=f"src/{svc}")
        
        print(f"✅ Built {image_tag}")
    
    print("✅ Docker images built successfully!")

def push_images(environment: str = "staging"):
    """Push images to ECR"""
    print(f"Pushing images to ECR for {environment}...")
    
    # Use the build script
    run_command(["./scripts/build_push_ecr.sh"], cwd=".")
    
    print("✅ Images pushed to ECR!")

def deploy_infrastructure(environment: str = "staging", auto_approve: bool = False):
    """Deploy infrastructure using Terraform"""
    print(f"Deploying infrastructure to {environment}...")
    
    terraform_dir = f"terraform/{environment}"
    
    # Initialize Terraform
    run_command(["terraform", "init"], cwd=terraform_dir)
    
    # Plan deployment
    run_command(["terraform", "plan"], cwd=terraform_dir)
    
    # Apply if auto-approve is set
    if auto_approve:
        run_command(["terraform", "apply", "-auto-approve"], cwd=terraform_dir)
    else:
        print(f"\nTo apply changes, run: cd {terraform_dir} && terraform apply")
    
    print("✅ Infrastructure deployment planned!")

def trigger_pipeline(pipeline_type: str, environment: str = "staging"):
    """Trigger a SageMaker pipeline execution"""
    print(f"Triggering {pipeline_type} pipeline in {environment}...")
    
    # Generate parameters
    run_command([
        "python", "scripts/generate_params_json.py",
        "--pipeline-type", pipeline_type,
        "--environment", environment
    ])
    
    print(f"✅ {pipeline_type} pipeline parameters generated!")
    print("Use the generated JSON file with AWS CLI or boto3 to trigger execution")

def monitor_logs(service: str = "training"):
    """Monitor CloudWatch logs for a service"""
    print(f"Monitoring {service} logs...")
    
    log_group = f"/aws/sagemaker/{'TrainingJobs' if service == 'training' else 'ProcessingJobs'}"
    
    print(f"Log group: {log_group}")
    print("Use AWS CLI or CloudWatch console to view logs:")
    print(f"aws logs tail {log_group} --follow")

def cleanup_resources(environment: str = "staging"):
    """Clean up AWS resources"""
    print(f"Cleaning up resources in {environment}...")
    
    terraform_dir = f"terraform/{environment}"
    
    run_command(["terraform", "destroy"], cwd=terraform_dir)
    
    print("✅ Resources cleaned up!")

def validate_config(environment: str = "staging"):
    """Validate Terraform configuration"""
    print(f"Validating {environment} configuration...")
    
    terraform_dir = f"terraform/{environment}"
    
    run_command(["terraform", "init"], cwd=terraform_dir)
    run_command(["terraform", "validate"], cwd=terraform_dir)
    run_command(["terraform", "fmt", "-check"], cwd=terraform_dir)
    
    print("✅ Configuration validation complete!")

def generate_docs():
    """Generate documentation from code"""
    print("Generating documentation...")
    
    # Create docs directory
    docs_dir = Path("docs")
    docs_dir.mkdir(exist_ok=True)
    
    # Generate API documentation for training
    run_command([
        "uv", "run", "python", "-m", "pydoc", "-w", "app"
    ], cwd="src/training", check=False)
    
    # Generate API documentation for inference
    run_command([
        "uv", "run", "python", "-m", "pydoc", "-w", "app"
    ], cwd="src/inference", check=False)
    
    print("✅ Documentation generated!")

def main():
    """Main task runner"""
    parser = argparse.ArgumentParser(description="SageMaker Pipelines Task Runner")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Setup command
    subparsers.add_parser("setup", help="Setup project dependencies")
    
    # Lint command
    subparsers.add_parser("lint", help="Run code linting")
    
    # Test command
    subparsers.add_parser("test", help="Run tests")
    
    # Build command
    build_parser = subparsers.add_parser("build", help="Build Docker images")
    build_parser.add_argument("--service", choices=["training", "inference"], help="Specific service to build")
    
    # Push command
    push_parser = subparsers.add_parser("push", help="Push images to ECR")
    push_parser.add_argument("--environment", default="staging", help="Target environment")
    
    # Deploy command
    deploy_parser = subparsers.add_parser("deploy", help="Deploy infrastructure")
    deploy_parser.add_argument("--environment", default="staging", help="Target environment")
    deploy_parser.add_argument("--auto-approve", action="store_true", help="Auto-approve Terraform changes")
    
    # Trigger command
    trigger_parser = subparsers.add_parser("trigger", help="Trigger pipeline execution")
    trigger_parser.add_argument("pipeline_type", choices=["training", "inference"], help="Pipeline type")
    trigger_parser.add_argument("--environment", default="staging", help="Target environment")
    
    # Monitor command
    monitor_parser = subparsers.add_parser("monitor", help="Monitor service logs")
    monitor_parser.add_argument("--service", default="training", choices=["training", "inference"], help="Service to monitor")
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser("cleanup", help="Clean up resources")
    cleanup_parser.add_argument("--environment", default="staging", help="Target environment")
    
    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate configuration")
    validate_parser.add_argument("--environment", default="staging", help="Target environment")
    
    # Docs command
    subparsers.add_parser("docs", help="Generate documentation")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    try:
        if args.command == "setup":
            setup_project()
        elif args.command == "lint":
            lint_code()
        elif args.command == "test":
            test_code()
        elif args.command == "build":
            build_images(args.service)
        elif args.command == "push":
            push_images(args.environment)
        elif args.command == "deploy":
            deploy_infrastructure(args.environment, args.auto_approve)
        elif args.command == "trigger":
            trigger_pipeline(args.pipeline_type, args.environment)
        elif args.command == "monitor":
            monitor_logs(args.service)
        elif args.command == "cleanup":
            cleanup_resources(args.environment)
        elif args.command == "validate":
            validate_config(args.environment)
        elif args.command == "docs":
            generate_docs()
    except KeyboardInterrupt:
        print("\n❌ Task interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Task failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
