"""
Base Model Class for all ML models
"""
import pickle
import json
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any, Dict, Optional
import numpy as np
from config import MODELS_DIR


class BaseModel(ABC):
    """Abstract base class for all ML models"""
    
    def __init__(self, name: str, **kwargs):
        self.name = name
        self.model = None
        self.is_trained = False
        self.metadata = {
            "name": name,
            "parameters": kwargs,
            "metrics": {}
        }
    
    @abstractmethod
    def build(self, **kwargs):
        """Build the model architecture"""
        pass
    
    @abstractmethod
    def train(self, X_train: np.ndarray, y_train: np.ndarray, **kwargs):
        """Train the model"""
        pass
    
    @abstractmethod
    def predict(self, X: np.ndarray) -> np.ndarray:
        """Make predictions"""
        pass
    
    @abstractmethod
    def evaluate(self, X_test: np.ndarray, y_test: np.ndarray) -> Dict[str, float]:
        """Evaluate model performance"""
        pass
    
    def save(self, filepath: Optional[Path] = None):
        """Save model to disk"""
        if filepath is None:
            filepath = MODELS_DIR / f"{self.name}.pkl"
        
        filepath = Path(filepath)
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'wb') as f:
            pickle.dump(self.model, f)
        
        # Save metadata
        metadata_path = filepath.with_suffix('.json')
        with open(metadata_path, 'w') as f:
            json.dump(self.metadata, f, indent=2)
        
        print(f"Model saved to {filepath}")
    
    def load(self, filepath: Path):
        """Load model from disk"""
        filepath = Path(filepath)
        
        with open(filepath, 'rb') as f:
            self.model = pickle.load(f)
        
        # Load metadata
        metadata_path = filepath.with_suffix('.json')
        if metadata_path.exists():
            with open(metadata_path, 'r') as f:
                self.metadata = json.load(f)
        
        self.is_trained = True
        print(f"Model loaded from {filepath}")
    
    def get_params(self) -> Dict[str, Any]:
        """Get model parameters"""
        return self.metadata.get("parameters", {})
    
    def set_params(self, **params):
        """Set model parameters"""
        self.metadata["parameters"].update(params)
