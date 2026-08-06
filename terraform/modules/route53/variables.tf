variable "env" {
  type        = string
  description = "Target deployment environment"
}

variable "domain_name" {
  type        = string
  description = "Root domain name for the hosted zone"
}

variable "alb_dns_name" {
  type        = string
  description = "The DNS name of the ALB"
}

variable "alb_zone_id" {
  type        = string
  description = "The Zone ID of the ALB"
}
