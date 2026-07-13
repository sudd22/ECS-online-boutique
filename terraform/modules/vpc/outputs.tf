output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "alb_sg" {
  value = aws_security_group.alb.id
}

output "ecs_tasks_sg" {
  value = aws_security_group.ecs_tasks.id
}

output "lambda_sg" {
  value = aws_security_group.lambda.id
}

output "rds_sg" {
  value = aws_security_group.nat_sg.id
}
