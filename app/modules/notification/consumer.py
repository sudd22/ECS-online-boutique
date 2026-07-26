import json
import logging
import os
import time

import boto3

from app.core.database import SessionLocal
from app.modules.notification import services

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("notification.consumer")

NOTIFICATIONS_QUEUE_URL = os.getenv("NOTIFICATIONS_QUEUE_URL")
AWS_REGION = os.getenv("AWS_REGION", "eu-west-2")

DLQ_SENTINEL_ORDER_ID = 999


def _process_body(body: dict) -> None:
    payload = body.get("payload", {}) or {}
    event_type = body.get("event_type", "unknown")
    order_id = payload.get("order_id")

    if order_id == DLQ_SENTINEL_ORDER_ID:
        raise RuntimeError("Simulated notification failure for order 999")

    db = SessionLocal()
    try:
        services.record_notification(
            db,
            event_type=event_type,
            order_id=order_id,
            payload=payload,
        )
    finally:
        db.close()

    logger.info(
        "Successfully processed %s notification for order_id=%s", event_type, order_id
    )


def lambda_handler(event, context):
    records = (event or {}).get("Records", [])
    processed = 0
    for record in records:
        raw_body = record.get("body", "{}")
        try:
            body = json.loads(raw_body)
        except (json.JSONDecodeError, TypeError):
            logger.warning("Skipping non-JSON message body: %r", raw_body)
            continue

        _process_body(body)
        processed += 1

    return {"processed": processed}


def run_polling_loop(poll_wait_seconds: int = 20) -> None:
    if not NOTIFICATIONS_QUEUE_URL:
        raise RuntimeError("NOTIFICATIONS_QUEUE_URL must be set to run the consumer loop.")

    sqs = boto3.client("sqs", region_name=AWS_REGION)
    logger.info("Starting SQS polling loop against %s", NOTIFICATIONS_QUEUE_URL)

    while True:
        response = sqs.receive_message(
            QueueUrl=NOTIFICATIONS_QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=poll_wait_seconds,
        )
        messages = response.get("Messages", [])
        if not messages:
            continue

        for message in messages:
            event = {"Records": [{"body": message.get("Body", "{}")}]}
            try:
                lambda_handler(event, None)
            except Exception as exc:  # noqa: BLE001
                logger.error("Processing failed, message left for retry/DLQ: %s", exc)
                continue

            sqs.delete_message(
                QueueUrl=NOTIFICATIONS_QUEUE_URL,
                ReceiptHandle=message["ReceiptHandle"],
            )

        time.sleep(0.1)


if __name__ == "__main__":
    run_polling_loop()
