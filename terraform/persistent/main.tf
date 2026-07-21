data "aws_caller_identity" "current" {}

provider "aws" {
  region = "eu-west-2"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_kms_key" "state" {
  description             = "KMS key for terraform state file and ECR images"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = {
    Environment = "presistent"
    Project     = "b2b-monolith"
  }

}

resource "aws_s3_bucket" "state" {
  bucket        = "b2b-monolith-tf-state-${random_string.suffix.result}"
  force_destroy = false
  tags = {
    Environment = "presistent"
    Project     = "b2b-monolith"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = "b2b-monolith-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Environment = "presistent"
    Project     = "b2b-monolith"
  }
}

resource "aws_ecr_repository" "app" {
  name                 = "b2b-monolith-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.state.arn
  }
  tags = {
    Environment = "presistent"
    Project     = "b2b-monolith"
  }
}

output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.locks.id
}

output "ecr_url" {
  value = aws_ecr_repository.app.repository_url
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:sudd22/ECS-online-boutique:*"]
    }
  }
}


resource "aws_iam_role" "ecr_push" {
  name               = "github-actions-ecr-push-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}


resource "aws_iam_role_policy" "ecr_push_policy" {
  name = "github-actions-ecr-push-policy"
  role = aws_iam_role.ecr_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]

        Resource = [
          "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/dev-b2b-cluster/dev-b2b-monolith-service",
          "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/prod-b2b-cluster/prod-b2b-monolith-service"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "tf_plan" {
  name               = "github-actions-tf-plan-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "tf_plan_state" {
  name = "github-actions-tf-plan-state"
  role = aws_iam_role.tf_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.locks.arn
      }
    ]
  })
}

resource "aws_iam_role" "tf_apply" {
  name               = "github-actions-tf-apply-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}


resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


resource "aws_iam_role" "tf_destroy" {
  name               = "github-actions-tf-destroy-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}


resource "aws_iam_role_policy_attachment" "tf_destroy_admin" {
  role       = aws_iam_role.tf_destroy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
