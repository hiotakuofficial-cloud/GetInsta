"""
Neural Network Models using PyTorch
"""
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
from typing import List, Optional
from .base_model import BaseModel
from config import DL_CONFIG


class NeuralNetwork(BaseModel):
    """Flexible Neural Network implementation with PyTorch"""
    
    def __init__(self, name: str = "neural_network", input_dim: int = 10, 
                 hidden_layers: List[int] = [64, 32], output_dim: int = 1,
                 activation: str = "relu", **kwargs):
        super().__init__(name, **kwargs)
        self.input_dim = input_dim
        self.hidden_layers = hidden_layers
        self.output_dim = output_dim
        self.activation = activation
        self.device = torch.device(DL_CONFIG["device"])
        self.build()
    
    def build(self, **kwargs):
        """Build neural network architecture"""
        layers = []
        prev_dim = self.input_dim
        
        # Hidden layers
        for hidden_dim in self.hidden_layers:
            layers.append(nn.Linear(prev_dim, hidden_dim))
            
            if self.activation == "relu":
                layers.append(nn.ReLU())
            elif self.activation == "tanh":
                layers.append(nn.Tanh())
            elif self.activation == "sigmoid":
                layers.append(nn.Sigmoid())
            
            layers.append(nn.Dropout(0.2))
            prev_dim = hidden_dim
        
        # Output layer
        layers.append(nn.Linear(prev_dim, self.output_dim))
        
        self.model = nn.Sequential(*layers).to(self.device)
        print(f"Neural Network built with architecture: {self.model}")
    
    def train(self, X_train: np.ndarray, y_train: np.ndarray, 
              X_val: Optional[np.ndarray] = None, y_val: Optional[np.ndarray] = None,
              epochs: int = 100, batch_size: int = 32, learning_rate: float = 0.001,
              **kwargs):
        """Train the neural network"""
        
        # Convert to tensors
        X_train_tensor = torch.FloatTensor(X_train).to(self.device)
        y_train_tensor = torch.FloatTensor(y_train).to(self.device)
        
        if len(y_train_tensor.shape) == 1:
            y_train_tensor = y_train_tensor.unsqueeze(1)
        
        # Create data loader
        train_dataset = TensorDataset(X_train_tensor, y_train_tensor)
        train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
        
        # Loss and optimizer
        if self.output_dim == 1:
            criterion = nn.MSELoss()
        else:
            criterion = nn.CrossEntropyLoss()
        
        optimizer = optim.Adam(self.model.parameters(), lr=learning_rate)
        
        # Training loop
        self.model.train()
        for epoch in range(epochs):
            epoch_loss = 0.0
            for batch_X, batch_y in train_loader:
                optimizer.zero_grad()
                outputs = self.model(batch_X)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()
            
            avg_loss = epoch_loss / len(train_loader)
            
            if (epoch + 1) % 10 == 0:
                print(f"Epoch [{epoch+1}/{epochs}], Loss: {avg_loss:.4f}")
        
        self.is_trained = True
        self.metadata["metrics"]["final_train_loss"] = avg_loss
        
        return self
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """Make predictions"""
        if not self.is_trained:
            raise ValueError("Model must be trained before making predictions")
        
        self.model.eval()
        with torch.no_grad():
            X_tensor = torch.FloatTensor(X).to(self.device)
            predictions = self.model(X_tensor)
            return predictions.cpu().numpy()
    
    def evaluate(self, X_test: np.ndarray, y_test: np.ndarray) -> dict:
        """Evaluate neural network performance"""
        predictions = self.predict(X_test)
        
        if self.output_dim == 1:
            # Regression metrics
            mse = np.mean((predictions - y_test.reshape(-1, 1)) ** 2)
            rmse = np.sqrt(mse)
            mae = np.mean(np.abs(predictions - y_test.reshape(-1, 1)))
            
            metrics = {
                "mse": float(mse),
                "rmse": float(rmse),
                "mae": float(mae)
            }
        else:
            # Classification metrics
            pred_classes = np.argmax(predictions, axis=1)
            accuracy = np.mean(pred_classes == y_test)
            
            metrics = {
                "accuracy": float(accuracy)
            }
        
        self.metadata["metrics"].update(metrics)
        
        print("\nEvaluation Metrics:")
        for metric, value in metrics.items():
            print(f"{metric}: {value:.4f}")
        
        return metrics
    
    def save(self, filepath=None):
        """Save PyTorch model"""
        if filepath is None:
            from config import MODELS_DIR
            filepath = MODELS_DIR / f"{self.name}.pth"
        
        torch.save({
            'model_state_dict': self.model.state_dict(),
            'metadata': self.metadata,
            'architecture': {
                'input_dim': self.input_dim,
                'hidden_layers': self.hidden_layers,
                'output_dim': self.output_dim,
                'activation': self.activation
            }
        }, filepath)
        
        print(f"Model saved to {filepath}")
    
    def load(self, filepath):
        """Load PyTorch model"""
        checkpoint = torch.load(filepath, map_location=self.device)
        self.model.load_state_dict(checkpoint['model_state_dict'])
        self.metadata = checkpoint['metadata']
        self.is_trained = True
        
        print(f"Model loaded from {filepath}")
