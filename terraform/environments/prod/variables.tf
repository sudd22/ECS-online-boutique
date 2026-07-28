variable "region" {
  type        = string
  description = "AWS Region"
  default     = "eu-west-2"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Target environment name"
}

variable "deploy_nat_gateway" {
  type        = bool
  default     = true
  description = "Toggle to deploy the NAT gateway"
}

variable "domain_name" {
  type        = string
  default     = "seudd.online"
  description = "Production root domain name"
}

