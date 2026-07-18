resource "aws_iam_role" "fis_service_role" {
  name = "${var.env}-fis-experiment-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "fis_experiment_role_policy" {
  name = "${var.env}-fis-experiment-policy"
  role = aws_iam_role.fis_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters",
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets"
        ]
        Resource = "*"
        Effect   = "Allow"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "fis.amazonaws.com"
          }
        }
      }
    ]
  })
}

