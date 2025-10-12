# Common Service Library

Shared utilities and code for all microservices in the platform.

## 📦 What's Included

### 🔐 Authentication (`auth.py`)
- `WSO2AuthClient` - Reusable WSO2 IS OAuth2 client
- `create_oauth2_dependency()` - FastAPI OAuth2 dependency factory
- Token validation (local JWT and remote introspection)

### ⚙️ Configuration (`config.py`)
- `BaseServiceConfig` - Base settings class all services can extend
- `DatabaseConfig` - Database URL builders
- `AWSConfig` - AWS configuration

### 📋 Models (`models.py`)
- `HealthCheck` - Standard health check response
- `UserBase`, `TokenData` - User and token models
- `ErrorResponse`, `SuccessResponse` - Standard API responses
- `PaginatedResponse` - Pagination support

### 📝 Logging (`logging.py`)
- `setup_logging()` - Configure service logging
- `JSONFormatter` - Structured JSON logs for production
- `RequestLogger` - HTTP request logging

### 🔧 Middleware (`middleware.py`)
- `RequestIDMiddleware` - Add unique request IDs
- `TimingMiddleware` - Add timing headers
- `LoggingMiddleware` - Log all requests/responses

### ⚠️ Exceptions (`exceptions.py`)
- Custom exception classes
- Standardized error responses
- Pre-configured exception handlers

### 🛠️ Utilities (`utils.py`)
- ID generation
- Hashing and masking
- Currency formatting
- Pagination helper

### 🗄️ Database (`database.py`)
- `DatabaseManager` - SQLAlchemy connection manager
- `Base` - Base model for all tables

## 🚀 Usage Examples

### 1. Service Configuration

```python
# your_service/config.py
from services.common.config import BaseServiceConfig

class ServiceConfig(BaseServiceConfig):
    SERVICE_NAME: str = "payment-service"
    DATABASE_URL: str = "postgresql://user:pass@localhost/db"
    
    # Add service-specific config
    STRIPE_API_KEY: str = ""

settings = ServiceConfig()
```

### 2. Authentication

```python
# your_service/main.py
from fastapi import FastAPI, Depends
from services.common.auth import WSO2AuthClient, create_oauth2_dependency
from services.common.config import BaseServiceConfig

settings = BaseServiceConfig(SERVICE_NAME="my-service")

# Create auth client
auth_client = WSO2AuthClient(
    issuer_url=settings.OAUTH_ISSUER,
    jwks_url=settings.OAUTH_JWKS_URL,
    introspect_url=settings.OAUTH_INTROSPECT_URL
)

# Create FastAPI dependency
get_current_user = create_oauth2_dependency(auth_client)

app = FastAPI()

@app.get("/protected")
async def protected_route(user = Depends(get_current_user)):
    return {"user": user}
```

### 3. Health Check

```python
from services.common.models import HealthCheck, HealthStatus
from datetime import datetime

@app.get("/health", response_model=HealthCheck)
async def health():
    return HealthCheck(
        status=HealthStatus.HEALTHY,
        service_name=settings.SERVICE_NAME,
        version=settings.SERVICE_VERSION,
        timestamp=datetime.utcnow()
    )
```

### 4. Exception Handling

```python
from services.common.exceptions import (
    register_exception_handlers,
    ResourceNotFoundError,
    ValidationError
)

app = FastAPI()
register_exception_handlers(app)  # Register all handlers

@app.get("/items/{item_id}")
async def get_item(item_id: str):
    item = get_item_from_db(item_id)
    if not item:
        raise ResourceNotFoundError("Item", item_id)
    return item
```

### 5. Middleware

```python
from services.common.middleware import (
    RequestIDMiddleware,
    TimingMiddleware,
    setup_cors_middleware
)
from services.common.logging import setup_logging

logger = setup_logging("my-service")

app = FastAPI()
app.add_middleware(RequestIDMiddleware)
app.add_middleware(TimingMiddleware, logger=logger)
setup_cors_middleware(app, settings)
```

## 📥 Installation

Each service should add the common module to its Python path:

```python
# In your service's main.py or __init__.py
import sys
from pathlib import Path

# Add parent services directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

# Now you can import
from common.auth import WSO2AuthClient
```

Or use relative imports if services are packages:
```python
from ..common.auth import WSO2AuthClient
```

## 🏗️ Directory Structure

```
services/
├── common/                    # ← Shared library
│   ├── __init__.py
│   ├── auth.py               # Authentication
│   ├── config.py             # Configuration
│   ├── models.py             # Shared models
│   ├── logging.py            # Logging
│   ├── middleware.py         # Middleware
│   ├── exceptions.py         # Exceptions
│   ├── utils.py              # Utilities
│   └── database.py           # Database
│
├── payment-service/          # Uses common
├── auth-service/             # Uses common
├── order-service/            # Uses common
└── notification-service/     # Uses common
```

## ✅ Benefits

- **DRY**: Don't repeat authentication, logging, error handling in every service
- **Consistency**: All services use the same patterns
- **Maintainability**: Fix bugs once, benefit everywhere
- **Testing**: Shared code is tested once
- **Onboarding**: New services can be bootstrapped quickly

## 📝 Best Practices

1. **Import what you need**: Don't import entire modules
   ```python
   from common.auth import WSO2AuthClient  # Good
   from common import *  # Bad
   ```

2. **Extend base classes**: Don't modify common code in services
   ```python
   class MyConfig(BaseServiceConfig):  # Good
       pass
   ```

3. **Version compatibility**: Keep common library backward compatible
4. **Documentation**: Update this README when adding new utilities
