# AI/ML Environment

A comprehensive Python-based AI/ML environment with modular structure for machine learning and deep learning projects.

## Project Structure

```
.
├── config.py                 # Configuration settings
├── requirements.txt          # Python dependencies
├── main.py                   # Example usage and entry point
│
├── models/                   # ML/DL Models
│   ├── __init__.py
│   ├── base_model.py        # Abstract base model class
│   ├── classifier.py        # Classification models
│   ├── regressor.py         # Regression models
│   ├── neural_network.py    # Neural network models
│   └── saved/               # Saved model files
│
├── preprocessing/            # Data Preprocessing
│   ├── __init__.py
│   ├── data_cleaner.py      # Data cleaning utilities
│   ├── feature_engineer.py  # Feature engineering
│   ├── scaler.py            # Data scaling/normalization
│   ├── text_processor.py    # NLP preprocessing
│   └── image_processor.py   # Computer vision preprocessing
│
├── data/                     # Data Management
│   ├── __init__.py
│   ├── data_loader.py       # Data loading utilities
│   ├── dataset.py           # Custom PyTorch datasets
│   ├── raw/                 # Raw data files
│   └── processed/           # Processed data files
│
├── training/                 # Training Utilities
│   ├── __init__.py
│   ├── trainer.py           # Training loop implementation
│   └── callbacks.py         # Training callbacks
│
├── utils/                    # Utilities
│   ├── __init__.py
│   ├── logger.py            # Logging utilities
│   ├── metrics.py           # Metrics calculation
│   └── visualization.py     # Visualization tools
│
├── logs/                     # Training logs
├── checkpoints/              # Model checkpoints
└── .env.example             # Environment variables template

```

## Features

### Models
- **Base Model**: Abstract class for all ML models with save/load functionality
- **Classifier**: Wrapper for scikit-learn classifiers (Random Forest, Gradient Boosting, Logistic Regression, SVM)
- **Regressor**: Wrapper for scikit-learn regressors (Random Forest, Gradient Boosting, Linear, Ridge, Lasso, SVR)
- **Neural Network**: Flexible PyTorch neural network with customizable architecture

### Preprocessing
- **Data Cleaner**: Handle missing values, outliers, duplicates, data type conversion
- **Feature Engineer**: Create polynomial features, interactions, binning, log transforms, datetime features, lag features, rolling features
- **Data Scaler**: Standard, MinMax, Robust, MaxAbs scaling
- **Text Processor**: Tokenization, stopword removal, stemming, lemmatization, TF-IDF
- **Image Processor**: Loading, resizing, normalization, augmentation, edge detection

### Data Management
- **Data Loader**: Load CSV, Excel, JSON, NumPy files; train/test/val splitting
- **Custom Datasets**: PyTorch datasets for arrays, images, text, time series

### Training
- **Trainer**: Generic PyTorch training loop with validation
- **Callbacks**: Early stopping, model checkpointing, learning rate scheduling

### Utilities
- **Logger**: Structured logging for training and experiments
- **Metrics**: Classification and regression metrics calculation
- **Visualization**: Plot training history, confusion matrix, feature importance, predictions

## Installation

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Quick Start

Run the example pipeline:
```bash
python main.py
```

## Usage Examples

### Classification
```python
from models import Classifier
from preprocessing import DataScaler
from data import DataLoader

# Load and split data
loader = DataLoader()
X_train, X_test, y_train, y_test = loader.train_test_split(X, y)

# Scale features
scaler = DataScaler(method="standard")
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Train classifier
classifier = Classifier(model_type="random_forest", n_estimators=100)
classifier.train(X_train_scaled, y_train)

# Evaluate
metrics = classifier.evaluate(X_test_scaled, y_test)
classifier.save()
```

### Neural Network
```python
from models import NeuralNetwork

# Create neural network
nn = NeuralNetwork(
    input_dim=20,
    hidden_layers=[64, 32, 16],
    output_dim=3,
    activation="relu"
)

# Train
nn.train(X_train, y_train, epochs=50, batch_size=32)

# Evaluate
metrics = nn.evaluate(X_test, y_test)
nn.save()
```

### Text Processing
```python
from preprocessing import TextProcessor

processor = TextProcessor()
texts = ["Your text here", "Another text"]

# Process texts
processed = processor.process_corpus(texts, remove_stopwords=True, use_lemmatization=True)

# Build vocabulary
vocab = processor.get_vocabulary(processed)

# Convert to sequences
sequences = processor.tokens_to_sequences(processed, vocab)
```

### Image Processing
```python
from preprocessing import ImageProcessor

processor = ImageProcessor(target_size=(224, 224))

# Load and preprocess image
img = processor.load_image("path/to/image.jpg")
img_resized = processor.resize_image(img)
img_normalized = processor.normalize_image(img_resized)

# Apply augmentation
img_augmented = processor.apply_random_augmentation(img_normalized)
```

## Configuration

Edit `config.py` to customize:
- Data paths
- Model hyperparameters
- Deep learning settings
- Computer vision settings
- NLP settings
- Logging configuration

## Environment Variables

Create a `.env` file with:
```
USE_GPU=false
NUM_WORKERS=4
MIXED_PRECISION=false
LOG_LEVEL=INFO
OPENAI_API_KEY=your_key_here
HUGGINGFACE_API_KEY=your_key_here
```

## Project Guidelines

- No test files are included (as per project requirements)
- Clean project structure with modular components
- All modules are well-documented with docstrings
- Configuration centralized in `config.py`
- Logging integrated throughout the pipeline

## Dependencies

Core libraries:
- NumPy, Pandas, Scikit-learn
- PyTorch, TensorFlow
- OpenCV, Pillow
- Transformers, NLTK, spaCy
- Matplotlib, Seaborn, Plotly

See `requirements.txt` for complete list.

## License

This project is open source and available for educational and commercial use.
