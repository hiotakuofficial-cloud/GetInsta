"""
Custom Dataset classes for PyTorch
"""
import numpy as np
import torch
from torch.utils.data import Dataset as TorchDataset
from typing import Optional, Callable


class Dataset(TorchDataset):
    """Custom PyTorch Dataset for numpy arrays"""
    
    def __init__(self, X: np.ndarray, y: np.ndarray, 
                 transform: Optional[Callable] = None):
        """
        Args:
            X: Input features
            y: Target labels
            transform: Optional transform to apply to samples
        """
        self.X = torch.FloatTensor(X)
        self.y = torch.FloatTensor(y) if y.dtype == np.float32 or y.dtype == np.float64 else torch.LongTensor(y)
        self.transform = transform
    
    def __len__(self) -> int:
        return len(self.X)
    
    def __getitem__(self, idx: int):
        sample = self.X[idx]
        label = self.y[idx]
        
        if self.transform:
            sample = self.transform(sample)
        
        return sample, label


class ImageDataset(TorchDataset):
    """Custom Dataset for image data"""
    
    def __init__(self, image_paths: list, labels: np.ndarray,
                 transform: Optional[Callable] = None):
        """
        Args:
            image_paths: List of image file paths
            labels: Target labels
            transform: Optional transform to apply to images
        """
        self.image_paths = image_paths
        self.labels = torch.LongTensor(labels)
        self.transform = transform
    
    def __len__(self) -> int:
        return len(self.image_paths)
    
    def __getitem__(self, idx: int):
        from PIL import Image
        
        image_path = self.image_paths[idx]
        image = Image.open(image_path).convert('RGB')
        label = self.labels[idx]
        
        if self.transform:
            image = self.transform(image)
        
        return image, label


class TextDataset(TorchDataset):
    """Custom Dataset for text data"""
    
    def __init__(self, texts: list, labels: np.ndarray,
                 tokenizer: Optional[Callable] = None,
                 max_length: int = 512):
        """
        Args:
            texts: List of text strings
            labels: Target labels
            tokenizer: Optional tokenizer function
            max_length: Maximum sequence length
        """
        self.texts = texts
        self.labels = torch.LongTensor(labels)
        self.tokenizer = tokenizer
        self.max_length = max_length
    
    def __len__(self) -> int:
        return len(self.texts)
    
    def __getitem__(self, idx: int):
        text = self.texts[idx]
        label = self.labels[idx]
        
        if self.tokenizer:
            encoding = self.tokenizer(
                text,
                max_length=self.max_length,
                padding='max_length',
                truncation=True,
                return_tensors='pt'
            )
            return encoding, label
        
        return text, label


class TimeSeriesDataset(TorchDataset):
    """Custom Dataset for time series data"""
    
    def __init__(self, data: np.ndarray, sequence_length: int, 
                 prediction_horizon: int = 1):
        """
        Args:
            data: Time series data
            sequence_length: Length of input sequences
            prediction_horizon: Number of steps to predict ahead
        """
        self.data = torch.FloatTensor(data)
        self.sequence_length = sequence_length
        self.prediction_horizon = prediction_horizon
    
    def __len__(self) -> int:
        return len(self.data) - self.sequence_length - self.prediction_horizon + 1
    
    def __getitem__(self, idx: int):
        X = self.data[idx:idx + self.sequence_length]
        y = self.data[idx + self.sequence_length:idx + self.sequence_length + self.prediction_horizon]
        return X, y
