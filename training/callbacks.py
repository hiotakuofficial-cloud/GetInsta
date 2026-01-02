"""
Training callbacks
"""
import numpy as np
import torch
from pathlib import Path
from config import CHECKPOINTS_DIR


class Callback:
    """Base callback class"""
    
    def on_epoch_end(self, epoch: int, logs: dict):
        """Called at the end of each epoch"""
        pass
    
    def on_train_begin(self, logs: dict):
        """Called at the beginning of training"""
        pass
    
    def on_train_end(self, logs: dict):
        """Called at the end of training"""
        pass


class EarlyStopping(Callback):
    """Stop training when a monitored metric has stopped improving"""
    
    def __init__(self, monitor: str = 'val_loss', patience: int = 10,
                 mode: str = 'min', min_delta: float = 0.0):
        """
        Args:
            monitor: Metric to monitor
            patience: Number of epochs with no improvement after which training will be stopped
            mode: 'min' or 'max' - whether to minimize or maximize the monitored metric
            min_delta: Minimum change to qualify as an improvement
        """
        self.monitor = monitor
        self.patience = patience
        self.mode = mode
        self.min_delta = min_delta
        self.wait = 0
        self.best_value = None
        self.should_stop = False
    
    def on_epoch_end(self, epoch: int, logs: dict):
        """Check if training should stop"""
        current_value = logs.get(self.monitor)
        
        if current_value is None:
            return
        
        if self.best_value is None:
            self.best_value = current_value
            return
        
        if self.mode == 'min':
            improved = current_value < (self.best_value - self.min_delta)
        else:
            improved = current_value > (self.best_value + self.min_delta)
        
        if improved:
            self.best_value = current_value
            self.wait = 0
        else:
            self.wait += 1
            if self.wait >= self.patience:
                self.should_stop = True
                print(f"\nEarly stopping triggered after {epoch + 1} epochs")
                print(f"Best {self.monitor}: {self.best_value:.4f}")


class ModelCheckpoint(Callback):
    """Save model checkpoints during training"""
    
    def __init__(self, filepath: Path = None, monitor: str = 'val_loss',
                 mode: str = 'min', save_best_only: bool = True):
        """
        Args:
            filepath: Path to save checkpoints
            monitor: Metric to monitor
            mode: 'min' or 'max'
            save_best_only: Only save when the monitored metric improves
        """
        self.filepath = filepath or CHECKPOINTS_DIR / "checkpoint_epoch_{epoch}.pth"
        self.monitor = monitor
        self.mode = mode
        self.save_best_only = save_best_only
        self.best_value = None
    
    def on_epoch_end(self, epoch: int, logs: dict):
        """Save checkpoint if conditions are met"""
        current_value = logs.get(self.monitor)
        model = logs.get('model')
        
        if model is None:
            return
        
        should_save = False
        
        if not self.save_best_only:
            should_save = True
        elif current_value is not None:
            if self.best_value is None:
                should_save = True
                self.best_value = current_value
            else:
                if self.mode == 'min':
                    improved = current_value < self.best_value
                else:
                    improved = current_value > self.best_value
                
                if improved:
                    should_save = True
                    self.best_value = current_value
        
        if should_save:
            filepath = Path(str(self.filepath).format(epoch=epoch + 1))
            filepath.parent.mkdir(parents=True, exist_ok=True)
            
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'monitored_value': current_value
            }, filepath)
            
            print(f"\nCheckpoint saved to {filepath}")


class ReduceLROnPlateau(Callback):
    """Reduce learning rate when a metric has stopped improving"""
    
    def __init__(self, optimizer, monitor: str = 'val_loss', factor: float = 0.5,
                 patience: int = 5, mode: str = 'min', min_lr: float = 1e-7):
        """
        Args:
            optimizer: Optimizer to adjust learning rate
            monitor: Metric to monitor
            factor: Factor by which to reduce learning rate
            patience: Number of epochs with no improvement after which LR will be reduced
            mode: 'min' or 'max'
            min_lr: Minimum learning rate
        """
        self.optimizer = optimizer
        self.monitor = monitor
        self.factor = factor
        self.patience = patience
        self.mode = mode
        self.min_lr = min_lr
        self.wait = 0
        self.best_value = None
    
    def on_epoch_end(self, epoch: int, logs: dict):
        """Check if learning rate should be reduced"""
        current_value = logs.get(self.monitor)
        
        if current_value is None:
            return
        
        if self.best_value is None:
            self.best_value = current_value
            return
        
        if self.mode == 'min':
            improved = current_value < self.best_value
        else:
            improved = current_value > self.best_value
        
        if improved:
            self.best_value = current_value
            self.wait = 0
        else:
            self.wait += 1
            if self.wait >= self.patience:
                self._reduce_lr()
                self.wait = 0
    
    def _reduce_lr(self):
        """Reduce learning rate"""
        for param_group in self.optimizer.param_groups:
            old_lr = param_group['lr']
            new_lr = max(old_lr * self.factor, self.min_lr)
            param_group['lr'] = new_lr
            print(f"\nReducing learning rate from {old_lr:.6f} to {new_lr:.6f}")


class LearningRateScheduler(Callback):
    """Custom learning rate scheduler"""
    
    def __init__(self, optimizer, schedule_fn):
        """
        Args:
            optimizer: Optimizer to adjust learning rate
            schedule_fn: Function that takes epoch and returns learning rate
        """
        self.optimizer = optimizer
        self.schedule_fn = schedule_fn
    
    def on_epoch_end(self, epoch: int, logs: dict):
        """Update learning rate based on schedule"""
        new_lr = self.schedule_fn(epoch)
        
        for param_group in self.optimizer.param_groups:
            param_group['lr'] = new_lr
        
        print(f"\nLearning rate updated to {new_lr:.6f}")
