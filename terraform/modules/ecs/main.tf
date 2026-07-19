resource "aws_ecs_cluster" "main" {
  name = "${var.env}-b2b-cluster"

  tags = {
    Name = "${var.env}-b2b-cluster"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.env}-b2b-monolith-app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "adot" {
  name              = "/ecs/${var.env}-b2b-adot-sidecar"
  retention_in_days = 7
}


resource "aws_ecs_task_definition" "monolith" {
  family                   = "${var.env}-b2b-monolith"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  pid_mode                 = "task"
  enable_fault_injection   = true

  container_definitions = jsonencode([
    {
      name      = "monolith-app"
      image     = "${var.ecr_url}:latest"
      cpu       = var.app_cpu
      memory    = var.app_memory
      essential = true

      portMappings = [{
        containerPort = 8000
      }]

      environment = [
        { name = "OTEL_SERVICE_NAME", value = "b2b-monolith-${var.env}" },
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
        { name = "OTEL_TRACES_EXPORTER", value = "otlp" },
        { name = "OTEL_METRICS_EXPORTER", value = "otlp" },
        { name = "OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED", value = "true" },
        { name = "ENVIRONMENT", value = var.env },
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_PORT", value = "5432" },
        { name = "NOTIFICATIONS_QUEUE_URL", value = var.notifications_queue_url }
      ]

      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    },
    {
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:${var.adot_image_tag}"
      cpu       = var.adot_cpu
      memory    = var.adot_memory
      essential = false
      command   = ["--config=/etc/ecs/ecs-default-config.yaml"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.adot.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "otel"
        }
      }
    }
  ])
}


resource "aws_ecs_service" "main" {
  name                    = "${var.env}-b2b-monolith-service"
  cluster                 = aws_ecs_cluster.main.id
  task_definition         = aws_ecs_task_definition.monolith.arn
  desired_count           = var.desired_count
  launch_type             = "FARGATE"
  enable_execute_command  = true
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "monolith-app"
    container_port   = 8000
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = "${var.env}-b2b-monolith-service"
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.env}-b2b-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.env}-b2b-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn]
    }]
  })
}


resource "aws_iam_role" "ecs_task" {
  name = "${var.env}-b2b-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "adot_xray" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "adot_cloudwatch" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "task_sqs_publish" {
  name = "${var.env}-task-sqs-publish"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = [var.notifications_queue_arn]
    }]
  })
}
