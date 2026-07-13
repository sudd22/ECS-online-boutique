output "db_secret_arn" {
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
  description = "ARN of Secrets Manager secret containing database master password"
}

output "db_host" {
  value       = aws_db_instance.main.address
  description = "Host endpoint of RDS cluster"
}
