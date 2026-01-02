"""
Configuration settings for AI/ML environment
"""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Project Paths
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
PROCESSED_DATA_DIR = DATA_DIR / "processed"
MODELS_DIR = BASE_DIR / "models" / "saved"
LOGS_DIR = BASE_DIR / "logs"
CHECKPOINTS_DIR = BASE_DIR / "checkpoints"

# Create directories if they don't exist
for directory in [RAW_DATA_DIR, PROCESSED_DATA_DIR, MODELS_DIR, LOGS_DIR, CHECKPOINTS_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

# Model Configuration
MODEL_CONFIG = {
    "random_seed": 42,
    "train_split": 0.8,
    "val_split": 0.1,
    "test_split": 0.1,
    "batch_size": 32,
    "epochs": 100,
    "learning_rate": 0.001,
    "early_stopping_patience": 10,
}

# Deep Learning Configuration
DL_CONFIG = {
    "device": "cuda" if os.getenv("USE_GPU", "false").lower() == "true" else "cpu",
    "num_workers": int(os.getenv("NUM_WORKERS", "4")),
    "pin_memory": True,
    "mixed_precision": os.getenv("MIXED_PRECISION", "false").lower() == "true",
}

# Computer Vision Configuration
CV_CONFIG = {
    "image_size": (224, 224),
    "channels": 3,
    "augmentation": True,
    "normalization_mean": [0.485, 0.456, 0.406],
    "normalization_std": [0.229, 0.224, 0.225],
}

# NLP Configuration
NLP_CONFIG = {
    "max_sequence_length": 512,
    "vocab_size": 30000,
    "embedding_dim": 300,
    "pretrained_model": "bert-base-uncased",
}

# Logging Configuration
LOGGING_CONFIG = {
    "level": os.getenv("LOG_LEVEL", "INFO"),
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "log_file": LOGS_DIR / "app.log",
}

# API Keys (from environment variables)
API_KEYS = {
    "openai": os.getenv("OPENAI_API_KEY"),
    "huggingface": os.getenv("HUGGINGFACE_API_KEY"),
}
