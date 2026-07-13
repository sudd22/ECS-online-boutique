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

