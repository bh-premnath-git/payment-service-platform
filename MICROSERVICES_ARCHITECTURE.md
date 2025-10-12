# Microservices Architecture Guide

## 🏗️ Architecture Overview

Your platform follows a **microservices architecture** with a shared common library:

```
services/
├── common/                    # ← Shared utilities (reusable)
│   ├── auth.py               # WSO2 OAuth2 authentication
│   ├── config.py             # Base configuration
│   ├── models.py             # Common Pydantic models
│   ├── logging.py            # Logging utilities
│   ├── middleware.py         # FastAPI middleware
│   ├── exceptions.py         # Error handling
│   ├── utils.py              # Helper functions
│   └── database.py           # Database utilities
│
├── payment-service/          # Handles payments
├── auth-service/             # User auth & management (future)
├── order-service/            # Order processing (future)
└── notification-service/     # Notifications (future)
```

## ✅ Benefits of This Structure

### 1. **DRY Principle** (Don't Repeat Yourself)
- Write authentication logic **once** in `common/auth.py`
- All services import and use it
- Fix bugs in one place, benefit everywhere

### 2. **Consistency**
- All services use the same error responses
- Logging format is identical across services
- Health checks follow the same structure

### 3. **Faster Development**
- Bootstrap new services in minutes
- Copy service template, add business logic
- No need to rewrite auth, logging, etc.

### 4. **Easier Testing**
- Test shared code once
- Reduces test duplication
- Higher confidence in all services

## 📦 How Services Use Common Module

### Method 1: Add to Python Path (Recommended)

```python
# services/payment-service/app/main.py
import sys
from pathlib import Path

# Add parent services directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Now import from common
from common.auth import WSO2AuthClient, create_oauth2_dependency
from common.models import HealthCheck
from common.config import BaseServiceConfig
```

### Method 2: Relative Imports (if services is a package)

```python
# services/payment-service/app/main.py
from ...common.auth import WSO2AuthClient
from ...common.models import HealthCheck
```

## 🚀 Service Template

Here's a template for creating new services:

```python
# services/new-service/app/main.py
import sys
from pathlib import Path
from fastapi import FastAPI, Depends
from datetime import datetime

# Add common to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from common.auth import WSO2AuthClient, create_oauth2_dependency
from common.config import BaseServiceConfig
from common.models import HealthCheck, HealthStatus
from common.exceptions import register_exception_handlers
from common.middleware import RequestIDMiddleware, TimingMiddleware
from common.logging import setup_logging

# Configuration
class ServiceConfig(BaseServiceConfig):
    SERVICE_NAME: str = "new-service"
    # Add service-specific config here

settings = ServiceConfig()

# Logging
logger = setup_logging(settings.SERVICE_NAME, settings.LOG_LEVEL)

# FastAPI app
app = FastAPI(title=settings.SERVICE_NAME, version=settings.SERVICE_VERSION)

# Middleware
app.add_middleware(RequestIDMiddleware)
app.add_middleware(TimingMiddleware, logger=logger)

# Exception handlers
register_exception_handlers(app)

# Auth setup
auth_client = WSO2AuthClient(
    issuer_url=settings.OAUTH_ISSUER,
    jwks_url=settings.OAUTH_JWKS_URL,
    introspect_url=settings.OAUTH_INTROSPECT_URL
)
get_current_user = create_oauth2_dependency(auth_client)

# Routes
@app.get("/health", response_model=HealthCheck)
async def health():
    return HealthCheck(
        status=HealthStatus.HEALTHY,
        service_name=settings.SERVICE_NAME,
        version=settings.SERVICE_VERSION,
        timestamp=datetime.utcnow()
    )

@app.get("/api/v1/protected")
async def protected_endpoint(user = Depends(get_current_user)):
    return {"message": "Protected data", "user": user}
```

## 🔐 Authentication Flow

All services use the same authentication:

```
1. Client → Gets OAuth2 token from WSO2 IS
2. Client → Sends request to Service with token in header
3. Service → Uses common/auth.py to validate token
4. Service → Returns protected data if valid
```

### In Your Service:

