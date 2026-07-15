variable "env" {
  type        = string
  description = "Target deployment environment"
}

variable "resource_arn" {
  type        = string
  description = "The ARN of the resource to associate the Web ACL with (ALB ARN)"
}
