"""
Logging utilities
"""
import logging
import sys
from pathlib import Path
from config import LOGGING_CONFIG, LOGS_DIR


def setup_logger(name: str = "ml_pipeline", 
                log_file: str = None,
                level: str = None) -> logging.Logger:
    """
    Setup logger with file and console handlers
    
    Args:
        name: Logger name
        log_file: Log file path (optional)
        level: Logging level (optional)
    
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    
    log_level = level or LOGGING_CONFIG["level"]
    logger.setLevel(getattr(logging, log_level))
    
    if logger.handlers:
        return logger
    
    formatter = logging.Formatter(LOGGING_CONFIG["format"])
    
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level))
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    if log_file:
        log_path = Path(log_file)
    else:
        log_path = LOGGING_CONFIG["log_file"]
    
    log_path.parent.mkdir(parents=True, exist_ok=True)
    
    file_handler = logging.FileHandler(log_path)
    file_handler.setLevel(getattr(logging, log_level))
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    return logger


class TrainingLogger:
    """Logger for tracking training progress"""
    
    def __init__(self, name: str = "training"):
        self.logger = setup_logger(name)
        self.history = {
            "epoch": [],
            "train_loss": [],
            "val_loss": [],
            "train_metrics": [],
            "val_metrics": []
        }
    
    def log_epoch(self, epoch: int, train_loss: float, val_loss: float = None,
                 train_metrics: dict = None, val_metrics: dict = None):
        """Log epoch results"""
        self.history["epoch"].append(epoch)
        self.history["train_loss"].append(train_loss)
        
        log_msg = f"Epoch {epoch}: Train Loss = {train_loss:.4f}"
        
        if val_loss is not None:
            self.history["val_loss"].append(val_loss)
            log_msg += f", Val Loss = {val_loss:.4f}"
        
        if train_metrics:
            self.history["train_metrics"].append(train_metrics)
            log_msg += f", Train Metrics = {train_metrics}"
        
        if val_metrics:
            self.history["val_metrics"].append(val_metrics)
            log_msg += f", Val Metrics = {val_metrics}"
        
        self.logger.info(log_msg)
    
    def log_info(self, message: str):
        """Log info message"""
        self.logger.info(message)
    
    def log_warning(self, message: str):
        """Log warning message"""
        self.logger.warning(message)
    
    def log_error(self, message: str):
        """Log error message"""
        self.logger.error(message)
    
    def get_history(self) -> dict:
        """Get training history"""
        return self.history
    
    def save_history(self, filepath: Path):
        """Save training history to file"""
        import json
        
        filepath = Path(filepath)
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'w') as f:
            json.dump(self.history, f, indent=2)
        
        self.logger.info(f"Training history saved to {filepath}")
