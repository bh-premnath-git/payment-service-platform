# Services Overview

## 📁 Current Structure

```
services/
├── common/                    # ✅ Shared library for all services
│   ├── auth.py               # WSO2 OAuth2 authentication
│   ├── config.py             # Base configuration classes
│   ├── models.py             # Shared Pydantic models
│   ├── logging.py            # Logging utilities
│   ├── middleware.py         # FastAPI middleware
│   ├── exceptions.py         # Error handling & exceptions
│   ├── utils.py              # Helper functions
│   ├── database.py           # Database utilities
│   ├── requirements.txt      # Dependencies
│   └── README.md             # Usage documentation
│
├── payment-service/          # ✅ Payment processing
│   └── app/
│       ├── main.py           # FastAPI app
│       ├── models.py         # Payment models
│       ├── auth.py           # Auth (can use common)
│       └── config.py         # Config (can use common)
│
├── auth-service/             # 🔨 TODO: User authentication & management
└── (future services)         # Order, Notification, Inventory, etc.
```

## 🎯 What is `services/common/`?

A **shared Python package** containing reusable code that ALL your microservices can import and use.

### What's Inside?

| Module | Purpose | Use Case |
|--------|---------|----------|
| `auth.py` | WSO2 OAuth2/JWT validation | All services need authentication |
| `config.py` | Base configuration classes | DRY configuration setup |
| `models.py` | Common Pydantic models | Health checks, errors, pagination |
| `logging.py` | Structured logging | Consistent logs across services |
| `middleware.py` | FastAPI middleware | Request IDs, timing, CORS |
| `exceptions.py` | Error handling | Standardized error responses |
| `utils.py` | Helper functions | ID generation, hashing, formatting |
| `database.py` | Database utilities | SQLAlchemy connection management |

## 🚀 How to Use in Your Services

### Step 1: Import Common Module

```python
# In your service (e.g., payment-service/app/main.py)
import sys
from pathlib import Path

# Add services/ directory to Python path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Now you can import!
from common.auth import WSO2AuthClient, create_oauth2_dependency
from common.models import HealthCheck
from common.config import BaseServiceConfig
from common.exceptions import register_exception_handlers
```

### Step 2: Use in Your Service

```python
from fastapi import FastAPI, Depends
from common.auth import create_oauth2_dependency, WSO2AuthClient

# Setup auth
auth_client = WSO2AuthClient(
    issuer_url="https://wso2is:9443/oauth2/token",
    jwks_url="https://wso2is:9443/oauth2/jwks",
    introspect_url="https://wso2is:9443/oauth2/introspect"
)

get_current_user = create_oauth2_dependency(auth_client)

# Use in protected endpoints
@app.get("/protected")
async def protected(user = Depends(get_current_user)):
    return {"user": user["username"]}
```

## 💡 Real Examples

### Example 1: Health Check (All Services)

```python
from common.models import HealthCheck, HealthStatus
from datetime import datetime

@app.get("/health", response_model=HealthCheck)
async def health():
    return HealthCheck(
        status=HealthStatus.HEALTHY,
        service_name="payment-service",
        version="1.0.0",
        timestamp=datetime.utcnow()
    )
```

### Example 2: Exception Handling (All Services)

```python
from common.exceptions import (
    register_exception_handlers,
    ResourceNotFoundError
)

app = FastAPI()
register_exception_handlers(app)  # One line!

@app.get("/payments/{payment_id}")
async def get_payment(payment_id: str):
    payment = find_payment(payment_id)
    if not payment:
        raise ResourceNotFoundError("Payment", payment_id)
    return payment
```

### Example 3: Configuration (All Services)

```python
from common.config import BaseServiceConfig

class PaymentConfig(BaseServiceConfig):
    SERVICE_NAME: str = "payment-service"
    # Inherits: OAUTH_ISSUER, OAUTH_JWKS_URL, etc.
    
    # Add payment-specific config
    STRIPE_API_KEY: str = ""
    DATABASE_URL: str = "postgresql://..."

settings = PaymentConfig()
```

## 🏗️ Future Services

You can easily create new services that reuse the common module:

### Auth Service (User Management)
```
services/auth-service/
├── app/
│   ├── main.py           # Uses common.auth
│   ├── models.py         # User models
│   └── routes/
│       ├── users.py
│       └── roles.py
├── Dockerfile
└── requirements.txt
```

### Order Service
```
services/order-service/
├── app/
│   ├── main.py           # Uses common.*
│   ├── models.py         # Order models
│   └── routes/
│       ├── orders.py
│       └── cart.py
├── Dockerfile
└── requirements.txt
```

### Notification Service
```
services/notification-service/
├── app/
│   ├── main.py           # Uses common.*
│   ├── channels/
│   │   ├── email.py
│   │   ├── sms.py
│   │   └── push.py
├── Dockerfile
└── requirements.txt
```

## ✅ Benefits

### 1. **No Code Duplication**
- Write authentication once, use everywhere
- Fix bugs in one place
- Maintain consistency

### 2. **Faster Development**
- Bootstrap new services in minutes
- No need to rewrite auth, logging, error handling
- Focus on business logic

### 3. **Consistency**
- All services use same patterns
- Same error response format
- Same logging format

### 4. **Easier Testing**
- Test shared code once
- Reduces test duplication

### 5. **Better Maintainability**
- Update common module, all services benefit
- Centralized improvements

## 🔄 Update Workflow

### To Update Common Module:
1. Edit files in `services/common/`
2. Test changes
3. Restart affected services (no reinstall needed)

### To Create New Service:
1. Copy service template
2. Import from `common/`
3. Add business logic
4. Deploy independently

## 📊 Service Communication Matrix

| Service | Uses Common Auth | Uses Common Config | Uses Common Models |
|---------|------------------|--------------------|--------------------|
| payment-service | ✅ | ✅ | ✅ |
| auth-service | ✅ | ✅ | ✅ |
| order-service | ✅ | ✅ | ✅ |
| notification-service | ✅ | ✅ | ✅ |

## 🎓 Quick Start Guide

### For Existing Services (e.g., payment-service):

1. **Add import path** (top of main.py):
   ```python
   import sys
   from pathlib import Path
   sys.path.insert(0, str(Path(__file__).parent.parent.parent))
   ```

2. **Replace custom code with common imports**:
   ```python
   # OLD
   from .auth import get_current_user
   
   # NEW
   from common.auth import create_oauth2_dependency, WSO2AuthClient
   auth_client = WSO2AuthClient(...)
   get_current_user = create_oauth2_dependency(auth_client)
   ```

3. **Test and deploy**

### For New Services:

1. **Create directory**: `services/my-service/`
2. **Copy template** from `MICROSERVICES_ARCHITECTURE.md`
3. **Import from common**: authentication, config, models, etc.
4. **Add business logic**: your unique service code
5. **Deploy**: add to `docker-compose.yml`

## 📚 Documentation

- `services/common/README.md` - Detailed common module docs
- `MICROSERVICES_ARCHITECTURE.md` - Full architecture guide
- `WSO2_DOCKER_SETUP.md` - Infrastructure setup

## 🤝 Contributing

When adding new shared utilities:

1. Add to appropriate file in `common/`
2. Update `common/README.md` with examples
3. Test with at least 2 services
4. Document any breaking changes

---

**Quick Wins:**
- ✅ Common module created with 8+ utilities
- ✅ Payment service can use it immediately
- ✅ Future services bootstrap in minutes
- ✅ No more code duplication

**Next Steps:**
- Refactor payment-service to use common module
- Create auth-service using common template
- Add more services as needed
