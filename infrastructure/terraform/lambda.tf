# ── cloudwatch_poller Lambda ──────────────────────────────────────────────────
resource "aws_lambda_function" "cloudwatch_poller" {
  function_name = "${local.prefix}-cloudwatch-poller"
  role          = aws_iam_role.cloudwatch_poller.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  memory_size   = 256
  timeout       = 300

  # Placeholder — replaced by CI/CD deploy step
  filename      = "${path.module}/../../modules/lambda/zips/cloudwatch_poller.zip"

  environment {
    variables = {
      ALERTS_TABLE     = aws_dynamodb_table.alerts.name
      METRICS_TABLE    = aws_dynamodb_table.metrics.name
      SNS_TOPIC_ARN    = aws_sns_topic.critical_alerts.arn
      CPU_THRESHOLD    = tostring(var.cpu_threshold)
      MEMORY_THRESHOLD = tostring(var.memory_threshold)
    }
  }

  depends_on = [
    aws_iam_role_policy.cloudwatch_poller,
    aws_cloudwatch_log_group.cloudwatch_poller,
  ]

  tags = local.common_tags
}

# ── ai_analysis Lambda ────────────────────────────────────────────────────────
resource "aws_lambda_function" "ai_analysis" {
  function_name = "${local.prefix}-ai-analysis"
  role          = aws_iam_role.ai_analysis.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  memory_size   = 512
  timeout       = 180

  filename = "${path.module}/../../modules/lambda/zips/ai_analysis.zip"

  environment {
    variables = {
      FIX_HISTORY_TABLE = aws_dynamodb_table.fix_history.name
      BEDROCK_MODEL_ID  = var.bedrock_model_id
    }
  }

  depends_on = [
    aws_iam_role_policy.ai_analysis,
    aws_cloudwatch_log_group.ai_analysis,
  ]

  tags = local.common_tags
}

# ── fix_executor Lambda ───────────────────────────────────────────────────────
resource "aws_lambda_function" "fix_executor" {
  function_name = "${local.prefix}-fix-executor"
  role          = aws_iam_role.fix_executor.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  memory_size   = 256
  timeout       = 120

  filename = "${path.module}/../../modules/lambda/zips/fix_executor.zip"

  environment {
    variables = {
      FIX_HISTORY_TABLE = aws_dynamodb_table.fix_history.name
    }
  }

  depends_on = [
    aws_iam_role_policy.fix_executor,
    aws_cloudwatch_log_group.fix_executor,
  ]

  tags = local.common_tags
}

# ── data_collector Lambda ─────────────────────────────────────────────────────
resource "aws_lambda_function" "data_collector" {
  function_name = "${local.prefix}-data-collector"
  role          = aws_iam_role.data_collector.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  memory_size   = 256
  timeout       = 300

  filename = "${path.module}/../../modules/lambda/zips/data_collector.zip"

  environment {
    variables = {
      METRICS_TABLE = aws_dynamodb_table.metrics.name
    }
  }

  depends_on = [
    aws_iam_role_policy.data_collector,
    aws_cloudwatch_log_group.data_collector,
  ]

  tags = local.common_tags
}

# ── EventBridge permissions ───────────────────────────────────────────────────
resource "aws_lambda_permission" "cloudwatch_poller_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_poller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudwatch_poller.arn
}

resource "aws_lambda_permission" "data_collector_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_collector.arn
}
