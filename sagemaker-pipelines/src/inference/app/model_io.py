"""
MLflow Model Loading and Management
Handles loading MLflow models for inference
"""

import os
import logging
from typing import Optional, List, Any, Dict
import pandas as pd
import numpy as np
import mlflow
import mlflow.sklearn
from mlflow.tracking import MlflowClient

logger = logging.getLogger(__name__)

class MLflowModelLoader:
    """Load and manage MLflow models for inference"""
    
    def __init__(self, model_name: str, model_stage: str = "Production", 
                 model_version: Optional[str] = None):
        """
        Initialize MLflow model loader
        
        Args:
            model_name: Name of the registered model in MLflow
            model_stage: Model stage (Production, Staging, etc.)
            model_version: Specific version (overrides stage)
        """
        self.model_name = model_name
        self.model_stage = model_stage
        self.model_version = model_version
        self.model = None
        self.model_info = None
        self.client = None
        
        # Setup MLflow
        self._setup_mlflow()
    
    def _setup_mlflow(self) -> None:
        """Setup MLflow client and tracking URI"""
        try:
            tracking_uri = os.environ.get('MLFLOW_TRACKING_URI')
            if tracking_uri:
                mlflow.set_tracking_uri(tracking_uri)
                logger.info(f"MLflow tracking URI: {tracking_uri}")
            
            self.client = MlflowClient()
            
        except Exception as e:
            logger.error(f"MLflow setup failed: {e}")
            raise
    
    def load_model(self) -> None:
        """Load the MLflow model"""
        try:
            if self.model_version:
                # Load specific version
                model_uri = f"models:/{self.model_name}/{self.model_version}"
                logger.info(f"Loading model version {self.model_version}")
            else:
                # Load by stage
                model_uri = f"models:/{self.model_name}/{self.model_stage}"
                logger.info(f"Loading model stage {self.model_stage}")
            
            # Load the model
            self.model = mlflow.sklearn.load_model(model_uri)
            
            # Get model metadata
            self.model_info = self.client.get_latest_versions(
                self.model_name, 
                stages=[self.model_stage] if not self.model_version else None
            )
            
            if self.model_version:
                # Get specific version info
                self.model_info = [self.client.get_model_version(self.model_name, self.model_version)]
            
            logger.info(f"Successfully loaded model: {self.model_name}")
            logger.info(f"Model type: {type(self.model).__name__}")
            
        except Exception as e:
            logger.error(f"Failed to load model {self.model_name}: {e}")
            raise
    
    def predict(self, data: pd.DataFrame) -> np.ndarray:
        """Generate predictions"""
        if self.model is None:
            raise ValueError("Model not loaded. Call load_model() first.")
        
        try:
            predictions = self.model.predict(data)
            logger.debug(f"Generated {len(predictions)} predictions")
            return predictions
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            raise
    
    def predict_proba(self, data: pd.DataFrame) -> Optional[np.ndarray]:
        """Generate prediction probabilities if supported"""
        if self.model is None:
            raise ValueError("Model not loaded. Call load_model() first.")
        
        try:
            if hasattr(self.model, 'predict_proba'):
                probabilities = self.model.predict_proba(data)
                logger.debug(f"Generated probabilities for {len(data)} samples")
                return probabilities
            else:
                logger.warning("Model does not support probability predictions")
                return None
                
        except Exception as e:
            logger.error(f"Probability prediction failed: {e}")
            return None
    
    def get_model_version(self) -> str:
        """Get the loaded model version"""
        if self.model_info:
            return self.model_info[0].version
        return "unknown"
    
    def get_model_stage(self) -> str:
        """Get the loaded model stage"""
        if self.model_info:
            return self.model_info[0].current_stage
        return "unknown"
    
    def get_model_metadata(self) -> Dict[str, Any]:
        """Get model metadata"""
        if not self.model_info:
            return {}
        
        model_version = self.model_info[0]
        return {
            'name': model_version.name,
            'version': model_version.version,
            'stage': model_version.current_stage,
            'creation_timestamp': model_version.creation_timestamp,
            'last_updated_timestamp': model_version.last_updated_timestamp,
            'description': model_version.description,
            'tags': dict(model_version.tags) if model_version.tags else {}
        }
    
    def get_expected_features(self) -> Optional[List[str]]:
        """Get expected feature names from model metadata"""
        try:
            if not self.model_info:
                return None
            
            # Try to get feature names from model signature
            model_version = self.model_info[0]
            run_id = model_version.run_id
            
            if run_id:
                run = self.client.get_run(run_id)
                
                # Look for feature names in tags or artifacts
                if 'feature_names' in run.data.tags:
                    feature_names = run.data.tags['feature_names'].split(',')
                    return [name.strip() for name in feature_names]
                
                # Try to get from model signature
                model_uri = f"models:/{self.model_name}/{model_version.version}"
                model_info = mlflow.models.get_model_info(model_uri)
                
                if model_info.signature and model_info.signature.inputs:
                    schema = model_info.signature.inputs
                    if hasattr(schema, 'input_names'):
                        return schema.input_names()
            
            return None
            
        except Exception as e:
            logger.warning(f"Could not retrieve expected features: {e}")
            return None
    
    def get_class_names(self) -> Optional[List[str]]:
        """Get class names for classification models"""
        try:
            if hasattr(self.model, 'classes_'):
                return self.model.classes_.tolist()
            return None
            
        except Exception as e:
            logger.warning(f"Could not retrieve class names: {e}")
            return None
    
    def validate_input_data(self, data: pd.DataFrame) -> bool:
        """Validate input data against model expectations"""
        try:
            expected_features = self.get_expected_features()
            
            if expected_features:
                missing_features = set(expected_features) - set(data.columns)
                extra_features = set(data.columns) - set(expected_features)
                
                if missing_features:
                    logger.warning(f"Missing expected features: {missing_features}")
                
                if extra_features:
                    logger.info(f"Extra features (will be ignored): {extra_features}")
                
                return len(missing_features) == 0
            
            # If no expected features available, assume valid
            return True
            
        except Exception as e:
            logger.error(f"Input validation failed: {e}")
            return False

