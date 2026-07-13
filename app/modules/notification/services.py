"""Notification record-keeping logic. Used by routes and the SQS consumer."""

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.notification.models import Notification


def record_notification(
    db: Session,
    *,
    event_type: str,
    order_id: int | None,
    payload: dict | None = None,
    channel: str = "email",
    status: str = "SENT",
) -> Notification:
    notification = Notification(
        event_type=event_type,
        order_id=order_id,
        channel=channel,
        status=status,
        payload=json.dumps(payload) if payload is not None else None,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


def list_notifications(db: Session, limit: int = 100) -> list[Notification]:
    stmt = select(Notification).order_by(Notification.id.desc()).limit(limit)
    return list(db.execute(stmt).scalars().all())
