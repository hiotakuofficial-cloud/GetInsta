"""
Data Scaling and Normalization utilities
"""
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler, MinMaxScaler, RobustScaler, MaxAbsScaler
from typing import Optional, Union


class DataScaler:
    """Scale and normalize data for ML models"""
    
    def __init__(self, method: str = "standard"):
        """
        Initialize scaler
        
        Args:
            method: 'standard', 'minmax', 'robust', 'maxabs'
        """
        self.method = method
        self.scaler = None
        self._initialize_scaler()
    
    def _initialize_scaler(self):
        """Initialize the appropriate scaler"""
        if self.method == "standard":
            self.scaler = StandardScaler()
        elif self.method == "minmax":
            self.scaler = MinMaxScaler()
        elif self.method == "robust":
            self.scaler = RobustScaler()
        elif self.method == "maxabs":
            self.scaler = MaxAbsScaler()
        else:
            raise ValueError(f"Unknown scaling method: {self.method}")
    
    def fit(self, X: Union[np.ndarray, pd.DataFrame]):
        """Fit the scaler to data"""
        self.scaler.fit(X)
        return self
    
    def transform(self, X: Union[np.ndarray, pd.DataFrame]) -> np.ndarray:
        """Transform data using fitted scaler"""
        if self.scaler is None:
            raise ValueError("Scaler must be fitted before transform")
        return self.scaler.transform(X)
    
    def fit_transform(self, X: Union[np.ndarray, pd.DataFrame]) -> np.ndarray:
        """Fit and transform data"""
        return self.scaler.fit_transform(X)
    
    def inverse_transform(self, X: Union[np.ndarray, pd.DataFrame]) -> np.ndarray:
        """Inverse transform scaled data back to original scale"""
        if self.scaler is None:
            raise ValueError("Scaler must be fitted before inverse_transform")
        return self.scaler.inverse_transform(X)
    
    def get_params(self) -> dict:
        """Get scaler parameters"""
        if self.scaler is None:
            return {}
        
        params = {"method": self.method}
        
        if hasattr(self.scaler, 'mean_'):
            params['mean'] = self.scaler.mean_
        if hasattr(self.scaler, 'scale_'):
            params['scale'] = self.scaler.scale_
        if hasattr(self.scaler, 'min_'):
            params['min'] = self.scaler.min_
        if hasattr(self.scaler, 'data_min_'):
            params['data_min'] = self.scaler.data_min_
        if hasattr(self.scaler, 'data_max_'):
            params['data_max'] = self.scaler.data_max_
        
        return params


def normalize_l2(X: np.ndarray) -> np.ndarray:
    """L2 normalization (unit norm)"""
    norms = np.linalg.norm(X, axis=1, keepdims=True)
    return X / (norms + 1e-8)


def normalize_l1(X: np.ndarray) -> np.ndarray:
    """L1 normalization"""
    norms = np.sum(np.abs(X), axis=1, keepdims=True)
    return X / (norms + 1e-8)


def clip_outliers(X: np.ndarray, lower_percentile: float = 1, 
                 upper_percentile: float = 99) -> np.ndarray:
    """Clip outliers based on percentiles"""
    lower = np.percentile(X, lower_percentile, axis=0)
    upper = np.percentile(X, upper_percentile, axis=0)
    return np.clip(X, lower, upper)
