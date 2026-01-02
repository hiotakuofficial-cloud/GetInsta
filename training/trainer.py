"""
Training utilities for ML models
"""
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from typing import Optional, List, Callable
from pathlib import Path
from config import MODEL_CONFIG, DL_CONFIG, CHECKPOINTS_DIR
from utils.logger import TrainingLogger


class Trainer:
    """Generic trainer for PyTorch models"""
    
    def __init__(self, model: nn.Module, device: str = None):
        """
        Initialize trainer
        
        Args:
            model: PyTorch model
            device: Device to train on ('cpu' or 'cuda')
        """
        self.device = device or DL_CONFIG["device"]
        self.model = model.to(self.device)
        self.logger = TrainingLogger()
        self.callbacks = []
    
    def add_callback(self, callback):
        """Add training callback"""
        self.callbacks.append(callback)
    
    def train(self, train_loader: DataLoader, val_loader: Optional[DataLoader] = None,
             criterion: nn.Module = None, optimizer: optim.Optimizer = None,
             epochs: int = None, learning_rate: float = None,
             scheduler: Optional[object] = None):
        """
        Train the model
        
        Args:
            train_loader: Training data loader
            val_loader: Validation data loader (optional)
            criterion: Loss function
            optimizer: Optimizer
            epochs: Number of epochs
            learning_rate: Learning rate
            scheduler: Learning rate scheduler (optional)
        """
        epochs = epochs or MODEL_CONFIG["epochs"]
        learning_rate = learning_rate or MODEL_CONFIG["learning_rate"]
        
        if criterion is None:
            criterion = nn.CrossEntropyLoss()
        
        if optimizer is None:
            optimizer = optim.Adam(self.model.parameters(), lr=learning_rate)
        
        self.logger.log_info(f"Starting training for {epochs} epochs")
        self.logger.log_info(f"Device: {self.device}")
        self.logger.log_info(f"Learning rate: {learning_rate}")
        
        for epoch in range(epochs):
            train_loss = self._train_epoch(train_loader, criterion, optimizer)
            
            val_loss = None
            if val_loader is not None:
                val_loss = self._validate_epoch(val_loader, criterion)
            
            self.logger.log_epoch(epoch + 1, train_loss, val_loss)
            
            if scheduler is not None:
                scheduler.step()
            
            for callback in self.callbacks:
                callback.on_epoch_end(epoch, {
                    'train_loss': train_loss,
                    'val_loss': val_loss,
                    'model': self.model
                })
                
                if hasattr(callback, 'should_stop') and callback.should_stop:
                    self.logger.log_info(f"Early stopping triggered at epoch {epoch + 1}")
                    break
        
        self.logger.log_info("Training completed")
        return self.logger.get_history()
    
    def _train_epoch(self, train_loader: DataLoader, criterion: nn.Module,
                    optimizer: optim.Optimizer) -> float:
        """Train for one epoch"""
        self.model.train()
        total_loss = 0.0
        
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(self.device), target.to(self.device)
            
            optimizer.zero_grad()
            output = self.model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
        
        avg_loss = total_loss / len(train_loader)
        return avg_loss
    
    def _validate_epoch(self, val_loader: DataLoader, criterion: nn.Module) -> float:
        """Validate for one epoch"""
        self.model.eval()
        total_loss = 0.0
        
        with torch.no_grad():
            for data, target in val_loader:
                data, target = data.to(self.device), target.to(self.device)
                output = self.model(data)
                loss = criterion(output, target)
                total_loss += loss.item()
        
        avg_loss = total_loss / len(val_loader)
        return avg_loss
    
    def evaluate(self, test_loader: DataLoader, criterion: nn.Module = None) -> dict:
        """
        Evaluate model on test set
        
        Args:
            test_loader: Test data loader
            criterion: Loss function
        
        Returns:
            Dictionary of evaluation metrics
        """
        if criterion is None:
            criterion = nn.CrossEntropyLoss()
        
        self.model.eval()
        total_loss = 0.0
        all_predictions = []
        all_targets = []
        
        with torch.no_grad():
            for data, target in test_loader:
                data, target = data.to(self.device), target.to(self.device)
                output = self.model(data)
                loss = criterion(output, target)
                total_loss += loss.item()
                
                predictions = torch.argmax(output, dim=1)
                all_predictions.extend(predictions.cpu().numpy())
                all_targets.extend(target.cpu().numpy())
        
        avg_loss = total_loss / len(test_loader)
        accuracy = np.mean(np.array(all_predictions) == np.array(all_targets))
        
        metrics = {
            'test_loss': avg_loss,
            'test_accuracy': accuracy
        }
        
        self.logger.log_info(f"Test Loss: {avg_loss:.4f}, Test Accuracy: {accuracy:.4f}")
        
        return metrics
    
    def predict(self, data_loader: DataLoader) -> np.ndarray:
        """
        Make predictions
        
        Args:
            data_loader: Data loader
        
        Returns:
            Predictions as numpy array
        """
        self.model.eval()
        all_predictions = []
        
        with torch.no_grad():
            for data, _ in data_loader:
                data = data.to(self.device)
                output = self.model(data)
                predictions = torch.argmax(output, dim=1)
                all_predictions.extend(predictions.cpu().numpy())
        
        return np.array(all_predictions)
    
    def save_checkpoint(self, filepath: Path, epoch: int, optimizer: optim.Optimizer = None):
        """Save training checkpoint"""
        filepath = Path(filepath)
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        checkpoint = {
            'epoch': epoch,
            'model_state_dict': self.model.state_dict(),
            'history': self.logger.get_history()
        }
        
        if optimizer is not None:
            checkpoint['optimizer_state_dict'] = optimizer.state_dict()
        
        torch.save(checkpoint, filepath)
        self.logger.log_info(f"Checkpoint saved to {filepath}")
    
    def load_checkpoint(self, filepath: Path, optimizer: optim.Optimizer = None):
        """Load training checkpoint"""
        checkpoint = torch.load(filepath, map_location=self.device)
        
        self.model.load_state_dict(checkpoint['model_state_dict'])
        
        if optimizer is not None and 'optimizer_state_dict' in checkpoint:
            optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
        
        self.logger.log_info(f"Checkpoint loaded from {filepath}")
        
        return checkpoint.get('epoch', 0)
