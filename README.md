┌─────────────────┐
│  Python APIs    │  ← Your FastAPI/Flask microservices
│  (FastAPI)      │
└────────┬────────┘
         │
    ┌────▼─────────────────────────────┐
    │   WSO2 API Manager 4.4.0         │
    │   - API Gateway                   │
    │   - Publisher Portal             │
    │   - Developer Portal             │
    │   - Rate Limiting               │
    └─────────┬──────────────────────┘
              │
    ┌─────────▼───────────────────────┐
    │   WSO2 Identity Server 7.0.0   │
    │   - OAuth2 Token Generation     │
    │   - JWT Validation              │
    │   - User Management             │
    └─────────┬──────────────────────┘
              │
    ┌─────────▼──────┬─────────────┐
    │  PostgreSQL    │  DynamoDB   │
    │  - User Data   │  - App Data │
    │  - APIM Data   │            │
    └────────────────┴─────────────┘
----------------------------
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