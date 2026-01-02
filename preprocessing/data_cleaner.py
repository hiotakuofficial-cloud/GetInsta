"""
Data Cleaning utilities
"""
import numpy as np
import pandas as pd
from typing import List, Optional, Union


class DataCleaner:
    """Handle missing values, outliers, and data quality issues"""
    
    def __init__(self):
        self.missing_strategies = {}
        self.outlier_bounds = {}
    
    def handle_missing_values(self, df: pd.DataFrame, strategy: str = "mean", 
                             columns: Optional[List[str]] = None) -> pd.DataFrame:
        """
        Handle missing values in dataframe
        
        Args:
            df: Input dataframe
            strategy: 'mean', 'median', 'mode', 'drop', 'forward_fill', 'backward_fill'
            columns: Specific columns to process (None = all columns)
        """
        df_clean = df.copy()
        cols = columns if columns else df_clean.columns
        
        for col in cols:
            if df_clean[col].isnull().any():
                if strategy == "mean":
                    df_clean[col].fillna(df_clean[col].mean(), inplace=True)
                elif strategy == "median":
                    df_clean[col].fillna(df_clean[col].median(), inplace=True)
                elif strategy == "mode":
                    df_clean[col].fillna(df_clean[col].mode()[0], inplace=True)
                elif strategy == "drop":
                    df_clean.dropna(subset=[col], inplace=True)
                elif strategy == "forward_fill":
                    df_clean[col].fillna(method='ffill', inplace=True)
                elif strategy == "backward_fill":
                    df_clean[col].fillna(method='bfill', inplace=True)
                
                self.missing_strategies[col] = strategy
        
        return df_clean
    
    def remove_duplicates(self, df: pd.DataFrame, subset: Optional[List[str]] = None) -> pd.DataFrame:
        """Remove duplicate rows"""
        return df.drop_duplicates(subset=subset, keep='first')
    
    def remove_outliers(self, df: pd.DataFrame, columns: List[str], 
                       method: str = "iqr", threshold: float = 1.5) -> pd.DataFrame:
        """
        Remove outliers using IQR or Z-score method
        
        Args:
            df: Input dataframe
            columns: Columns to check for outliers
            method: 'iqr' or 'zscore'
            threshold: IQR multiplier (default 1.5) or Z-score threshold (default 3)
        """
        df_clean = df.copy()
        
        for col in columns:
            if method == "iqr":
                Q1 = df_clean[col].quantile(0.25)
                Q3 = df_clean[col].quantile(0.75)
                IQR = Q3 - Q1
                lower_bound = Q1 - threshold * IQR
                upper_bound = Q3 + threshold * IQR
                
                self.outlier_bounds[col] = (lower_bound, upper_bound)
                df_clean = df_clean[(df_clean[col] >= lower_bound) & (df_clean[col] <= upper_bound)]
            
            elif method == "zscore":
                mean = df_clean[col].mean()
                std = df_clean[col].std()
                z_scores = np.abs((df_clean[col] - mean) / std)
                df_clean = df_clean[z_scores < threshold]
        
        return df_clean
    
    def convert_dtypes(self, df: pd.DataFrame, dtype_map: dict) -> pd.DataFrame:
        """Convert column data types"""
        df_clean = df.copy()
        for col, dtype in dtype_map.items():
            if col in df_clean.columns:
                df_clean[col] = df_clean[col].astype(dtype)
        return df_clean
    
    def clean_text_column(self, df: pd.DataFrame, column: str) -> pd.DataFrame:
        """Clean text data (remove extra spaces, lowercase, etc.)"""
        df_clean = df.copy()
        if column in df_clean.columns:
            df_clean[column] = df_clean[column].str.strip()
            df_clean[column] = df_clean[column].str.lower()
            df_clean[column] = df_clean[column].str.replace(r'\s+', ' ', regex=True)
        return df_clean
    
    def get_data_quality_report(self, df: pd.DataFrame) -> dict:
        """Generate data quality report"""
        report = {
            "total_rows": len(df),
            "total_columns": len(df.columns),
            "missing_values": df.isnull().sum().to_dict(),
            "missing_percentage": (df.isnull().sum() / len(df) * 100).to_dict(),
            "duplicates": df.duplicated().sum(),
            "dtypes": df.dtypes.to_dict()
        }
        return report
