"""Auth HTTP endpoints: registration and JWT token issuance."""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth import services

router = APIRouter()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    tenant_id: int

    model_config = {"from_attributes": True}


@router.post("/token", response_model=TokenResponse, tags=["auth"])
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
) -> TokenResponse:
    """OAuth2 password-flow token endpoint (Swagger "Authorize" compatible)."""
    user = services.authenticate_user(db, form_data.username, form_data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(access_token=services.create_access_token(user))


@router.post("/login", response_model=TokenResponse, tags=["auth"])
async def login_json(
    payload: LoginRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """JSON-body login alternative for SPA / API clients."""
    user = services.authenticate_user(db, payload.email, payload.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    return TokenResponse(access_token=services.create_access_token(user))
