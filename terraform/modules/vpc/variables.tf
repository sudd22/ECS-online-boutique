variable "env" {
  type        = string
  description = "Environment Name"
}

variable "deploy_nat_gateway" {
  type        = bool
  description = "Toggle to deploy the NAT gateway (FinOps cost control)"
}
