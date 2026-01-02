"""
Data Loading utilities
"""
import pandas as pd
import numpy as np
from pathlib import Path
from typing import Tuple, Optional, Union
from sklearn.model_selection import train_test_split
from config import RAW_DATA_DIR, PROCESSED_DATA_DIR, MODEL_CONFIG


class DataLoader:
    """Load and split data for ML tasks"""
    
    def __init__(self, random_seed: int = None):
        self.random_seed = random_seed or MODEL_CONFIG["random_seed"]
    
    def load_csv(self, filepath: Union[str, Path], **kwargs) -> pd.DataFrame:
        """Load data from CSV file"""
        filepath = Path(filepath)
        if not filepath.is_absolute():
            filepath = RAW_DATA_DIR / filepath
        
        return pd.read_csv(filepath, **kwargs)
    
    def load_excel(self, filepath: Union[str, Path], **kwargs) -> pd.DataFrame:
        """Load data from Excel file"""
        filepath = Path(filepath)
        if not filepath.is_absolute():
            filepath = RAW_DATA_DIR / filepath
        
        return pd.read_excel(filepath, **kwargs)
    
    def load_json(self, filepath: Union[str, Path], **kwargs) -> pd.DataFrame:
        """Load data from JSON file"""
        filepath = Path(filepath)
        if not filepath.is_absolute():
            filepath = RAW_DATA_DIR / filepath
        
        return pd.read_json(filepath, **kwargs)
    
    def load_numpy(self, filepath: Union[str, Path]) -> np.ndarray:
        """Load data from numpy file"""
        filepath = Path(filepath)
        if not filepath.is_absolute():
            filepath = RAW_DATA_DIR / filepath
        
        return np.load(filepath)
    
    def save_csv(self, df: pd.DataFrame, filename: str, processed: bool = True):
        """Save dataframe to CSV"""
        save_dir = PROCESSED_DATA_DIR if processed else RAW_DATA_DIR
        filepath = save_dir / filename
        df.to_csv(filepath, index=False)
        print(f"Data saved to {filepath}")
    
    def save_numpy(self, array: np.ndarray, filename: str, processed: bool = True):
        """Save numpy array"""
        save_dir = PROCESSED_DATA_DIR if processed else RAW_DATA_DIR
        filepath = save_dir / filename
        np.save(filepath, array)
        print(f"Data saved to {filepath}")
    
    def train_test_split(self, X: np.ndarray, y: np.ndarray, 
                        test_size: float = None,
                        stratify: bool = False) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        """Split data into train and test sets"""
        test_size = test_size or MODEL_CONFIG["test_split"]
        
        stratify_param = y if stratify else None
        
        return train_test_split(
            X, y, 
            test_size=test_size, 
            random_state=self.random_seed,
            stratify=stratify_param
        )
    
    def train_val_test_split(self, X: np.ndarray, y: np.ndarray,
                            val_size: float = None,
                            test_size: float = None,
                            stratify: bool = False) -> Tuple:
        """Split data into train, validation, and test sets"""
        val_size = val_size or MODEL_CONFIG["val_split"]
        test_size = test_size or MODEL_CONFIG["test_split"]
        
        stratify_param = y if stratify else None
        
        X_temp, X_test, y_temp, y_test = train_test_split(
            X, y,
            test_size=test_size,
            random_state=self.random_seed,
            stratify=stratify_param
        )
        
        val_ratio = val_size / (1 - test_size)
        stratify_param = y_temp if stratify else None
        
        X_train, X_val, y_train, y_val = train_test_split(
            X_temp, y_temp,
            test_size=val_ratio,
            random_state=self.random_seed,
            stratify=stratify_param
        )
        
        return X_train, X_val, X_test, y_train, y_val, y_test
    
    def load_image_paths(self, directory: Union[str, Path], 
                        extensions: list = ['.jpg', '.jpeg', '.png']) -> list:
        """Load image file paths from directory"""
        directory = Path(directory)
        if not directory.is_absolute():
            directory = RAW_DATA_DIR / directory
        
        image_paths = []
        for ext in extensions:
            image_paths.extend(list(directory.glob(f"**/*{ext}")))
        
        return [str(path) for path in image_paths]
    
    def create_batches(self, X: np.ndarray, y: np.ndarray, 
                      batch_size: int = None) -> list:
        """Create batches from data"""
        batch_size = batch_size or MODEL_CONFIG["batch_size"]
        
        n_samples = len(X)
        indices = np.arange(n_samples)
        np.random.shuffle(indices)
        
        batches = []
        for start_idx in range(0, n_samples, batch_size):
            end_idx = min(start_idx + batch_size, n_samples)
            batch_indices = indices[start_idx:end_idx]
            batches.append((X[batch_indices], y[batch_indices]))
        
        return batches
    
    def get_data_info(self, X: np.ndarray, y: np.ndarray) -> dict:
        """Get information about the dataset"""
        info = {
            "n_samples": len(X),
            "n_features": X.shape[1] if len(X.shape) > 1 else 1,
            "X_shape": X.shape,
            "y_shape": y.shape,
            "X_dtype": X.dtype,
            "y_dtype": y.dtype,
            "n_classes": len(np.unique(y)) if y.dtype in [np.int32, np.int64] else None
        }
        return info
