resource "aws_sns_topic" "ops_alarms" {
  name = "${var.env}-b2b-ops-alarms"
}

resource "aws_sns_topic_policy" "ops_alarms" {
  arn = aws_sns_topic.ops_alarms.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudWatchAlarmsPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.ops_alarms.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_chatbot_slack_channel_configuration" "ops" {
  count = var.slack_workspace_id != "" && var.slack_channel_id != "" ? 1 : 0

  configuration_name = "${var.env}-b2b-ops-slack"
  iam_role_arn       = aws_iam_role.chatbot_channel_role.arn
  slack_team_id      = var.slack_workspace_id
  slack_channel_id   = var.slack_channel_id
  sns_topic_arns     = [aws_sns_topic.ops_alarms.arn]

  # Chatbot applies guardrails as a session policy. ReadOnlyAccess blocks Approve → Lambda invoke.
  guardrail_policy_arns = [
    aws_iam_policy.chatbot_allow_remediation.arn,
  ]
}

resource "aws_iam_policy" "chatbot_allow_remediation" {
  name = "${var.env}-chatbot-allow-remediation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowRemediationInvoke"
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [
        aws_lambda_function.remediation.arn,
        "${aws_lambda_function.remediation.arn}:*",
      ]
    }]
  })
}
