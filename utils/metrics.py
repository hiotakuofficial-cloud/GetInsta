"""
Metrics calculation utilities
"""
import numpy as np
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    mean_squared_error, mean_absolute_error, r2_score,
    confusion_matrix, classification_report, roc_auc_score
)
from typing import Dict, Optional


def calculate_classification_metrics(y_true: np.ndarray, y_pred: np.ndarray,
                                     y_pred_proba: Optional[np.ndarray] = None,
                                     average: str = 'weighted') -> Dict[str, float]:
    """
    Calculate classification metrics
    
    Args:
        y_true: True labels
        y_pred: Predicted labels
        y_pred_proba: Predicted probabilities (optional)
        average: Averaging method for multi-class
    
    Returns:
        Dictionary of metrics
    """
    metrics = {
        'accuracy': accuracy_score(y_true, y_pred),
        'precision': precision_score(y_true, y_pred, average=average, zero_division=0),
        'recall': recall_score(y_true, y_pred, average=average, zero_division=0),
        'f1_score': f1_score(y_true, y_pred, average=average, zero_division=0)
    }
    
    if y_pred_proba is not None:
        try:
            if len(np.unique(y_true)) == 2:
                metrics['roc_auc'] = roc_auc_score(y_true, y_pred_proba[:, 1])
            else:
                metrics['roc_auc'] = roc_auc_score(y_true, y_pred_proba, 
                                                   multi_class='ovr', average=average)
        except Exception as e:
            print(f"Could not calculate ROC AUC: {e}")
    
    return metrics


def calculate_regression_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
    """
    Calculate regression metrics
    
    Args:
        y_true: True values
        y_pred: Predicted values
    
    Returns:
        Dictionary of metrics
    """
    metrics = {
        'mse': mean_squared_error(y_true, y_pred),
        'rmse': np.sqrt(mean_squared_error(y_true, y_pred)),
        'mae': mean_absolute_error(y_true, y_pred),
        'r2_score': r2_score(y_true, y_pred)
    }
    
    mape = np.mean(np.abs((y_true - y_pred) / (y_true + 1e-8))) * 100
    metrics['mape'] = mape
    
    return metrics


def calculate_metrics(y_true: np.ndarray, y_pred: np.ndarray,
                     task_type: str = 'classification',
                     **kwargs) -> Dict[str, float]:
    """
    Calculate metrics based on task type
    
    Args:
        y_true: True labels/values
        y_pred: Predicted labels/values
        task_type: 'classification' or 'regression'
        **kwargs: Additional arguments
    
    Returns:
        Dictionary of metrics
    """
    if task_type == 'classification':
        return calculate_classification_metrics(y_true, y_pred, **kwargs)
    elif task_type == 'regression':
        return calculate_regression_metrics(y_true, y_pred)
    else:
        raise ValueError(f"Unknown task_type: {task_type}")


def print_classification_report(y_true: np.ndarray, y_pred: np.ndarray,
                               target_names: Optional[list] = None):
    """Print detailed classification report"""
    print("\nClassification Report:")
    print("=" * 60)
    print(classification_report(y_true, y_pred, target_names=target_names, zero_division=0))


def get_confusion_matrix(y_true: np.ndarray, y_pred: np.ndarray) -> np.ndarray:
    """Calculate confusion matrix"""
    return confusion_matrix(y_true, y_pred)


def calculate_class_weights(y: np.ndarray) -> Dict[int, float]:
    """Calculate class weights for imbalanced datasets"""
    unique_classes, counts = np.unique(y, return_counts=True)
    total_samples = len(y)
    n_classes = len(unique_classes)
    
    weights = {}
    for cls, count in zip(unique_classes, counts):
        weights[int(cls)] = total_samples / (n_classes * count)
    
    return weights


def calculate_top_k_accuracy(y_true: np.ndarray, y_pred_proba: np.ndarray, k: int = 5) -> float:
    """Calculate top-k accuracy"""
    top_k_preds = np.argsort(y_pred_proba, axis=1)[:, -k:]
    correct = np.array([y_true[i] in top_k_preds[i] for i in range(len(y_true))])
    return np.mean(correct)


def calculate_precision_at_k(y_true: np.ndarray, y_pred_proba: np.ndarray, k: int = 5) -> float:
    """Calculate precision at k for ranking tasks"""
    top_k_preds = np.argsort(y_pred_proba, axis=1)[:, -k:]
    precisions = []
    
    for i in range(len(y_true)):
        relevant = np.sum(top_k_preds[i] == y_true[i])
        precisions.append(relevant / k)
    
    return np.mean(precisions)


def calculate_mean_average_precision(y_true: np.ndarray, y_pred_proba: np.ndarray) -> float:
    """Calculate Mean Average Precision (MAP)"""
    aps = []
    
    for i in range(len(y_true)):
        sorted_indices = np.argsort(y_pred_proba[i])[::-1]
        relevant_positions = np.where(sorted_indices == y_true[i])[0]
        
        if len(relevant_positions) > 0:
            ap = 1.0 / (relevant_positions[0] + 1)
            aps.append(ap)
    
    return np.mean(aps) if aps else 0.0
