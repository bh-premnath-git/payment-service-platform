from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://wso2user:wso2pass@postgres:5432/wso2am_db"
    
    # WSO2 IS OAuth2 Configuration
    OAUTH_ISSUER: str = "https://wso2is:9443/oauth2/token"
    OAUTH_JWKS_URL: str = "https://wso2is:9443/oauth2/jwks"
    OAUTH_INTROSPECT_URL: str = "https://wso2is:9443/oauth2/introspect"
    
    # API Configuration
    API_PREFIX: str = "/api/v1"
    APP_NAME: str = "Payment Service"
    
    # DynamoDB Configuration (optional)
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    DYNAMODB_TABLE: str = "payments"
    
    class Config:
        env_file = ".env"

settings = Settings()