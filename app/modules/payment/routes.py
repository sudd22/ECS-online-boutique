import asyncio
import json
import logging
import os
import random
import uuid
from decimal import Decimal

import boto3
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.payment import services

logger = logging.getLogger("payment")

router = APIRouter()

NOTIFICATIONS_QUEUE_URL = os.getenv("NOTIFICATIONS_QUEUE_URL")
sqs_client = boto3.client("sqs", region_name=os.getenv("AWS_REGION", "eu-west-2"))

CHAOS_FAILURE_AMOUNT = 66.60


class PaymentRequest(BaseModel):
    order_id: int
    amount: Decimal


class PaymentResponse(BaseModel):
    status: str
    order_id: int
    amount: Decimal
    transaction_ref: str


def publish_notification(event_type: str, payload: dict) -> None:
    if not NOTIFICATIONS_QUEUE_URL:
        logger.info("No NOTIFICATIONS_QUEUE_URL configured; skipping publish of %s", event_type)
        return

    message = {"event_type": event_type, "payload": payload}
    try:
        sqs_client.send_message(
            QueueUrl=NOTIFICATIONS_QUEUE_URL,
            MessageBody=json.dumps(message),
        )
        logger.info("Published %s event to SQS", event_type)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Failed to publish %s event to SQS: %s", event_type, exc)


@router.post("/process", response_model=PaymentResponse, tags=["payments"])
async def process_payment(
    payload: PaymentRequest,
    db: Session = Depends(get_db),
) -> PaymentResponse:
    amount_float = float(payload.amount)

    if amount_float == CHAOS_FAILURE_AMOUNT:
        services.record_payment(
            db,
            order_id=payload.order_id,
            amount=payload.amount,
            status="FAILED",
            transaction_ref=None,
        )
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Simulated Gateway Error: Insufficient funds threshold met.",
        )

    await asyncio.sleep(random.uniform(0.5, 1.5))
    transaction_ref = f"txn_{uuid.uuid4().hex[:24]}"

    services.record_payment(
        db,
        order_id=payload.order_id,
        amount=payload.amount,
        status="SUCCESSFUL",
        transaction_ref=transaction_ref,
    )

    publish_notification(
        "payment.completed",
        {
            "order_id": payload.order_id,
            "amount": str(payload.amount),
            "transaction_ref": transaction_ref,
        },
    )

    return PaymentResponse(
        status="SUCCESSFUL",
        order_id=payload.order_id,
        amount=payload.amount,
        transaction_ref=transaction_ref,
    )
