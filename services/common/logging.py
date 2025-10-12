"""
Shared logging configuration for all services
"""

import logging
import sys
from typing import Optional
import json
from datetime import datetime


class JSONFormatter(logging.Formatter):
    """JSON log formatter for structured logging"""
    
    def __init__(self, service_name: str):
        super().__init__()
        self.service_name = service_name
    
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "service": self.service_name,
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # Add extra fields
        if hasattr(record, "user_id"):
            log_data["user_id"] = record.user_id
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id
        
        return json.dumps(log_data)


def setup_logging(
    service_name: str,
    log_level: str = "INFO",
    use_json: bool = False
) -> logging.Logger:
    """
    Setup logging for a service
    
    Args:
        service_name: Name of the microservice
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR)
        use_json: Use JSON formatting (for production)
    
    Returns:
        Configured logger
    """
    logger = logging.getLogger(service_name)
    logger.setLevel(getattr(logging, log_level.upper()))
    
    # Clear existing handlers
    logger.handlers.clear()
    
    # Console handler
    handler = logging.StreamHandler(sys.stdout)
    
    if use_json:
        formatter = JSONFormatter(service_name)
    else:
        formatter = logging.Formatter(
            f'[%(asctime)s] [{service_name}] %(levelname)s - %(name)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
    
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    
    return logger


class RequestLogger:
    """Middleware-compatible request logger"""
    
    def __init__(self, logger: logging.Logger):
        self.logger = logger
    
    def log_request(
        self,
        method: str,
        path: str,
        status_code: int,
        duration_ms: float,
        user_id: Optional[str] = None
    ):
        """Log HTTP request"""
        log_data = {
            "method": method,
            "path": path,
            "status_code": status_code,
            "duration_ms": round(duration_ms, 2),
        }
        
        if user_id:
            log_data["user_id"] = user_id
        
        level = logging.INFO if status_code < 400 else logging.WARNING
        self.logger.log(level, f"{method} {path} - {status_code} - {duration_ms:.2f}ms")
