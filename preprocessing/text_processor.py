"""
Text Processing utilities for NLP
"""
import re
import numpy as np
from typing import List, Optional
import nltk
from nltk.corpus import stopwords
from nltk.tokenize import word_tokenize
from nltk.stem import PorterStemmer, WordNetLemmatizer


class TextProcessor:
    """Process and clean text data for NLP tasks"""
    
    def __init__(self, language: str = "english"):
        self.language = language
        self.stemmer = PorterStemmer()
        self.lemmatizer = WordNetLemmatizer()
        
        try:
            self.stop_words = set(stopwords.words(language))
        except LookupError:
            print(f"Downloading NLTK stopwords for {language}...")
            nltk.download('stopwords', quiet=True)
            self.stop_words = set(stopwords.words(language))
        
        try:
            word_tokenize("test")
        except LookupError:
            print("Downloading NLTK punkt tokenizer...")
            nltk.download('punkt', quiet=True)
        
        try:
            self.lemmatizer.lemmatize("test")
        except LookupError:
            print("Downloading NLTK wordnet...")
            nltk.download('wordnet', quiet=True)
    
    def clean_text(self, text: str) -> str:
        """Basic text cleaning"""
        text = text.lower()
        text = re.sub(r'http\S+|www\S+|https\S+', '', text, flags=re.MULTILINE)
        text = re.sub(r'\@\w+|\#', '', text)
        text = re.sub(r'[^a-zA-Z\s]', '', text)
        text = re.sub(r'\s+', ' ', text).strip()
        return text
    
    def tokenize(self, text: str) -> List[str]:
        """Tokenize text into words"""
        return word_tokenize(text)
    
    def remove_stopwords(self, tokens: List[str]) -> List[str]:
        """Remove stopwords from token list"""
        return [token for token in tokens if token not in self.stop_words]
    
    def stem_tokens(self, tokens: List[str]) -> List[str]:
        """Apply stemming to tokens"""
        return [self.stemmer.stem(token) for token in tokens]
    
    def lemmatize_tokens(self, tokens: List[str], pos: str = 'v') -> List[str]:
        """Apply lemmatization to tokens"""
        return [self.lemmatizer.lemmatize(token, pos=pos) for token in tokens]
    
    def process_text(self, text: str, remove_stopwords: bool = True,
                    use_stemming: bool = False, use_lemmatization: bool = True) -> List[str]:
        """Complete text processing pipeline"""
        text = self.clean_text(text)
        tokens = self.tokenize(text)
        
        if remove_stopwords:
            tokens = self.remove_stopwords(tokens)
        
        if use_stemming:
            tokens = self.stem_tokens(tokens)
        elif use_lemmatization:
            tokens = self.lemmatize_tokens(tokens)
        
        return tokens
    
    def process_corpus(self, texts: List[str], **kwargs) -> List[List[str]]:
        """Process multiple texts"""
        return [self.process_text(text, **kwargs) for text in texts]
    
    def get_vocabulary(self, corpus: List[List[str]]) -> dict:
        """Build vocabulary from processed corpus"""
        vocab = {}
        idx = 0
        for tokens in corpus:
            for token in tokens:
                if token not in vocab:
                    vocab[token] = idx
                    idx += 1
        return vocab
    
    def tokens_to_sequences(self, corpus: List[List[str]], vocab: dict) -> List[List[int]]:
        """Convert tokens to sequences of integers"""
        sequences = []
        for tokens in corpus:
            sequence = [vocab.get(token, 0) for token in tokens]
            sequences.append(sequence)
        return sequences
    
    def pad_sequences(self, sequences: List[List[int]], maxlen: int, 
                     padding: str = 'post', truncating: str = 'post') -> np.ndarray:
        """Pad sequences to same length"""
        padded = np.zeros((len(sequences), maxlen), dtype=np.int32)
        
        for i, seq in enumerate(sequences):
            if len(seq) > maxlen:
                if truncating == 'post':
                    padded[i] = seq[:maxlen]
                else:
                    padded[i] = seq[-maxlen:]
            else:
                if padding == 'post':
                    padded[i, :len(seq)] = seq
                else:
                    padded[i, -len(seq):] = seq
        
        return padded
    
    def extract_ngrams(self, tokens: List[str], n: int = 2) -> List[tuple]:
        """Extract n-grams from tokens"""
        return [tuple(tokens[i:i+n]) for i in range(len(tokens)-n+1)]
    
    def calculate_tfidf(self, corpus: List[List[str]]) -> dict:
        """Calculate TF-IDF scores (simplified version)"""
        from collections import Counter
        
        doc_count = len(corpus)
        word_doc_count = Counter()
        
        for tokens in corpus:
            unique_tokens = set(tokens)
            for token in unique_tokens:
                word_doc_count[token] += 1
        
        tfidf_scores = {}
        for doc_idx, tokens in enumerate(corpus):
            token_counts = Counter(tokens)
            doc_tfidf = {}
            
            for token, count in token_counts.items():
                tf = count / len(tokens)
                idf = np.log(doc_count / (word_doc_count[token] + 1))
                doc_tfidf[token] = tf * idf
            
            tfidf_scores[doc_idx] = doc_tfidf
        
        return tfidf_scores
