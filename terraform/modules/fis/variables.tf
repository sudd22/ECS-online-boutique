variable "env" {
  type        = string
  description = "environment name"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name"
}

variable "devops_agent_ingestion_lambda" {
  type        = string
  default     = "devops-agent-ingestion"
  description = "The name of the DevOps Agent webhook for the ingestion Lambda function"
}
