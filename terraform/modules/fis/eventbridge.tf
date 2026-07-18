resource "aws_cloudwatch_event_rule" "fis_anomaly_trigger" {
  name        = "${var.env}-devops-agent-anomaly-trigger"
  description = "Triggers AWS DevOps Agent investigation on CloudWatch Anomaly Alarms"
  event_pattern = jsonencode({
    "source" : ["aws.cloudwatch"],
    "detail-type" : ["CloudWatch Alarm State Change"],
    "detail" : {
      "alarmName" : [{ "prefix" : "${var.env}-b2b-monolith-" }],
      "state" : { "value" : ["ALARM"] }

    }
  })
}

resource "aws_cloudwatch_event_target" "devops_agent_target" {
  rule      = aws_cloudwatch_event_rule.fis_anomaly_trigger.name
  target_id = "TriggerDevOpsAgent Ingestion"
  arn       = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.devops_agent_ingestion_lambda}"
}

resource "aws_lambda_permission" "allow_eventbridge_ingestion" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  function_name = var.devops_agent_ingestion_lambda
  source_arn    = aws_cloudwatch_event_rule.fis_anomaly_trigger.arn


}
