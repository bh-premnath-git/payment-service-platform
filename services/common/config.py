"""
Shared configuration base classes
All services can extend these base classes
"""

from pydantic_settings import BaseSettings
from typing import Optional


class BaseServiceConfig(BaseSettings):
    """Base configuration that all services can extend"""
    
    # Service Info
    SERVICE_NAME: str
    SERVICE_VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"
    
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    
    # WSO2 IS OAuth2 Configuration (shared across all services)
    OAUTH_ISSUER: str = "https://wso2is:9443/oauth2/token"
    OAUTH_JWKS_URL: str = "https://wso2is:9443/oauth2/jwks"
    OAUTH_INTROSPECT_URL: str = "https://wso2is:9443/oauth2/introspect"
    OAUTH_VERIFY_SSL: bool = False
    
    # Use remote token validation (checks revocation) or local (faster)
    USE_REMOTE_TOKEN_VALIDATION: bool = True
    
    # Database Configuration (optional - services can override)
    DATABASE_URL: Optional[str] = None
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20
    
    # Redis Configuration (optional - for caching/sessions)
    REDIS_URL: Optional[str] = None
    
    # CORS Configuration
    CORS_ORIGINS: list = ["*"]
    CORS_ALLOW_CREDENTIALS: bool = True
    CORS_ALLOW_METHODS: list = ["*"]
    CORS_ALLOW_HEADERS: list = ["*"]
    
    # Logging
    LOG_LEVEL: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


class DatabaseConfig:
    """Shared database configuration helpers"""
    
    @staticmethod
    def get_postgres_url(
        user: str,
        password: str,
        host: str,
        port: int,
        database: str
    ) -> str:
        """Build PostgreSQL connection URL"""
        return f"postgresql://{user}:{password}@{host}:{port}/{database}"
    
    @staticmethod
    def get_postgres_async_url(
        user: str,
        password: str,
        host: str,
        port: int,
        database: str
    ) -> str:
        """Build async PostgreSQL connection URL"""
        return f"postgresql+asyncpg://{user}:{password}@{host}:{port}/{database}"


class AWSConfig(BaseSettings):
    """Shared AWS configuration for services using DynamoDB/S3"""
    
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    
    class Config:
        env_file = ".env"
