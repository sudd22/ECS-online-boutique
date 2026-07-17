resource "aws_iam_role" "chatbot_channel_role" {
  name = "${var.env}-devops-chatbot-channel-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "chatbot.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "chatbot_invoke_remediation" {
  name = "${var.env}-chatbot-invoke-remediation"
  role = aws_iam_role.chatbot_channel_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.remediation.arn
    }]
  })
}
