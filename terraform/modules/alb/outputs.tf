output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The DNS name of the Application Load Balancer"
}
output "target_group_arn" {
  value       = aws_lb_target_group.app.arn
  description = "The ARN of the ALB target group"
}
output "alb_arn" {
  value       = aws_lb.main.arn
  description = "The ARN of the ALB"
}

output "alb_zone_id" {
  value       = aws_lb.main.zone_id
  description = "The Zone ID of the Application Load Balancer"
}
