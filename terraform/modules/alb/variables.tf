variable "env" {
  type        = string
  description = "Deployment Enviorment"
}

variable "public_subnet_ids" {
  type        = string
  description = "Public Subnet Id Of the ALB"
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
}

variable "alb_sg" {
  type        = string
  description = "Security Group Id of ALB"
}
