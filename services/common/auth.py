"""
Shared authentication utilities for WSO2 IS OAuth2/JWT
Can be used by all microservices
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, HTTPBearer
from jose import JWTError, jwt
import httpx
from typing import Dict, Optional
from functools import lru_cache


class WSO2AuthClient:
    """Reusable WSO2 IS authentication client"""
    
    def __init__(
        self,
        issuer_url: str,
        jwks_url: str,
        introspect_url: str,
        verify_ssl: bool = False
    ):
        self.issuer_url = issuer_url
        self.jwks_url = jwks_url
        self.introspect_url = introspect_url
        self.verify_ssl = verify_ssl
        self._jwks_cache: Optional[Dict] = None
    
    @lru_cache(maxsize=1)
    async def get_jwks(self) -> Dict:
        """Fetch and cache JWKS from WSO2 IS"""
        async with httpx.AsyncClient(verify=self.verify_ssl) as client:
            response = await client.get(self.jwks_url, timeout=10.0)
            response.raise_for_status()
            return response.json()
    
    async def verify_token_local(self, token: str) -> Dict:
        """
        Verify JWT token locally using JWKS
        Faster but doesn't check token revocation
        """
        try:
            jwks = await self.get_jwks()
            
            # Get the signing key (handle multiple keys in production)
            if not jwks.get('keys'):
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="No keys found in JWKS"
                )
            
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
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Authentication error: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )
    
    async def verify_token_remote(
        self,
        token: str,
        client_id: str = "admin",
        client_secret: str = "admin"
    ) -> Dict:
        """
        Verify token via WSO2 IS introspection endpoint
        Slower but checks token revocation status
        """
        try:
            async with httpx.AsyncClient(verify=self.verify_ssl) as client:
                response = await client.post(
                    self.introspect_url,
                    data={"token": token},
                    auth=(client_id, client_secret),
                    timeout=10.0
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
                        detail="Token is not active or has been revoked"
                    )
                
                return result
                
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Cannot reach authentication service: {str(e)}"
            )
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token verification failed: {str(e)}"
            )
    
    async def get_token(
        self,
        client_id: str,
        client_secret: str,
        grant_type: str = "client_credentials",
        scope: Optional[str] = None
    ) -> Dict:
        """Get OAuth2 token from WSO2 IS"""
        data = {
            "grant_type": grant_type,
            "client_id": client_id,
            "client_secret": client_secret,
        }
        
        if scope:
            data["scope"] = scope
        
        async with httpx.AsyncClient(verify=self.verify_ssl) as client:
            response = await client.post(
                self.issuer_url,
                data=data,
                timeout=10.0
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Failed to obtain access token"
                )
            
            return response.json()


def create_oauth2_dependency(
    auth_client: WSO2AuthClient,
    use_remote_validation: bool = True
):
    """
    Factory function to create FastAPI OAuth2 dependency
    
    Usage:
        auth_client = WSO2AuthClient(...)
        get_current_user = create_oauth2_dependency(auth_client)
        
        @app.get("/protected")
        async def protected_route(user = Depends(get_current_user)):
            return user
    """
    oauth2_scheme = OAuth2PasswordBearer(tokenUrl=auth_client.issuer_url)
    
    async def get_current_user(token: str = Depends(oauth2_scheme)) -> Dict:
        """Dependency to get current authenticated user"""
        if use_remote_validation:
            # Remote validation - checks revocation but slower
            return await auth_client.verify_token_remote(token)
        else:
            # Local validation - faster but doesn't check revocation
            return await auth_client.verify_token_local(token)
    
    return get_current_user


def create_bearer_dependency(auth_client: WSO2AuthClient):
    """
    Create Bearer token dependency (alternative to OAuth2)
    
    Usage:
        auth_client = WSO2AuthClient(...)
        get_bearer_token = create_bearer_dependency(auth_client)
        
        @app.get("/protected")
        async def protected_route(token_data = Depends(get_bearer_token)):
            return token_data
    """
    bearer_scheme = HTTPBearer()
    
    async def verify_bearer_token(credentials = Depends(bearer_scheme)) -> Dict:
        """Verify Bearer token"""
        return await auth_client.verify_token_remote(credentials.credentials)
    
    return verify_bearer_token
