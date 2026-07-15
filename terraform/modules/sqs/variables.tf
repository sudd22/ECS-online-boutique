variable "env" {
  type        = string
  description = "Target deployment environment"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the Lambda consumer function"
}

variable "consumer_lambda_sg_id" {
  type        = string
  description = "Security Group ID for the Lambda consumer"
}

variable "db_host" {
  type        = string
  description = "Postgres Host endpoint"
}

variable "db_username" {
  type        = string
  description = "Postgres Master Username"
}

variable "db_name" {
  type        = string
  description = "Postgres Database Name"
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN containing DB password"
}

variable "ecr_url" {
  type        = string
  description = "ECR Repository URL (for consumer image)"
}
