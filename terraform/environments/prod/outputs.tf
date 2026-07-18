output "environment" {
  value       = var.environment
  description = "The Deployment Environment"
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Public ingress URL for the storefront and API docs"
}