class ModelRegistry:
    """Manage multiple models and model registry operations"""
    
    def __init__(self):
        self.client = MlflowClient()
        self.loaded_models = {}
    
    def list_models(self) -> List[Dict[str, Any]]:
        """List all registered models"""
        try:
            models = self.client.search_registered_models()
            return [
                {
                    'name': model.name,
                    'creation_timestamp': model.creation_timestamp,
                    'last_updated_timestamp': model.last_updated_timestamp,
                    'description': model.description,
                    'tags': dict(model.tags) if model.tags else {}
                }
                for model in models
            ]
        except Exception as e:
            logger.error(f"Failed to list models: {e}")
            return []
    
    def get_model_versions(self, model_name: str) -> List[Dict[str, Any]]:
        """Get all versions of a specific model"""
        try:
            versions = self.client.search_model_versions(f"name='{model_name}'")
            return [
                {
                    'version': version.version,
                    'stage': version.current_stage,
                    'creation_timestamp': version.creation_timestamp,
                    'last_updated_timestamp': version.last_updated_timestamp,
                    'description': version.description,
                    'run_id': version.run_id
                }
                for version in versions
            ]
        except Exception as e:
            logger.error(f"Failed to get model versions for {model_name}: {e}")
            return []
    
    def load_model(self, model_name: str, stage: str = "Production") -> MLflowModelLoader:
        """Load a model and cache it"""
        cache_key = f"{model_name}_{stage}"
        
        if cache_key not in self.loaded_models:
            loader = MLflowModelLoader(model_name, stage)
            loader.load_model()
            self.loaded_models[cache_key] = loader
        
        return self.loaded_models[cache_key]
