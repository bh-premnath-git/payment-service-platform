"""
Shared exception handlers and custom exceptions
"""

from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from datetime import datetime
from typing import Union
import logging


# ===== Custom Exceptions =====

class ServiceException(Exception):
    """Base exception for service-specific errors"""
    
    def __init__(
        self,
        message: str,
        code: str = "SERVICE_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: dict = None
    ):
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details or {}
        super().__init__(self.message)


class AuthenticationError(ServiceException):
    """Authentication failed"""
    
    def __init__(self, message: str = "Authentication failed", details: dict = None):
        super().__init__(
            message=message,
            code="AUTHENTICATION_ERROR",
            status_code=status.HTTP_401_UNAUTHORIZED,
            details=details
        )


class AuthorizationError(ServiceException):
    """User not authorized"""
    
    def __init__(self, message: str = "Not authorized", details: dict = None):
        super().__init__(
            message=message,
            code="AUTHORIZATION_ERROR",
            status_code=status.HTTP_403_FORBIDDEN,
            details=details
        )


class ResourceNotFoundError(ServiceException):
    """Resource not found"""
    
    def __init__(self, resource: str, identifier: str):
        super().__init__(
            message=f"{resource} with ID '{identifier}' not found",
            code="RESOURCE_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
            details={"resource": resource, "id": identifier}
        )


class ValidationError(ServiceException):
    """Business validation error"""
    
    def __init__(self, message: str, field: str = None, details: dict = None):
        details = details or {}
        if field:
            details["field"] = field
        
        super().__init__(
            message=message,
            code="VALIDATION_ERROR",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            details=details
        )


class ExternalServiceError(ServiceException):
    """Error communicating with external service"""
    
    def __init__(self, service: str, message: str):
        super().__init__(
            message=f"Error from {service}: {message}",
            code="EXTERNAL_SERVICE_ERROR",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            details={"service": service}
        )


# ===== Exception Handlers =====

def create_error_response(
    code: str,
    message: str,
    status_code: int,
    path: str = None,
    details: dict = None
) -> JSONResponse:
    """Create standardized error response"""
    content = {
        "error": {
            "code": code,
            "message": message,
        },
        "timestamp": datetime.utcnow().isoformat(),
    }
    
    if path:
        content["path"] = path
    
    if details:
        content["error"]["details"] = details
    
    return JSONResponse(
        status_code=status_code,
        content=content
    )


async def service_exception_handler(request: Request, exc: ServiceException):
    """Handler for custom ServiceException"""
    return create_error_response(
        code=exc.code,
        message=exc.message,
        status_code=exc.status_code,
        path=str(request.url),
        details=exc.details
    )


async def http_exception_handler(request: Request, exc: HTTPException):
    """Handler for FastAPI HTTPException"""
    return create_error_response(
        code="HTTP_ERROR",
        message=exc.detail,
        status_code=exc.status_code,
        path=str(request.url)
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handler for request validation errors"""
    errors = []
    for error in exc.errors():
        errors.append({
            "field": ".".join(str(x) for x in error["loc"]),
            "message": error["msg"],
            "type": error["type"]
        })
    
    return create_error_response(
        code="VALIDATION_ERROR",
        message="Request validation failed",
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        path=str(request.url),
        details={"errors": errors}
    )


async def general_exception_handler(request: Request, exc: Exception):
    """Handler for unhandled exceptions"""
    logger = logging.getLogger("exception_handler")
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    
    return create_error_response(
        code="INTERNAL_ERROR",
        message="An internal error occurred",
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        path=str(request.url)
    )


def register_exception_handlers(app):
    """Register all exception handlers with FastAPI app"""
    app.add_exception_handler(ServiceException, service_exception_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, general_exception_handler)
