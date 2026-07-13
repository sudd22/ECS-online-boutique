"""SQS event consumer worker (Chaos-Testing Anchor #2).

Drains the notifications queue and persists an outbound log entry for each
event. Designed to run either as:
  * an AWS Lambda triggered by an SQS event source mapping, or
  * a long-running ECS/standalone poller (see `run_polling_loop`).

DLQ demo: order_id == 999 raises, so the message is retried and eventually
redriven to the Dead Letter Queue after maxReceiveCount=3.
"""

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

# DLQ demo sentinel: any event referencing this order id will crash the worker.
DLQ_SENTINEL_ORDER_ID = 999


def _process_body(body: dict) -> None:
    """Process a single decoded message body.

    Raises RuntimeError for the DLQ sentinel order so the message is retried
    and ultimately redriven to the configured Dead Letter Queue.
    """
    payload = body.get("payload", {}) or {}
    event_type = body.get("event_type", "unknown")
    order_id = payload.get("order_id")

    # --- DLQ Demo Sentinel Hook ----------------------------------------
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
    """AWS Lambda / SQS event-source-mapping entrypoint.

    Iterates over `Records`, decoding each SQS message body into JSON. A raised
    exception fails the batch so SQS can retry and eventually redrive to DLQ.
    """
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
    """Standalone long-poll loop for running the worker as an ECS service."""
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

        # Reuse the lambda_handler contract by shaping messages into Records.
        for message in messages:
            event = {"Records": [{"body": message.get("Body", "{}")}]}
            try:
                lambda_handler(event, None)
            except Exception as exc:  # noqa: BLE001 - leave msg for retry/DLQ
                logger.error("Processing failed, message left for retry/DLQ: %s", exc)
                continue

            # Only delete on success so failures are retried -> DLQ.
            sqs.delete_message(
                QueueUrl=NOTIFICATIONS_QUEUE_URL,
                ReceiptHandle=message["ReceiptHandle"],
            )

        time.sleep(0.1)


if __name__ == "__main__":
    run_polling_loop()
