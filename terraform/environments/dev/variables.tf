variable "region" {
  default     = "eu-west-2"
  type        = string
  description = "AWS Region"
}

variable "environment" {
  default     = "dev"
  type        = string
  description = "Environment Name"
}


variable "deploy_nat_gateway" {
  default     = false
  type        = bool
  description = "Toggle to deploy the NAT gateway (FinOps cost control)"
}
