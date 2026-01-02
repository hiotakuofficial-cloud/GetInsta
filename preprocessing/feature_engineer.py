"""
Feature Engineering utilities
"""
import numpy as np
import pandas as pd
from sklearn.preprocessing import PolynomialFeatures
from typing import List, Optional


class FeatureEngineer:
    """Create and transform features for ML models"""
    
    def __init__(self):
        self.poly_features = None
        self.feature_names = []
    
    def create_polynomial_features(self, X: np.ndarray, degree: int = 2, 
                                   include_bias: bool = False) -> np.ndarray:
        """Create polynomial features"""
        self.poly_features = PolynomialFeatures(degree=degree, include_bias=include_bias)
        X_poly = self.poly_features.fit_transform(X)
        self.feature_names = self.poly_features.get_feature_names_out()
        return X_poly
    
    def create_interaction_features(self, df: pd.DataFrame, 
                                   col_pairs: List[tuple]) -> pd.DataFrame:
        """Create interaction features between column pairs"""
        df_new = df.copy()
        for col1, col2 in col_pairs:
            if col1 in df.columns and col2 in df.columns:
                feature_name = f"{col1}_x_{col2}"
                df_new[feature_name] = df[col1] * df[col2]
        return df_new
    
    def create_binned_features(self, df: pd.DataFrame, column: str, 
                              bins: int = 5, labels: Optional[List] = None) -> pd.DataFrame:
        """Create binned/discretized features"""
        df_new = df.copy()
        if column in df.columns:
            bin_column = f"{column}_binned"
            df_new[bin_column] = pd.cut(df[column], bins=bins, labels=labels)
        return df_new
    
    def create_log_features(self, df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """Create log-transformed features"""
        df_new = df.copy()
        for col in columns:
            if col in df.columns:
                log_col = f"{col}_log"
                df_new[log_col] = np.log1p(df[col])
        return df_new
    
    def create_ratio_features(self, df: pd.DataFrame, 
                             numerator_cols: List[str], 
                             denominator_cols: List[str]) -> pd.DataFrame:
        """Create ratio features"""
        df_new = df.copy()
        for num_col in numerator_cols:
            for den_col in denominator_cols:
                if num_col in df.columns and den_col in df.columns:
                    ratio_col = f"{num_col}_div_{den_col}"
                    df_new[ratio_col] = df[num_col] / (df[den_col] + 1e-8)
        return df_new
    
    def create_aggregation_features(self, df: pd.DataFrame, 
                                   group_col: str, 
                                   agg_cols: List[str],
                                   agg_funcs: List[str] = ['mean', 'std', 'min', 'max']) -> pd.DataFrame:
        """Create aggregation features based on grouping"""
        df_new = df.copy()
        
        for agg_col in agg_cols:
            if agg_col in df.columns:
                for func in agg_funcs:
                    feature_name = f"{agg_col}_{func}_by_{group_col}"
                    agg_values = df.groupby(group_col)[agg_col].transform(func)
                    df_new[feature_name] = agg_values
        
        return df_new
    
    def create_datetime_features(self, df: pd.DataFrame, date_column: str) -> pd.DataFrame:
        """Extract features from datetime column"""
        df_new = df.copy()
        
        if date_column in df.columns:
            df_new[date_column] = pd.to_datetime(df_new[date_column])
            
            df_new[f"{date_column}_year"] = df_new[date_column].dt.year
            df_new[f"{date_column}_month"] = df_new[date_column].dt.month
            df_new[f"{date_column}_day"] = df_new[date_column].dt.day
            df_new[f"{date_column}_dayofweek"] = df_new[date_column].dt.dayofweek
            df_new[f"{date_column}_quarter"] = df_new[date_column].dt.quarter
            df_new[f"{date_column}_is_weekend"] = df_new[date_column].dt.dayofweek.isin([5, 6]).astype(int)
        
        return df_new
    
    def create_lag_features(self, df: pd.DataFrame, column: str, 
                           lags: List[int] = [1, 2, 3]) -> pd.DataFrame:
        """Create lag features for time series"""
        df_new = df.copy()
        
        if column in df.columns:
            for lag in lags:
                lag_col = f"{column}_lag_{lag}"
                df_new[lag_col] = df[column].shift(lag)
        
        return df_new
    
    def create_rolling_features(self, df: pd.DataFrame, column: str, 
                               windows: List[int] = [3, 7, 14],
                               agg_funcs: List[str] = ['mean', 'std']) -> pd.DataFrame:
        """Create rolling window features"""
        df_new = df.copy()
        
        if column in df.columns:
            for window in windows:
                for func in agg_funcs:
                    feature_name = f"{column}_rolling_{window}_{func}"
                    df_new[feature_name] = df[column].rolling(window=window).agg(func)
        
        return df_new
    
    def one_hot_encode(self, df: pd.DataFrame, columns: List[str], 
                      drop_first: bool = True) -> pd.DataFrame:
        """One-hot encode categorical variables"""
        return pd.get_dummies(df, columns=columns, drop_first=drop_first)
    
    def label_encode(self, df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """Label encode categorical variables"""
        df_new = df.copy()
        
        for col in columns:
            if col in df.columns:
                df_new[col] = pd.Categorical(df[col]).codes
        
        return df_new
