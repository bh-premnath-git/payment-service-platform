from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class PaymentCreate(BaseModel):
    amount: float = Field(..., gt=0, description="Payment amount")
    currency: str = Field(default="USD", max_length=3)
    description: Optional[str] = None
    customer_id: str

class PaymentResponse(BaseModel):
    id: str
    amount: float
    currency: str
    status: str
    created_at: datetime
    customer_id: str
    description: Optional[str] = None

class HealthCheck(BaseModel):
    status: str
    version: str
    timestamp: datetime