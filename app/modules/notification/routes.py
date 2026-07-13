"""Internal system management endpoints for the notification module.

These let operators inspect the outbound notification log and replay an event
through the same handler the SQS consumer uses (handy for local demos).
"""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.auth.models import User
from app.modules.notification import services

router = APIRouter()


class NotificationResponse(BaseModel):
    id: int
    event_type: str
    order_id: int | None
    channel: str
    status: str
    payload: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


@router.get("", response_model=list[NotificationResponse], tags=["notifications"])
async def list_notifications(
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[NotificationResponse]:
    """List recent outbound notifications (auth-protected internal view)."""
    return services.list_notifications(db, limit=limit)
