resource "aws_fis_experiment_template" "network_blackhole" {
  description = "Isolate database egress by blackholing port 5432 for 10 minutes"
  role_arn    = aws_iam_role.fis_service_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "inject-blackhole"
    action_id = "aws:ecs:task-network-blackhole-port"

    parameter {
      key   = "port"
      value = "5432"
    }
    parameter {
      key   = "trafficType"
      value = "egress"
    }

    parameter {
      key   = "protocol"
      value = "tcp"
    }

    parameter {
      key   = "duration"
      value = "PT10M"
    }

    target {
      key   = "Tasks"
      value = "target-fargate-tasks"
    }
  }

  target {
    name           = "target-fargate-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "aws:ecs:service-name"
      value = var.ecs_service_name
    }
  }
}
