"""
Shared FastAPI middleware components
"""

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.cors import CORSMiddleware
import time
import uuid
from typing import Callable
import logging


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Add unique request ID to each request"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        
        return response


class TimingMiddleware(BaseHTTPMiddleware):
    """Add timing information to responses"""
    
    def __init__(self, app, logger: logging.Logger = None):
        super().__init__(app)
        self.logger = logger
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.time()
        
        response = await call_next(request)
        
        duration_ms = (time.time() - start_time) * 1000
        response.headers["X-Process-Time"] = f"{duration_ms:.2f}ms"
        
        if self.logger:
            self.logger.info(
                f"{request.method} {request.url.path} - "
                f"Status: {response.status_code} - "
                f"Duration: {duration_ms:.2f}ms"
            )
        
        return response


class LoggingMiddleware(BaseHTTPMiddleware):
    """Log all requests and responses"""
    
    def __init__(self, app, logger: logging.Logger):
        super().__init__(app)
        self.logger = logger
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Log request
        self.logger.info(
            f"Request: {request.method} {request.url.path}",
            extra={
                "method": request.method,
                "path": request.url.path,
                "client": request.client.host if request.client else None,
            }
        )
        
        start_time = time.time()
        response = await call_next(request)
        duration = time.time() - start_time
        
        # Log response
        log_level = logging.INFO if response.status_code < 400 else logging.WARNING
        self.logger.log(
            log_level,
            f"Response: {request.method} {request.url.path} - "
            f"Status: {response.status_code} - "
            f"Duration: {duration * 1000:.2f}ms"
        )
        
        return response


def setup_cors_middleware(app, config):
    """Add CORS middleware with configuration"""
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_credentials=config.CORS_ALLOW_CREDENTIALS,
        allow_methods=config.CORS_ALLOW_METHODS,
        allow_headers=config.CORS_ALLOW_HEADERS,
    )
