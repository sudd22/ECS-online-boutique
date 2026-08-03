resource "aws_iam_role" "ingestion_lambda_role" {
  name = "${var.env}-devops-agent-ingestion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ingestion_basic_execution" {
  role       = aws_iam_role.ingestion_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "ingestion_zip" {
  type        = "zip"
  output_path = "${path.module}/ingestion_payload.zip"

  source {
    content  = <<EOF
import json
import urllib.request
import datetime
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)
WEBHOOK_URL = os.environ['WEBHOOK_URL']
API_KEY = os.environ['API_KEY']

def lambda_handler(event, context):
    detail = event.get('detail', {})
    alarm_name = detail.get('alarmName', 'Unknown-Alarm')
    state = detail.get('state', {})
    state_value = state.get('value', 'ALARM')
    reason = state.get('reason', 'No reason provided')

    action = 'created'
    if state_value == 'OK':
        action = 'resolved'

    timestamp = datetime.datetime.utcnow().isoformat() + 'Z'

    payload = {
        "eventType": "incident",
        "incidentId": event.get('id', 'incident-123'),
        "action": action,
        "priority": "HIGH",
        "title": alarm_name,
        "description": reason,
        "timestamp": timestamp,
        "service": "b2b-monolith",
        "data": event
    }

    headers = {
        "Content-Type": "application/json",
        "x-amzn-event-timestamp": timestamp,
        "Authorization": f"Bearer {API_KEY}",
        "x-api-key": API_KEY,
    }

    req = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode('utf-8')
            logger.info("DevOps Agent webhook response: %s", res_body)
            return {
                "statusCode": 200,
                "body": res_body
            }
    except Exception as e:
        logger.error("Error posting to webhook: %s", e)
        if hasattr(e, 'read'):
            try:
                err_body = e.read().decode('utf-8')
                logger.error("Webhook error response body: %s", err_body)
            except Exception:
                pass
        raise
EOF
    filename = "ingestion_handler.py"
  }
}

resource "aws_lambda_function" "ingestion" {
  function_name = var.devops_agent_ingestion_lambda
  runtime       = "python3.11"
  handler       = "ingestion_handler.lambda_handler"
  role          = aws_iam_role.ingestion_lambda_role.arn
  filename      = data.archive_file.ingestion_zip.output_path

  environment {
    variables = {
      WEBHOOK_URL = var.devops_agent_webhook_url
      API_KEY     = var.devops_agent_api_key
    }
  }
}
