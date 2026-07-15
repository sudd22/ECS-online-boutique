output "notifications_queue_url" {
  value = aws_sqs_queue.notifications.url
}

output "notifications_queue_arn" {
  value = aws_sqs_queue.notifications.arn
}
