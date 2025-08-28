"""
Kafka Integration for ML Predictions
Handles sending predictions to Kafka topics using confluent-kafka with Secrets Manager support
"""

import os
import json
import logging
import boto3
from typing import Any, Dict, Optional
from datetime import datetime
from confluent_kafka import Producer, KafkaError, KafkaException
import time

logger = logging.getLogger(__name__)

def get_kafka_credentials(secret_arn: Optional[str] = None) -> Dict[str, str]:
    """Get Kafka credentials from AWS Secrets Manager"""
    if not secret_arn:
        logger.info("No Kafka secret ARN provided, using IAM authentication")
        return {}
    
    try:
        secrets_client = boto3.client('secretsmanager')
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        
        if 'SecretString' in response:
            secret = json.loads(response['SecretString'])
            logger.info("Successfully retrieved Kafka credentials from Secrets Manager")
            return {
                'username': secret.get('username', ''),
                'password': secret.get('password', ''),
                'ssl_ca_location': secret.get('ssl_ca_location', '/etc/ssl/certs/ca-certificates.crt')
            }
        else:
            logger.warning("Secret does not contain SecretString")
            return {}
            
    except Exception as e:
        logger.error(f"Failed to retrieve Kafka credentials from Secrets Manager: {e}")
        return {}

