"""
Main entry point for AI/ML pipeline
Example usage and demonstrations
"""
import numpy as np
from sklearn.datasets import make_classification, make_regression

from models import Classifier, Regressor, NeuralNetwork
from preprocessing import DataCleaner, FeatureEngineer, DataScaler
from data import DataLoader
from utils import setup_logger, calculate_metrics
from config import MODEL_CONFIG


def example_classification():
    """Example classification pipeline"""
    print("\n" + "="*60)
    print("CLASSIFICATION EXAMPLE")
    print("="*60)
    
    logger = setup_logger("classification_example")
    logger.info("Starting classification example")
    
    X, y = make_classification(
        n_samples=1000, 
        n_features=20, 
        n_informative=15,
        n_redundant=5,
        random_state=42
    )
    
    data_loader = DataLoader()
    X_train, X_test, y_train, y_test = data_loader.train_test_split(X, y)
    
    logger.info(f"Data split: Train={len(X_train)}, Test={len(X_test)}")
    
    scaler = DataScaler(method="standard")
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    classifier = Classifier(
        name="random_forest_classifier",
        model_type="random_forest",
        n_estimators=100,
        random_state=42
    )
    
    logger.info("Training classifier...")
    classifier.train(X_train_scaled, y_train)
    
    logger.info("Evaluating classifier...")
    metrics = classifier.evaluate(X_test_scaled, y_test)
    
    print("\nClassification Results:")
    for metric, value in metrics.items():
        print(f"  {metric}: {value:.4f}")
    
    classifier.save()
    logger.info("Classification example completed")


def example_regression():
    """Example regression pipeline"""
    print("\n" + "="*60)
    print("REGRESSION EXAMPLE")
    print("="*60)
    
    logger = setup_logger("regression_example")
    logger.info("Starting regression example")
    
    X, y = make_regression(
        n_samples=1000,
        n_features=20,
        n_informative=15,
        noise=10,
        random_state=42
    )
    
    data_loader = DataLoader()
    X_train, X_test, y_train, y_test = data_loader.train_test_split(X, y)
    
    logger.info(f"Data split: Train={len(X_train)}, Test={len(X_test)}")
    
    scaler = DataScaler(method="standard")
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    regressor = Regressor(
        name="random_forest_regressor",
        model_type="random_forest",
        n_estimators=100,
        random_state=42
    )
    
    logger.info("Training regressor...")
    regressor.train(X_train_scaled, y_train)
    
    logger.info("Evaluating regressor...")
    metrics = regressor.evaluate(X_test_scaled, y_test)
    
    print("\nRegression Results:")
    for metric, value in metrics.items():
        print(f"  {metric}: {value:.4f}")
    
    regressor.save()
    logger.info("Regression example completed")


def example_neural_network():
    """Example neural network pipeline"""
    print("\n" + "="*60)
    print("NEURAL NETWORK EXAMPLE")
    print("="*60)
    
    logger = setup_logger("neural_network_example")
    logger.info("Starting neural network example")
    
    X, y = make_classification(
        n_samples=1000,
        n_features=20,
        n_classes=3,
        n_informative=15,
        random_state=42
    )
    
    data_loader = DataLoader()
    X_train, X_val, X_test, y_train, y_val, y_test = data_loader.train_val_test_split(X, y)
    
    logger.info(f"Data split: Train={len(X_train)}, Val={len(X_val)}, Test={len(X_test)}")
    
    scaler = DataScaler(method="standard")
    X_train_scaled = scaler.fit_transform(X_train)
    X_val_scaled = scaler.transform(X_val)
    X_test_scaled = scaler.transform(X_test)
    
    nn_model = NeuralNetwork(
        name="mlp_classifier",
        input_dim=20,
        hidden_layers=[64, 32, 16],
        output_dim=3,
        activation="relu"
    )
    
    logger.info("Training neural network...")
    nn_model.train(
        X_train_scaled, y_train,
        X_val=X_val_scaled, y_val=y_val,
        epochs=50,
        batch_size=32,
        learning_rate=0.001
    )
    
    logger.info("Evaluating neural network...")
    metrics = nn_model.evaluate(X_test_scaled, y_test)
    
    print("\nNeural Network Results:")
    for metric, value in metrics.items():
        print(f"  {metric}: {value:.4f}")
    
    nn_model.save()
    logger.info("Neural network example completed")


def main():
    """Run all examples"""
    print("\n" + "="*60)
    print("AI/ML ENVIRONMENT - EXAMPLES")
    print("="*60)
    
    try:
        example_classification()
    except Exception as e:
        print(f"Classification example failed: {e}")
    
    try:
        example_regression()
    except Exception as e:
        print(f"Regression example failed: {e}")
    
    try:
        example_neural_network()
    except Exception as e:
        print(f"Neural network example failed: {e}")
    
    print("\n" + "="*60)
    print("ALL EXAMPLES COMPLETED")
    print("="*60)


if __name__ == "__main__":
    main()
