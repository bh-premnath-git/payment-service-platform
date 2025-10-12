from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .auth import get_current_user
from .models import PaymentCreate, PaymentResponse, HealthCheck
from .config import settings
from datetime import datetime
import uuid

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="Payment Processing API secured with WSO2 IS OAuth2"
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint (public)
@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Public health check endpoint"""
    return HealthCheck(
        status="healthy",
        version="1.0.0",
        timestamp=datetime.utcnow()
    )

# Protected endpoints
@app.post(f"{settings.API_PREFIX}/payments", response_model=PaymentResponse)
async def create_payment(
    payment: PaymentCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    Create a new payment (Protected endpoint)
    Requires valid OAuth2 token from WSO2 IS
    """
    # In production, save to PostgreSQL/DynamoDB
    payment_id = str(uuid.uuid4())
    
    return PaymentResponse(
        id=payment_id,
        amount=payment.amount,
        currency=payment.currency,
        status="pending",
        created_at=datetime.utcnow(),
        customer_id=payment.customer_id,
        description=payment.description
    )

@app.get(f"{settings.API_PREFIX}/payments/{{payment_id}}", response_model=PaymentResponse)
async def get_payment(
    payment_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Get payment by ID (Protected endpoint)
    """
    # In production, fetch from database
    return PaymentResponse(
        id=payment_id,
        amount=100.00,
        currency="USD",
        status="completed",
        created_at=datetime.utcnow(),
        customer_id="cust_123",
        description="Sample payment"
    )

@app.get(f"{settings.API_PREFIX}/user/profile")
async def get_user_profile(current_user: dict = Depends(get_current_user)):
    """
    Get current user profile from token (Protected endpoint)
    """
    return {
        "username": current_user.get("username"),
        "scopes": current_user.get("scope", "").split(),
        "token_type": current_user.get("token_type"),
        "client_id": current_user.get("client_id")
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)