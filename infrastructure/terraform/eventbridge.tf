# ── cloudwatch_poller — every 1 minute ───────────────────────────────────────
resource "aws_cloudwatch_event_rule" "cloudwatch_poller" {
  name                = "${local.prefix}-cloudwatch-poller-trigger"
  description         = "Trigger cloudwatch_poller Lambda every 60 seconds"
  schedule_expression = "rate(1 minute)"
  state               = "ENABLED"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "cloudwatch_poller" {
  rule      = aws_cloudwatch_event_rule.cloudwatch_poller.name
  target_id = "cloudwatch-poller-lambda"
  arn       = aws_lambda_function.cloudwatch_poller.arn

  input = jsonencode({
    source  = "eventbridge"
    trigger = "scheduled"
  })
}

# ── data_collector — every 5 minutes ─────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "data_collector" {
  name                = "${local.prefix}-data-collector-trigger"
  description         = "Trigger data_collector Lambda every 5 minutes"
  schedule_expression = "rate(5 minutes)"
  state               = "ENABLED"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "data_collector" {
  rule      = aws_cloudwatch_event_rule.data_collector.name
  target_id = "data-collector-lambda"
  arn       = aws_lambda_function.data_collector.arn

  input = jsonencode({
    source  = "eventbridge"
    trigger = "scheduled"
  })
}
