variable "env" {
  type        = string
  description = "Target deployment environment"
}

variable "region" {
  type        = string
  default     = "eu-west-2"
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the ECS service tasks"
}

variable "ecs_tasks_sg_id" {
  type        = string
  description = "Security group ID for the ECS tasks"
}

variable "target_group_arn" {
  type        = string
  description = "ARN of the ALB target group"
}

variable "ecr_url" {
  type        = string
  description = "Repository URL of ECR"
}

variable "db_host" {
  type        = string
  description = "Postgres DB Host endpoint"
}

variable "db_username" {
  type        = string
  description = "Postgres DB Master Username"
}

variable "db_name" {
  type        = string
  description = "Postgres Database name"
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN containing DB password"
}

variable "notifications_queue_url" {
  type        = string
  description = "SQS notifications queue URL"
}

variable "notifications_queue_arn" {
  type        = string
  description = "SQS notifications queue ARN"
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Desired count of Fargate tasks"
}

variable "adot_image_tag" {
  type        = string
  default     = "v0.40.0"
  description = "AWS Otel Collector container image tag version"
}

variable "task_cpu" {
  type        = number
  default     = 512
  description = "Task level CPU allocation (units)"
}

variable "task_memory" {
  type        = number
  default     = 1024
  description = "Task level Memory allocation (MB)"
}

variable "app_cpu" {
  type        = number
  default     = 256
  description = "App container level CPU allocation (units)"
}

variable "app_memory" {
  type        = number
  default     = 768
  description = "App container level Memory allocation (MB)"
}

variable "adot_cpu" {
  type        = number
  default     = 256
  description = "ADOT container level CPU allocation (units)"
}

variable "adot_memory" {
  type        = number
  default     = 256
  description = "ADOT container level Memory allocation (MB)"
}
