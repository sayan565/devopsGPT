# ── Log Groups (30-day retention) ────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "cloudwatch_poller" {
  name              = "/aws/lambda/${local.prefix}-cloudwatch-poller"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "ai_analysis" {
  name              = "/aws/lambda/${local.prefix}-ai-analysis"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "fix_executor" {
  name              = "/aws/lambda/${local.prefix}-fix-executor"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "data_collector" {
  name              = "/aws/lambda/${local.prefix}-data-collector"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_errors_cloudwatch_poller" {
  alarm_name          = "${local.prefix}-cloudwatch-poller-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "cloudwatch_poller Lambda error rate too high"
  alarm_actions       = [aws_sns_topic.critical_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.cloudwatch_poller.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors_ai_analysis" {
  alarm_name          = "${local.prefix}-ai-analysis-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "ai_analysis Lambda error rate too high"
  alarm_actions       = [aws_sns_topic.critical_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.ai_analysis.function_name
  }

  tags = local.common_tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "devopsgpt" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Invocations"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName",
             "${local.prefix}-cloudwatch-poller"],
            ["AWS/Lambda", "Invocations", "FunctionName",
             "${local.prefix}-ai-analysis"],
            ["AWS/Lambda", "Invocations", "FunctionName",
             "${local.prefix}-fix-executor"],
            ["AWS/Lambda", "Invocations", "FunctionName",
             "${local.prefix}-data-collector"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName",
             "${local.prefix}-cloudwatch-poller"],
            ["AWS/Lambda", "Errors", "FunctionName",
             "${local.prefix}-ai-analysis"],
            ["AWS/Lambda", "Errors", "FunctionName",
             "${local.prefix}-fix-executor"],
            ["AWS/Lambda", "Errors", "FunctionName",
             "${local.prefix}-data-collector"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration (ms)"
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName",
             "${local.prefix}-cloudwatch-poller"],
            ["AWS/Lambda", "Duration", "FunctionName",
             "${local.prefix}-ai-analysis"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB Read/Write Capacity"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits",
             "TableName", "${local.prefix}-alerts"],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits",
             "TableName", "${local.prefix}-metrics"],
          ]
        }
      },
    ]
  })
}
