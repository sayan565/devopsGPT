# ── Shared Lambda assume-role policy ─────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ── cloudwatch_poller IAM ─────────────────────────────────────────────────────
resource "aws_iam_role" "cloudwatch_poller" {
  name               = "${local.prefix}-cloudwatch-poller-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "cloudwatch_poller" {
  name = "${local.prefix}-cloudwatch-poller-policy"
  role = aws_iam_role.cloudwatch_poller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = [
          aws_dynamodb_table.alerts.arn,
          "${aws_dynamodb_table.alerts.arn}/index/*",
        ]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.critical_alerts.arn]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ── ai_analysis IAM ───────────────────────────────────────────────────────────
resource "aws_iam_role" "ai_analysis" {
  name               = "${local.prefix}-ai-analysis-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "ai_analysis" {
  name = "${local.prefix}-ai-analysis-policy"
  role = aws_iam_role.ai_analysis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvoke"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = [
          aws_dynamodb_table.fix_history.arn,
          "${aws_dynamodb_table.fix_history.arn}/index/*",
        ]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ── fix_executor IAM ──────────────────────────────────────────────────────────
resource "aws_iam_role" "fix_executor" {
  name               = "${local.prefix}-fix-executor-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "fix_executor" {
  name = "${local.prefix}-fix-executor-policy"
  role = aws_iam_role.fix_executor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2Reboot"
        Effect   = "Allow"
        Action   = ["ec2:RebootInstances", "ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid      = "ECSUpdate"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = "*"
      },
      {
        Sid      = "AutoScaling"
        Effect   = "Allow"
        Action   = ["autoscaling:SetDesiredCapacity", "autoscaling:DescribeAutoScalingGroups"]
        Resource = "*"
      },
      {
        Sid      = "SSMCommand"
        Effect   = "Allow"
        Action   = ["ssm:SendCommand", "ssm:GetCommandInvocation"]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = [
          aws_dynamodb_table.fix_history.arn,
          "${aws_dynamodb_table.fix_history.arn}/index/*",
        ]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ── data_collector IAM ────────────────────────────────────────────────────────
resource "aws_iam_role" "data_collector" {
  name               = "${local.prefix}-data-collector-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "data_collector" {
  name = "${local.prefix}-data-collector-policy"
  role = aws_iam_role.data_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
        ]
        Resource = "*"
      },
      {
        Sid      = "EC2Describe"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:BatchWriteItem"]
        Resource = [
          aws_dynamodb_table.metrics.arn,
        ]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}
