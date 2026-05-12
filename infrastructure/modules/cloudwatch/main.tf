variable "prefix"             {}
variable "lambda_names"       { type = map(string) }
variable "log_retention_days" { type = number }
variable "sns_topic_arn"      { default = "" }
variable "cpu_threshold"      { default = 80 }
variable "memory_threshold"   { default = 85 }

# ── Lambda log groups ─────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = var.lambda_names
  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.log_retention_days

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
  }
}

# ── Lambda error alarms ───────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = var.lambda_names
  alarm_name          = "${var.prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda ${each.key} has errors — investigate immediately"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
  }
}

# ── EC2 CPU Utilization alarm (static threshold) ──────────────────────────────
# Triggers when average CPU > cpu_threshold% for 2 consecutive 5-minute periods
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.prefix}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "EC2 CPU utilization exceeds ${var.cpu_threshold}% — auto-healer may trigger"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  # No instance dimension — monitors all EC2 instances in the account
  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
  }
}

# ── EC2 Memory Utilization alarm (requires CloudWatch Agent on instances) ─────
resource "aws_cloudwatch_metric_alarm" "ec2_memory_high" {
  alarm_name          = "${var.prefix}-ec2-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "EC2 memory utilization exceeds ${var.memory_threshold}% — check for memory leaks"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
  }
}

# ── EC2 CPU Anomaly Detection alarm ──────────────────────────────────────────
# Uses ML-based band detection — fires when CPU exits the expected range
# Provides predictive alerting 15-30 minutes before hard threshold breach (FS1)
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_anomaly" {
  alarm_name          = "${var.prefix}-ec2-cpu-anomaly"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "e1"
  alarm_description   = "EC2 CPU anomaly detected — unusual pattern may indicate impending incident"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    return_data = false
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = 300
      stat        = "Average"
    }
  }

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "CPUUtilization (expected)"
    return_data = true
  }

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
  }
}

# ── EC2 Memory Anomaly Detection alarm ───────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ec2_memory_anomaly" {
  alarm_name          = "${var.prefix}-ec2-memory-anomaly"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "e2"
  alarm_description   = "EC2 memory anomaly detected — unusual pattern may indicate memory leak"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m2"
    return_data = false
    metric {
      metric_name = "mem_used_percent"
      namespace   = "CWAgent"
      period      = 300
      stat        = "Average"
    }
  }

  metric_query {
    id          = "e2"
    expression  = "ANOMALY_DETECTION_BAND(m2, 2)"
    label       = "mem_used_percent (expected)"
    return_data = true
  }

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "devopsgpt" {
  dashboard_name = "${var.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x = 0; y = 0; width = 12; height = 6
        properties = {
          title   = "EC2 CPU Utilization"
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization"],
            [{ expression = "ANOMALY_DETECTION_BAND(m1, 2)", label = "Expected band", id = "e1" }]
          ]
        }
      },
      {
        type   = "metric"
        x = 12; y = 0; width = 12; height = 6
        properties = {
          title   = "EC2 Memory Utilization"
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          metrics = [["CWAgent", "mem_used_percent"]]
        }
      },
      {
        type   = "metric"
        x = 0; y = 6; width = 12; height = 6
        properties = {
          title   = "Lambda Errors"
          period  = 60
          stat    = "Sum"
          metrics = [for k, v in var.lambda_names :
            ["AWS/Lambda", "Errors", "FunctionName", v]
          ]
        }
      },
      {
        type   = "alarm"
        x = 12; y = 6; width = 12; height = 6
        properties = {
          title  = "Active Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.ec2_cpu_high.arn,
            aws_cloudwatch_metric_alarm.ec2_memory_high.arn,
            aws_cloudwatch_metric_alarm.ec2_cpu_anomaly.arn,
            aws_cloudwatch_metric_alarm.ec2_memory_anomaly.arn,
          ]
        }
      }
    ]
  })
}