```python
from common.auth import WSO2AuthClient, create_oauth2_dependency

# Setup once
auth_client = WSO2AuthClient(
    issuer_url="https://wso2is:9443/oauth2/token",
    jwks_url="https://wso2is:9443/oauth2/jwks",
    introspect_url="https://wso2is:9443/oauth2/introspect"
)

get_current_user = create_oauth2_dependency(auth_client)

# Use in routes
@app.get("/protected")
async def protected(user = Depends(get_current_user)):
    return {"username": user["username"]}
```

## 📊 Example: Refactoring Payment Service

### Before (Without Common Module):

```python
# payment-service/app/auth.py - 66 lines of code
# payment-service/app/config.py - 25 lines
# Duplicated in every service!
```

### After (With Common Module):

```python
# payment-service/app/main.py
from common.auth import create_oauth2_dependency
from common.config import BaseServiceConfig

class PaymentConfig(BaseServiceConfig):
    SERVICE_NAME: str = "payment-service"
    STRIPE_KEY: str = ""  # Service-specific

# Much cleaner, no duplication!
```

## 🗄️ Database Per Service Pattern

Each service can have its own database:

```
- payment-service   → payments_db (PostgreSQL)
- auth-service      → auth_db (PostgreSQL)  
- order-service     → orders_db (PostgreSQL)
- inventory-service → inventory_db (DynamoDB)
```

### Using Common Database Utils:

```python
from common.database import DatabaseManager

db_manager = DatabaseManager(
    database_url="postgresql://user:pass@localhost/payments_db"
)

# Use in FastAPI
@app.get("/items")
def get_items(db = Depends(db_manager.get_db)):
    return db.query(Item).all()
```

## 🔄 Service Communication

Services communicate via:

1. **HTTP/REST** - For synchronous calls
2. **Message Queue** - For async events (future: RabbitMQ/Kafka)
3. **API Gateway** - WSO2 APIM routes external requests

### Example: Payment Service calling Notification Service

```python
import httpx
from common.auth import WSO2AuthClient

async def notify_payment_success(payment_id: str):
    # Get service-to-service token
    auth_client = WSO2AuthClient(...)
    token = await auth_client.get_token(
        client_id="payment-service",
        client_secret="secret"
    )
    
    # Call notification service
    async with httpx.AsyncClient() as client:
        await client.post(
            "http://notification-service/api/v1/notify",
            json={"payment_id": payment_id, "type": "payment_success"},
            headers={"Authorization": f"Bearer {token['access_token']}"}
        )
```

## 📝 Service Development Checklist

When creating a new service:

- [ ] Create service directory: `services/my-service/`
- [ ] Add `Dockerfile`
- [ ] Add `requirements.txt` (include common dependencies)
- [ ] Import from `common/` for auth, logging, etc.
- [ ] Extend `BaseServiceConfig` for configuration
- [ ] Implement `/health` endpoint using `HealthCheck` model
- [ ] Register exception handlers from `common/exceptions.py`
- [ ] Add service to `docker-compose.yml`
- [ ] Document service-specific APIs

## 🧪 Testing Strategy

### Unit Tests
Test service-specific business logic

### Integration Tests  
Test service with real database and WSO2 IS

### Contract Tests
Test service-to-service communication

### Shared Code Tests
Test `common/` module separately - benefits all services

## 📦 Deployment

Each service is deployed independently:

```yaml
# docker-compose.yml
services:
  payment-service:
    build: ./services/payment-service
    ports:
      - "8001:8000"
  
  order-service:
    build: ./services/order-service
    ports:
      - "8002:8000"
```

## 🎯 Best Practices

### 1. Keep Services Small
- Single Responsibility Principle
- One service = One business capability

### 2. Use Common Module Wisely
- ✅ DO: Use for auth, logging, error handling
- ❌ DON'T: Put business logic in common module

### 3. Service Independence
- Each service should be deployable independently
- Minimize tight coupling between services

### 4. Configuration
- Use environment variables
- Extend `BaseServiceConfig` from common
- Never hardcode secrets

### 5. Versioning
- Use API versioning (`/api/v1/`, `/api/v2/`)
- Version common module when making breaking changes

## 📚 Further Reading

- `services/common/README.md` - Common module documentation
- `WSO2_DOCKER_SETUP.md` - WSO2 IS and APIM setup
- FastAPI docs: https://fastapi.tiangolo.com/
- Microservices patterns: https://microservices.io/patterns/

---

**Architecture Version:** 1.0  
**Last Updated:** Oct 12, 2025
