"""
Shared Pydantic models used across services
"""

from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ===== Health Check Models =====

class HealthStatus(str, Enum):
    HEALTHY = "healthy"
    UNHEALTHY = "unhealthy"
    DEGRADED = "degraded"


class HealthCheck(BaseModel):
    """Standard health check response for all services"""
    status: HealthStatus
    service_name: str
    version: str
    timestamp: datetime
    database: Optional[str] = None  # "connected" | "disconnected"
    dependencies: Optional[dict] = None  # Status of external dependencies


# ===== User Models =====

class UserBase(BaseModel):
    """Base user model from WSO2 IS token"""
    username: str
    email: Optional[EmailStr] = None
    client_id: Optional[str] = None
    scopes: List[str] = []


class TokenData(BaseModel):
    """OAuth2 token data"""
    access_token: str
    token_type: str = "Bearer"
    expires_in: Optional[int] = None
    refresh_token: Optional[str] = None
    scope: Optional[str] = None


# ===== Standard API Response Models =====

class ErrorDetail(BaseModel):
    """Standard error response"""
    code: str
    message: str
    details: Optional[dict] = None


class ErrorResponse(BaseModel):
    """Standard error response wrapper"""
    error: ErrorDetail
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    path: Optional[str] = None


class SuccessResponse(BaseModel):
    """Generic success response"""
    success: bool = True
    message: str
    data: Optional[dict] = None


# ===== Pagination Models =====

class PaginationParams(BaseModel):
    """Standard pagination parameters"""
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)
    
    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


class PaginatedResponse(BaseModel):
    """Standard paginated response"""
    items: List[dict]
    total: int
    page: int
    page_size: int
    total_pages: int
    
    @classmethod
    def create(cls, items: List, total: int, page: int, page_size: int):
        """Helper to create paginated response"""
        total_pages = (total + page_size - 1) // page_size
        return cls(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages
        )


# ===== Audit/Logging Models =====

class AuditLog(BaseModel):
    """Standard audit log entry"""
    event_type: str
    user_id: Optional[str] = None
    resource: str
    action: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    ip_address: Optional[str] = None
    metadata: Optional[dict] = None