class KafkaProducer:
    """Kafka producer for sending ML predictions with MSK and external Kafka support"""
    
    def __init__(self, bootstrap_servers: str, topic: str, timeout: int = 30, 
                 credentials: Optional[Dict[str, str]] = None):
        """
        Initialize Kafka producer
        
        Args:
            bootstrap_servers: Kafka bootstrap servers
            topic: Default Kafka topic
            timeout: Producer timeout in seconds
            credentials: Optional credentials from Secrets Manager
        """
        self.bootstrap_servers = bootstrap_servers
        self.topic = topic
        self.timeout = timeout
        self.credentials = credentials or {}
        self.producer = None
        self.message_count = 0
        
        # Initialize producer
        self._setup_producer()
    
    def _setup_producer(self) -> None:
        """Setup Kafka producer with configuration for MSK and external Kafka"""
        try:
            # Base Kafka configuration
            config = {
                'bootstrap.servers': self.bootstrap_servers,
                'client.id': f"ml-inference-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
                'acks': 'all',  # Wait for all replicas to acknowledge
                'retries': 3,
                'retry.backoff.ms': 1000,
                'request.timeout.ms': self.timeout * 1000,
                'message.timeout.ms': self.timeout * 1000,
                'batch.size': 16384,
                'linger.ms': 10,  # Wait up to 10ms to batch messages
                'compression.type': 'gzip'
            }
            
            # Configure authentication based on available credentials
            if self.credentials and 'username' in self.credentials:
                # External Kafka with SASL authentication
                config.update({
                    'security.protocol': 'SASL_SSL',
                    'sasl.mechanism': 'PLAIN',
                    'sasl.username': self.credentials['username'],
                    'sasl.password': self.credentials['password']
                })
                
                if 'ssl_ca_location' in self.credentials:
                    config['ssl.ca.location'] = self.credentials['ssl_ca_location']
                
                logger.info("Using SASL_SSL authentication for external Kafka")
                
            elif 'amazonaws.com' in self.bootstrap_servers:
                # AWS MSK with IAM authentication
                config.update({
                    'security.protocol': 'SASL_SSL',
                    'sasl.mechanism': 'AWS_MSK_IAM',
                    'sasl.oauth.token.endpoint.url': 'https://sts.amazonaws.com/',
                    'sasl.oauth.method': 'aws-iam',
                    'ssl.ca.location': '/etc/ssl/certs/ca-certificates.crt'
                })
                
                logger.info("Using AWS MSK IAM authentication")
                
            else:
                # Default to PLAINTEXT for local development
                config['security.protocol'] = 'PLAINTEXT'
                logger.info("Using PLAINTEXT authentication")
            
            self.producer = Producer(config)
            logger.info(f"Kafka producer initialized for topic: {self.topic}")
            logger.info(f"Bootstrap servers: {self.bootstrap_servers}")
            logger.info(f"Security protocol: {config['security.protocol']}")
            
        except Exception as e:
            logger.error(f"Failed to setup Kafka producer: {e}")
            raise
    
    def _delivery_callback(self, err: Optional[KafkaError], msg) -> None:
        """Callback for message delivery confirmation"""
        if err is not None:
            logger.error(f"Message delivery failed: {err}")
        else:
            logger.debug(f"Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}")
    
    def send_message(self, message: Dict[str, Any], topic: Optional[str] = None, 
                    key: Optional[str] = None) -> None:
        """
        Send a message to Kafka topic
        
        Args:
            message: Message payload (will be JSON serialized)
            topic: Kafka topic (uses default if None)
            key: Message key for partitioning
        """
        if self.producer is None:
            raise ValueError("Kafka producer not initialized")
        
        target_topic = topic or self.topic
        
        try:
            # Serialize message to JSON
            message_json = json.dumps(message, default=self._json_serializer)
            
            # Send message
            self.producer.produce(
                topic=target_topic,
                value=message_json.encode('utf-8'),
                key=key.encode('utf-8') if key else None,
                callback=self._delivery_callback
            )
            
            self.message_count += 1
            
            # Poll for delivery callbacks
            self.producer.poll(0)
            
        except Exception as e:
            logger.error(f"Failed to send message to {target_topic}: {e}")
            raise
    
    def send_batch(self, messages: list, topic: Optional[str] = None) -> int:
        """
        Send a batch of messages to Kafka
        
        Args:
            messages: List of message dictionaries
            topic: Kafka topic (uses default if None)
            
        Returns:
            Number of successfully sent messages
        """
        if self.producer is None:
            raise ValueError("Kafka producer not initialized")
        
        target_topic = topic or self.topic
        success_count = 0
        
        try:
            for i, message in enumerate(messages):
                try:
                    # Add batch metadata
                    enriched_message = {
                        **message,
                        'batch_index': i,
                        'batch_size': len(messages),
                        'batch_timestamp': datetime.utcnow().isoformat()
                    }
                    
                    self.send_message(
                        enriched_message, 
                        topic=target_topic,
                        key=f"batch_{i}"
                    )
                    success_count += 1
                    
                except Exception as e:
                    logger.error(f"Failed to send message {i} in batch: {e}")
            
            # Flush to ensure all messages are sent
            self.flush()
            
            logger.info(f"Batch send completed: {success_count}/{len(messages)} messages sent")
            return success_count
            
        except Exception as e:
            logger.error(f"Batch send failed: {e}")
            raise
    
    def flush(self, timeout: Optional[float] = None) -> None:
        """Flush producer to ensure all messages are sent"""
        if self.producer is None:
            return
        
        flush_timeout = timeout or self.timeout
        
        try:
            remaining = self.producer.flush(timeout=flush_timeout)
            if remaining > 0:
                logger.warning(f"{remaining} messages not delivered after flush")
            else:
                logger.debug("All messages flushed successfully")
                
        except Exception as e:
            logger.error(f"Producer flush failed: {e}")
    
    def close(self) -> None:
        """Close the Kafka producer"""
        if self.producer is not None:
            try:
                # Flush remaining messages
                self.flush()
                logger.info(f"Kafka producer closed. Total messages sent: {self.message_count}")
            except Exception as e:
                logger.error(f"Error during producer close: {e}")
            finally:
                self.producer = None
    
    @staticmethod
    def _json_serializer(obj) -> str:
        """Custom JSON serializer for special types"""
        if hasattr(obj, 'isoformat'):  # datetime objects
            return obj.isoformat()
        elif hasattr(obj, 'item'):  # numpy types
            return obj.item()
        elif hasattr(obj, 'tolist'):  # numpy arrays
            return obj.tolist()
        else:
            return str(obj)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get producer statistics"""
        if self.producer is None:
            return {}
        
        try:
            # Get producer statistics (returns JSON string)
            stats_json = self.producer.list_topics(timeout=1)
            return {
                'message_count': self.message_count,
                'topic': self.topic,
                'is_connected': True,
                'available_topics': list(stats_json.topics.keys()) if stats_json else []
            }
        except Exception as e:
            logger.warning(f"Could not get producer stats: {e}")
            return {
                'message_count': self.message_count,
                'topic': self.topic,
                'is_connected': False,
                'error': str(e)
            }

class KafkaHealthChecker:
    """Health checker for Kafka connectivity"""
    
    @staticmethod
    def check_connectivity(bootstrap_servers: str, timeout: int = 10) -> bool:
        """Check if Kafka cluster is accessible"""
        try:
            config = {
                'bootstrap.servers': bootstrap_servers,
                'request.timeout.ms': timeout * 1000
            }
            
            producer = Producer(config)
            
            # Try to get cluster metadata
            metadata = producer.list_topics(timeout=timeout)
            
            if metadata and metadata.topics:
                logger.info(f"Kafka connectivity check passed. Available topics: {len(metadata.topics)}")
                return True
            else:
                logger.warning("Kafka connectivity check: No topics found")
                return False
                
        except Exception as e:
            logger.error(f"Kafka connectivity check failed: {e}")
            return False
    
    @staticmethod
    def check_topic_exists(bootstrap_servers: str, topic: str, timeout: int = 10) -> bool:
        """Check if a specific topic exists"""
        try:
            config = {
                'bootstrap.servers': bootstrap_servers,
                'request.timeout.ms': timeout * 1000
            }
            
            producer = Producer(config)
            metadata = producer.list_topics(topic=topic, timeout=timeout)
            
            return topic in metadata.topics
            
        except Exception as e:
            logger.error(f"Topic existence check failed for {topic}: {e}")
            return False

# Utility function for simple message sending
def send_prediction_to_kafka(prediction_data: Dict[str, Any], topic: str, 
                           bootstrap_servers: str) -> bool:
    """
    Utility function to send a single prediction to Kafka
    
    Args:
        prediction_data: Prediction data dictionary
        topic: Kafka topic
        bootstrap_servers: Kafka bootstrap servers
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Temporarily set environment variable
        original_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS')
        os.environ['KAFKA_BOOTSTRAP_SERVERS'] = bootstrap_servers
        
        producer = KafkaProducer(topic=topic, timeout=10)
        producer.send_message(prediction_data)
        producer.close()
        
        # Restore original environment
        if original_servers:
            os.environ['KAFKA_BOOTSTRAP_SERVERS'] = original_servers
        else:
            os.environ.pop('KAFKA_BOOTSTRAP_SERVERS', None)
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to send prediction to Kafka: {e}")
        return False
