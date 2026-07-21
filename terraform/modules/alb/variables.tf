variable "env" {
  type        = string
  description = "Deployment Enviorment"
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public Subnet Id Of the ALB"
}

variable "alb_sg" {
  type        = string
  description = "Security Group Id of ALB"
}
variable "acm_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM Certificate ARN"
}
