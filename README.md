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