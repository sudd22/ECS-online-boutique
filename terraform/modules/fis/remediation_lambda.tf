data "archive_file" "remediation_zip" {
  type        = "zip"
  source_file = "${path.module}/scripts/remediation_handler.py"
  output_path = "${path.module}/lambda_payload.zip"
}

resource "aws_lambda_function" "remediation" {
  function_name    = "${var.env}-devops-agent-remediation"
  handler          = "remediation_handler.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.remediation_lambda_role.arn
  filename         = data.archive_file.remediation_zip.output_path
  source_code_hash = data.archive_file.remediation_zip.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_NAME = var.ecs_cluster_name
      ECS_SERVICE_NAME = var.ecs_service_name
    }
  }
}
