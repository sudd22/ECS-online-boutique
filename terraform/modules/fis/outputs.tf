output "ops_alarms_topic_arn" {
  description = "SNS topic for Chatbot human-in-the-loop alarm notifications"
  value       = aws_sns_topic.ops_alarms.arn
}

output "chatbot_channel_role_arn" {
  description = "IAM role Amazon Q Chatbot assumes in the Slack channel"
  value       = aws_iam_role.chatbot_channel_role.arn
}
