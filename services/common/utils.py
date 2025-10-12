"""
Shared utility functions
"""

import uuid
from datetime import datetime, timedelta
from typing import Optional, Any, Dict
import hashlib
import secrets


def generate_id(prefix: str = "") -> str:
    """Generate unique ID with optional prefix"""
    unique_id = str(uuid.uuid4())
    return f"{prefix}_{unique_id}" if prefix else unique_id


def generate_short_id(length: int = 8) -> str:
    """Generate short random ID"""
    return secrets.token_urlsafe(length)[:length]


def hash_string(value: str, algorithm: str = "sha256") -> str:
    """Hash a string using specified algorithm"""
    hash_obj = hashlib.new(algorithm)
    hash_obj.update(value.encode())
    return hash_obj.hexdigest()


def calculate_expiry(minutes: int = 60) -> datetime:
    """Calculate expiry datetime from now"""
    return datetime.utcnow() + timedelta(minutes=minutes)


def is_expired(expiry_time: datetime) -> bool:
    """Check if datetime has expired"""
    return datetime.utcnow() > expiry_time


def safe_get(data: Dict, key: str, default: Any = None) -> Any:
    """Safely get value from dict with default"""
    return data.get(key, default)


def mask_sensitive(value: str, show_chars: int = 4) -> str:
    """Mask sensitive data (e.g., credit cards, tokens)"""
    if not value or len(value) <= show_chars:
        return "*" * len(value) if value else ""
    
    return "*" * (len(value) - show_chars) + value[-show_chars:]


def format_currency(amount: float, currency: str = "USD") -> str:
    """Format amount as currency"""
    currency_symbols = {
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "INR": "₹",
    }
    symbol = currency_symbols.get(currency, currency)
    return f"{symbol}{amount:,.2f}"


class Paginator:
    """Helper class for pagination"""
    
    def __init__(self, page: int = 1, page_size: int = 20):
        self.page = max(1, page)
        self.page_size = min(max(1, page_size), 100)  # Max 100 items
    
    @property
    def offset(self) -> int:
        """Calculate offset for database query"""
        return (self.page - 1) * self.page_size
    
    @property
    def limit(self) -> int:
        """Get limit for database query"""
        return self.page_size
    
    def get_total_pages(self, total_items: int) -> int:
        """Calculate total pages"""
        return (total_items + self.page_size - 1) // self.page_size
