"""
Utility functions for the training pipeline
"""

import os
import logging
import json
from pathlib import Path
from typing import Dict, Any, Optional
import pandas as pd
import numpy as np
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.ensemble import RandomForestClassifier

def setup_logging(level: str = None) -> None:
    """Setup logging configuration"""
    log_level = level or os.environ.get('LOG_LEVEL', 'INFO')
    
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('/opt/ml/output/training.log') if os.path.exists('/opt/ml/output') else logging.NullHandler()
        ]
    )

def load_config(config_path: str = '/opt/ml/input/config/hyperparameters.json') -> Dict[str, Any]:
    """Load configuration from SageMaker or local file"""
    try:
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                return json.load(f)
        return {}
    except Exception as e:
        logging.warning(f"Could not load config from {config_path}: {e}")
        return {}

def save_artifacts(model: RandomForestClassifier, X_test: pd.DataFrame, y_test: pd.Series, 
                  y_pred: np.ndarray, output_dir: str) -> None:
    """Save training artifacts for analysis"""
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    try:
        # Feature importance
        if hasattr(model, 'feature_importances_'):
            feature_names = X_test.columns if hasattr(X_test, 'columns') else [f'feature_{i}' for i in range(X_test.shape[1])]
            feature_importance = pd.DataFrame({
                'feature': feature_names,
                'importance': model.feature_importances_
            }).sort_values('importance', ascending=False)
            
            feature_importance.to_csv(output_path / 'feature_importance.csv', index=False)
        
        # Classification report
        if len(np.unique(y_test)) > 1:
            report = classification_report(y_test, y_pred, output_dict=True)
            with open(output_path / 'classification_report.json', 'w') as f:
                json.dump(report, f, indent=2)
        
        # Confusion matrix
        if len(np.unique(y_test)) > 1:
            cm = confusion_matrix(y_test, y_pred)
            cm_df = pd.DataFrame(cm)
            cm_df.to_csv(output_path / 'confusion_matrix.csv', index=False)
        
        # Model summary
        model_summary = {
            'model_type': type(model).__name__,
            'n_features': X_test.shape[1],
            'n_samples_test': X_test.shape[0],
            'n_classes': len(np.unique(y_test)),
            'accuracy': float(np.mean(y_pred == y_test))
        }
        
        if hasattr(model, 'n_estimators'):
            model_summary['n_estimators'] = model.n_estimators
        if hasattr(model, 'max_depth'):
            model_summary['max_depth'] = model.max_depth
        
        with open(output_path / 'model_summary.json', 'w') as f:
            json.dump(model_summary, f, indent=2)
            
        logging.info(f"Artifacts saved to {output_dir}")
        
    except Exception as e:
        logging.error(f"Failed to save artifacts: {e}")

def validate_data_quality(df: pd.DataFrame) -> Dict[str, Any]:
    """Validate data quality and return metrics"""
    quality_metrics = {
        'shape': df.shape,
        'missing_values': df.isnull().sum().to_dict(),
        'duplicate_rows': df.duplicated().sum(),
        'data_types': df.dtypes.astype(str).to_dict(),
        'memory_usage_mb': df.memory_usage(deep=True).sum() / 1024 / 1024
    }
    
    # Numeric columns statistics
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    if len(numeric_cols) > 0:
        quality_metrics['numeric_stats'] = df[numeric_cols].describe().to_dict()
    
    # Categorical columns statistics
    categorical_cols = df.select_dtypes(include=['object', 'category']).columns
    if len(categorical_cols) > 0:
        quality_metrics['categorical_stats'] = {}
        for col in categorical_cols:
            quality_metrics['categorical_stats'][col] = {
                'unique_values': df[col].nunique(),
                'most_frequent': df[col].mode().iloc[0] if not df[col].empty else None
            }
    
    return quality_metrics

def detect_data_drift(current_data: pd.DataFrame, reference_stats: Optional[Dict] = None) -> Dict[str, Any]:
    """Detect potential data drift (placeholder implementation)"""
    # This is a simplified version - in production you'd use more sophisticated drift detection
    drift_metrics = {
        'timestamp': pd.Timestamp.now().isoformat(),
        'current_shape': current_data.shape,
        'drift_detected': False  # Placeholder
    }
    
    if reference_stats:
        # Compare current data with reference statistics
        current_stats = validate_data_quality(current_data)
        
        # Simple checks
        if current_stats['shape'] != reference_stats.get('shape'):
            drift_metrics['drift_detected'] = True
            drift_metrics['shape_drift'] = True
    
    return drift_metrics
