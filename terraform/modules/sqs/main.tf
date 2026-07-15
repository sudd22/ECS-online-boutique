resource "aws_sqs_queue" "notifications_dlq" {
  name = "${var.env}-b2b-notifications-dlq"
}

resource "aws_sqs_queue" "notifications" {
  name = "${var.env}-b2b-notifications"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_function" "notification_consumer" {
  function_name = "${var.env}-b2b-notification-consumer"
  package_type  = "Image"
  image_uri     = "${var.ecr_url}:latest"
  role          = aws_iam_role.notification_consumer_role.arn
  timeout       = 30


  image_config {
    entry_point = ["/usr/local/bin/python", "-m", "awslambdaric"]
    command     = ["app.modules.notification.consumer.lambda_handler"]
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.consumer_lambda_sg_id]
  }

  environment {
    variables = {
      ENVIRONMENT   = var.env
      DB_HOST       = var.db_host
      DB_USER       = var.db_username
      DB_NAME       = var.db_name
      DB_PORT       = "5432"
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

}

resource "aws_lambda_event_source_mapping" "notification" {
  function_name    = aws_lambda_function.notification_consumer.function_name
  event_source_arn = aws_sqs_queue.notifications.arn
  batch_size       = 1
}

resource "aws_iam_role" "notification_consumer_role" {
  name = "${var.env}-b2b-notification-consumer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }

    }]
  })
}

resource "aws_iam_role_policy" "notification_consumer_policy" {
  name = "${var.env}-b2b-notification-consumer-policy"
  role = aws_iam_role.notification_consumer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.notifications.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      },

    ]

  })
}

resource "aws_iam_role_policy_attachment" "notification_consumer_vpc" {
  role       = aws_iam_role.notification_consumer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "notification_consumer_secret" {
  name = "${var.env}-b2b-notification-consumer-secret"
  role = aws_iam_role.notification_consumer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.db_secret_arn
    }]
  })
}

