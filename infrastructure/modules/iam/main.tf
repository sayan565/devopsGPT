variable "prefix"     {}
variable "aws_region" {}
variable "account_id" {}
variable "tables"     { type = list(string) }

resource "aws_iam_role" "lambda" {
  name = "${var.prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = ["ec2:DescribeInstances","ec2:DescribeInstanceStatus","ec2:DescribeTags"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = ["cloudwatch:DescribeAlarms","cloudwatch:GetMetricStatistics","cloudwatch:GetMetricData","cloudwatch:ListMetrics","logs:DescribeLogGroups","logs:DescribeLogStreams","logs:GetLogEvents","logs:FilterLogEvents"]
        Resource = "*"
      },
      {
        Sid    = "SSMRunCommand"
        Effect = "Allow"
        Action = ["ssm:SendCommand","ssm:GetCommandInvocation","ssm:ListCommands","ssm:DescribeInstanceInformation"]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = ["dynamodb:PutItem","dynamodb:GetItem","dynamodb:UpdateItem","dynamodb:DeleteItem","dynamodb:Query","dynamodb:Scan"]
        Resource = var.tables
      },
      {
        Sid      = "STSAssumeRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::*:role/DevOpsGPTMonitoringRole"
      },
      {
        Sid      = "APIGatewayWS"
        Effect   = "Allow"
        Action   = "execute-api:ManageConnections"
        Resource = "arn:aws:execute-api:${var.aws_region}:${var.account_id}:*"
      },
    ]
  })
}

output "lambda_role_arn"  { value = aws_iam_role.lambda.arn }
output "lambda_role_name" { value = aws_iam_role.lambda.name }