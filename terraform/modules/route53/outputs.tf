output "zone_id" {
  value       = data.aws_route53_zone.primary.zone_id
  description = "The Route 53 Zone ID"
}

output "app_fqdn_a" {
  value       = aws_route53_record.record_a.fqdn
  description = "The A record fully qualified domain name of the app"
}

output "name_servers" {
  value       = data.aws_route53_zone.primary.name_servers
  description = "The 4 Route 53 Name Servers for GoDaddy delegation"
}



