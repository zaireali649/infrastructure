import json
import os
import boto3
import logging
from datetime import datetime

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SageMaker client
sagemaker = boto3.client('sagemaker')

def handler(event, context):
    """
    Default Lambda function to launch SageMaker training jobs from EventBridge schedule.
    
    This function reads configuration from environment variables and creates a training job
    with MLflow integration for experiment tracking and model registration.
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Generate unique training job name with timestamp
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        training_job_name_prefix = os.environ.get('TRAINING_JOB_NAME_PREFIX', 'ml-training')
        training_job_name = f"{training_job_name_prefix}-{timestamp}"
        
        # Basic training job configuration from environment variables
        training_config = {
            'TrainingJobName': training_job_name,
            'RoleArn': os.environ['TRAINING_ROLE_ARN'],
            'AlgorithmSpecification': {
                'TrainingImage': os.environ['TRAINING_IMAGE'],
                'TrainingInputMode': os.environ.get('TRAINING_INPUT_MODE', 'File')
            },
            'OutputDataConfig': {
                'S3OutputPath': os.environ['OUTPUT_DATA_S3_PATH']
            },
            'ResourceConfig': {
                'InstanceType': os.environ.get('INSTANCE_TYPE', 'ml.m5.large'),
                'InstanceCount': int(os.environ.get('INSTANCE_COUNT', '1')),
                'VolumeSizeInGB': int(os.environ.get('VOLUME_SIZE_GB', '30'))
            },
            'StoppingCondition': {
                'MaxRuntimeInSeconds': int(os.environ.get('MAX_RUNTIME_SECONDS', '3600'))
            }
        }
        
        # Add input data configuration if provided
        input_data_config_str = os.environ.get('INPUT_DATA_CONFIG')
        if input_data_config_str:
            try:
                input_data_config = json.loads(input_data_config_str)
                if input_data_config:
                    training_config['InputDataConfig'] = input_data_config
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse INPUT_DATA_CONFIG: {e}")
        
        # Add hyperparameters if provided
        hyperparameters_str = os.environ.get('HYPERPARAMETERS')
        if hyperparameters_str:
            try:
                hyperparameters = json.loads(hyperparameters_str)
                if hyperparameters:
                    training_config['HyperParameters'] = hyperparameters
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse HYPERPARAMETERS: {e}")
        
        # Add environment variables if provided
        environment_variables_str = os.environ.get('ENVIRONMENT_VARIABLES')
        if environment_variables_str:
            try:
                environment_variables = json.loads(environment_variables_str)
                if environment_variables:
                    training_config['Environment'] = environment_variables
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse ENVIRONMENT_VARIABLES: {e}")
        
        # Add tags for tracking
        training_config['Tags'] = [
            {'Key': 'Project', 'Value': os.environ.get('PROJECT_NAME', 'ml-platform')},
            {'Key': 'Environment', 'Value': os.environ.get('ENVIRONMENT', 'staging')},
            {'Key': 'LaunchedBy', 'Value': 'lambda-scheduler'},
            {'Key': 'LaunchTime', 'Value': timestamp},
            {'Key': 'ManagedBy', 'Value': 'terraform'}
        ]
        
        logger.info(f"Creating training job with config: {json.dumps(training_config, indent=2)}")
        
        # Create the training job
        response = sagemaker.create_training_job(**training_config)
        
        logger.info(f"Successfully created training job: {training_job_name}")
        logger.info(f"Training job ARN: {response['TrainingJobArn']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Training job created successfully',
                'trainingJobName': training_job_name,
                'trainingJobArn': response['TrainingJobArn'],
                'timestamp': timestamp
            })
        }
        
    except Exception as e:
        logger.error(f"Error creating training job: {str(e)}")
        
        # Return error response
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to create training job',
                'timestamp': datetime.now().isoformat()
            })
        }
