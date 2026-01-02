"""
Classification Models
"""
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.svm import SVC
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, classification_report
from .base_model import BaseModel


class Classifier(BaseModel):
    """Generic Classifier wrapper for scikit-learn models"""
    
    def __init__(self, name: str = "classifier", model_type: str = "random_forest", **kwargs):
        super().__init__(name, **kwargs)
        self.model_type = model_type
        self.build(**kwargs)
    
    def build(self, **kwargs):
        """Build classifier based on model_type"""
        if self.model_type == "random_forest":
            self.model = RandomForestClassifier(
                n_estimators=kwargs.get('n_estimators', 100),
                max_depth=kwargs.get('max_depth', None),
                random_state=kwargs.get('random_state', 42)
            )
        elif self.model_type == "gradient_boosting":
            self.model = GradientBoostingClassifier(
                n_estimators=kwargs.get('n_estimators', 100),
                learning_rate=kwargs.get('learning_rate', 0.1),
                max_depth=kwargs.get('max_depth', 3),
                random_state=kwargs.get('random_state', 42)
            )
        elif self.model_type == "logistic_regression":
            self.model = LogisticRegression(
                max_iter=kwargs.get('max_iter', 1000),
                random_state=kwargs.get('random_state', 42)
            )
        elif self.model_type == "svm":
            self.model = SVC(
                kernel=kwargs.get('kernel', 'rbf'),
                C=kwargs.get('C', 1.0),
                random_state=kwargs.get('random_state', 42)
            )
        else:
            raise ValueError(f"Unknown model_type: {self.model_type}")
    
    def train(self, X_train: np.ndarray, y_train: np.ndarray, **kwargs):
        """Train the classifier"""
        self.model.fit(X_train, y_train)
        self.is_trained = True
        
        # Calculate training metrics
        y_pred = self.model.predict(X_train)
        self.metadata["metrics"]["train_accuracy"] = accuracy_score(y_train, y_pred)
        
        return self
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """Make predictions"""
        if not self.is_trained:
            raise ValueError("Model must be trained before making predictions")
        return self.model.predict(X)
    
    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        """Predict class probabilities"""
        if not self.is_trained:
            raise ValueError("Model must be trained before making predictions")
        if hasattr(self.model, 'predict_proba'):
            return self.model.predict_proba(X)
        else:
            raise AttributeError(f"{self.model_type} does not support probability predictions")
    
    def evaluate(self, X_test: np.ndarray, y_test: np.ndarray) -> dict:
        """Evaluate classifier performance"""
        y_pred = self.predict(X_test)
        
        metrics = {
            "accuracy": accuracy_score(y_test, y_pred),
            "precision": precision_score(y_test, y_pred, average='weighted', zero_division=0),
            "recall": recall_score(y_test, y_pred, average='weighted', zero_division=0),
            "f1_score": f1_score(y_test, y_pred, average='weighted', zero_division=0)
        }
        
        self.metadata["metrics"].update(metrics)
        
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred, zero_division=0))
        
        return metrics
    
    def feature_importance(self) -> np.ndarray:
        """Get feature importance (if available)"""
        if hasattr(self.model, 'feature_importances_'):
            return self.model.feature_importances_
        else:
            raise AttributeError(f"{self.model_type} does not support feature importance")
