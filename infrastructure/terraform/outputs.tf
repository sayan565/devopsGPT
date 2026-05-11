output "api_gateway_url" {
  description = "Base URL for the DevOpsGPT API Gateway"
  value       = "${aws_api_gateway_stage.devopsgpt.invoke_url}"
}

output "lambda_arns" {
  description = "ARNs of all Lambda functions"
  value = {
    cloudwatch_poller = aws_lambda_function.cloudwatch_poller.arn
    ai_analysis       = aws_lambda_function.ai_analysis.arn
    fix_executor      = aws_lambda_function.fix_executor.arn
    data_collector    = aws_lambda_function.data_collector.arn
  }
}

output "table_names" {
  description = "DynamoDB table names"
  value = {
    alerts      = aws_dynamodb_table.alerts.name
    metrics     = aws_dynamodb_table.metrics.name
    fix_history = aws_dynamodb_table.fix_history.name
    servers     = aws_dynamodb_table.servers.name
  }
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.devopsgpt.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS topic ARN for CRITICAL alerts"
  value       = aws_sns_topic.critical_alerts.arn
}

output "api_key_id" {
  description = "API Gateway key ID (retrieve value from AWS Console)"
  value       = aws_api_gateway_api_key.devopsgpt.id
}
