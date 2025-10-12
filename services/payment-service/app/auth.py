from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, HTTPBearer
from jose import JWTError, jwt
import httpx
from .config import settings

# OAuth2 scheme for token extraction
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.OAUTH_ISSUER}")
bearer_scheme = HTTPBearer()

async def get_jwks():
    """Fetch JWKS from WSO2 IS"""
    async with httpx.AsyncClient(verify=False) as client:
        response = await client.get(settings.OAUTH_JWKS_URL)
        return response.json()

async def verify_token_local(token: str):
    """Verify JWT token locally using JWKS"""
    try:
        jwks = await get_jwks()
        # Get the key from JWKS (simplified - production should handle key rotation)
        key = jwks['keys'][0]
        
        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            options={"verify_aud": False}
        )
        return payload
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token validation failed: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def verify_token_remote(token: str):
    """Verify token via WSO2 IS introspection endpoint"""
    async with httpx.AsyncClient(verify=False) as client:
        response = await client.post(
            settings.OAUTH_INTROSPECT_URL,
            data={"token": token},
            auth=("admin", "admin")  # Client credentials
        )
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token introspection failed"
            )
        
        result = response.json()
        if not result.get("active"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is not active"
            )
        
        return result

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Dependency to get current authenticated user"""
    # Use remote verification (checks revocation)
    user_info = await verify_token_remote(token)
    return user_info