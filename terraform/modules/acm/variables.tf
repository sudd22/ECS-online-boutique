variable "env" {
  type        = string
  description = "Target deployment environment"
}

variable "domain_name" {
  type        = string
  description = "Root domain name for the certificate"
}

variable "route53_zone_id" {
  type        = string
  description = "The Route 53 hosted zone ID for DNS validation"
}
