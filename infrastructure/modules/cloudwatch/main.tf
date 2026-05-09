variable "prefix"             {}
variable "lambda_names"       { type = map(string) }
variable "log_retention_days" { type = number }

resource "aws_cloudwatch_metric_alarm" "errors" {
  for_each            = var.lambda_names
  alarm_name          = "${var.prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda ${each.key} errors"

  dimensions = {
    FunctionName = each.value
  }
}