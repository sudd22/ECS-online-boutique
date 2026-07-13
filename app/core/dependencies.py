"""Shared authentication/security guards.

`get_current_user` validates the bearer JWT and resolves the User entity via
the auth service layer. Other module routers depend on this to enforce auth
without ever importing the auth tables for a cross-domain join.
"""

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth import services
from app.modules.auth.models import User

# tokenUrl points at the auth module's token endpoint so Swagger's Authorize
# button works out of the box.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

_CREDENTIALS_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = services.decode_access_token(token)
        subject = payload.get("sub")
        if subject is None:
            raise _CREDENTIALS_EXCEPTION
        user_id = int(subject)
    except (jwt.PyJWTError, ValueError, TypeError):
        raise _CREDENTIALS_EXCEPTION

    user = services.get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        raise _CREDENTIALS_EXCEPTION
    return user
