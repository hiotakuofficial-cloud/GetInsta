"""
Image Processing utilities for Computer Vision
"""
import numpy as np
import cv2
from PIL import Image
from typing import Tuple, Optional, List
from config import CV_CONFIG


class ImageProcessor:
    """Process and augment images for computer vision tasks"""
    
    def __init__(self, target_size: Tuple[int, int] = None):
        self.target_size = target_size or CV_CONFIG["image_size"]
    
    def load_image(self, image_path: str, color_mode: str = "rgb") -> np.ndarray:
        """Load image from file"""
        img = cv2.imread(image_path)
        
        if img is None:
            raise ValueError(f"Could not load image from {image_path}")
        
        if color_mode == "rgb":
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        elif color_mode == "gray":
            img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        return img
    
    def resize_image(self, image: np.ndarray, size: Optional[Tuple[int, int]] = None) -> np.ndarray:
        """Resize image to target size"""
        size = size or self.target_size
        return cv2.resize(image, size, interpolation=cv2.INTER_LINEAR)
    
    def normalize_image(self, image: np.ndarray, method: str = "standard") -> np.ndarray:
        """Normalize image pixel values"""
        image = image.astype(np.float32)
        
        if method == "standard":
            mean = CV_CONFIG["normalization_mean"]
            std = CV_CONFIG["normalization_std"]
            image = (image / 255.0 - mean) / std
        elif method == "minmax":
            image = image / 255.0
        elif method == "centered":
            image = (image - 127.5) / 127.5
        
        return image
    
    def augment_image(self, image: np.ndarray, augmentation_type: str) -> np.ndarray:
        """Apply image augmentation"""
        if augmentation_type == "flip_horizontal":
            return cv2.flip(image, 1)
        
        elif augmentation_type == "flip_vertical":
            return cv2.flip(image, 0)
        
        elif augmentation_type == "rotate_90":
            return cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
        
        elif augmentation_type == "rotate_180":
            return cv2.rotate(image, cv2.ROTATE_180)
        
        elif augmentation_type == "rotate_270":
            return cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)
        
        elif augmentation_type == "brightness":
            hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)
            hsv[:, :, 2] = cv2.add(hsv[:, :, 2], np.random.randint(-30, 30))
            return cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
        
        elif augmentation_type == "blur":
            return cv2.GaussianBlur(image, (5, 5), 0)
        
        elif augmentation_type == "noise":
            noise = np.random.normal(0, 25, image.shape).astype(np.uint8)
            return cv2.add(image, noise)
        
        return image
    
    def random_crop(self, image: np.ndarray, crop_size: Tuple[int, int]) -> np.ndarray:
        """Randomly crop image"""
        h, w = image.shape[:2]
        crop_h, crop_w = crop_size
        
        if h < crop_h or w < crop_w:
            return self.resize_image(image, crop_size)
        
        top = np.random.randint(0, h - crop_h)
        left = np.random.randint(0, w - crop_w)
        
        return image[top:top+crop_h, left:left+crop_w]
    
    def center_crop(self, image: np.ndarray, crop_size: Tuple[int, int]) -> np.ndarray:
        """Center crop image"""
        h, w = image.shape[:2]
        crop_h, crop_w = crop_size
        
        top = (h - crop_h) // 2
        left = (w - crop_w) // 2
        
        return image[top:top+crop_h, left:left+crop_w]
    
    def apply_random_augmentation(self, image: np.ndarray) -> np.ndarray:
        """Apply random augmentation from available options"""
        augmentations = [
            "flip_horizontal", "rotate_90", "brightness", "blur", "noise"
        ]
        aug_type = np.random.choice(augmentations)
        return self.augment_image(image, aug_type)
    
    def preprocess_batch(self, image_paths: List[str], 
                        augment: bool = False) -> np.ndarray:
        """Preprocess batch of images"""
        images = []
        
        for path in image_paths:
            img = self.load_image(path)
            img = self.resize_image(img)
            
            if augment:
                img = self.apply_random_augmentation(img)
            
            img = self.normalize_image(img)
            images.append(img)
        
        return np.array(images)
    
    def save_image(self, image: np.ndarray, output_path: str):
        """Save image to file"""
        if image.dtype == np.float32 or image.dtype == np.float64:
            image = (image * 255).astype(np.uint8)
        
        if len(image.shape) == 3 and image.shape[2] == 3:
            image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
        
        cv2.imwrite(output_path, image)
    
    def convert_to_grayscale(self, image: np.ndarray) -> np.ndarray:
        """Convert image to grayscale"""
        if len(image.shape) == 3:
            return cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        return image
    
    def detect_edges(self, image: np.ndarray, low_threshold: int = 50, 
                    high_threshold: int = 150) -> np.ndarray:
        """Detect edges using Canny edge detection"""
        gray = self.convert_to_grayscale(image)
        return cv2.Canny(gray, low_threshold, high_threshold)
    
    def apply_histogram_equalization(self, image: np.ndarray) -> np.ndarray:
        """Apply histogram equalization for contrast enhancement"""
        if len(image.shape) == 3:
            img_yuv = cv2.cvtColor(image, cv2.COLOR_RGB2YUV)
            img_yuv[:, :, 0] = cv2.equalizeHist(img_yuv[:, :, 0])
            return cv2.cvtColor(img_yuv, cv2.COLOR_YUV2RGB)
        else:
            return cv2.equalizeHist(image)
