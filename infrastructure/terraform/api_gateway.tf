# ── REST API ──────────────────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "devopsgpt" {
  name        = "${local.prefix}-api"
  description = "DevOpsGPT API Gateway — routes to Lambda functions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# ── /ai-analysis resource ─────────────────────────────────────────────────────
resource "aws_api_gateway_resource" "ai_analysis" {
  rest_api_id = aws_api_gateway_rest_api.devopsgpt.id
  parent_id   = aws_api_gateway_rest_api.devopsgpt.root_resource_id
  path_part   = "ai-analysis"
}

resource "aws_api_gateway_method" "ai_analysis_post" {
  rest_api_id   = aws_api_gateway_rest_api.devopsgpt.id
  resource_id   = aws_api_gateway_resource.ai_analysis.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "ai_analysis" {
  rest_api_id             = aws_api_gateway_rest_api.devopsgpt.id
  resource_id             = aws_api_gateway_resource.ai_analysis.id
  http_method             = aws_api_gateway_method.ai_analysis_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ai_analysis.invoke_arn
}

resource "aws_lambda_permission" "ai_analysis_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_analysis.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.devopsgpt.execution_arn}/*/*"
}

# ── /fix-execute resource ─────────────────────────────────────────────────────
resource "aws_api_gateway_resource" "fix_execute" {
  rest_api_id = aws_api_gateway_rest_api.devopsgpt.id
  parent_id   = aws_api_gateway_rest_api.devopsgpt.root_resource_id
  path_part   = "fix-execute"
}

resource "aws_api_gateway_method" "fix_execute_post" {
  rest_api_id   = aws_api_gateway_rest_api.devopsgpt.id
  resource_id   = aws_api_gateway_resource.fix_execute.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "fix_execute" {
  rest_api_id             = aws_api_gateway_rest_api.devopsgpt.id
  resource_id             = aws_api_gateway_resource.fix_execute.id
  http_method             = aws_api_gateway_method.fix_execute_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fix_executor.invoke_arn
}

resource "aws_lambda_permission" "fix_executor_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fix_executor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.devopsgpt.execution_arn}/*/*"
}

# ── Deployment ────────────────────────────────────────────────────────────────
resource "aws_api_gateway_deployment" "devopsgpt" {
  rest_api_id = aws_api_gateway_rest_api.devopsgpt.id

  depends_on = [
    aws_api_gateway_integration.ai_analysis,
    aws_api_gateway_integration.fix_execute,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "devopsgpt" {
  deployment_id = aws_api_gateway_deployment.devopsgpt.id
  rest_api_id   = aws_api_gateway_rest_api.devopsgpt.id
  stage_name    = var.environment

  tags = local.common_tags
}

# ── API Key ───────────────────────────────────────────────────────────────────
resource "aws_api_gateway_api_key" "devopsgpt" {
  name    = "${local.prefix}-api-key"
  enabled = true
  tags    = local.common_tags
}

resource "aws_api_gateway_usage_plan" "devopsgpt" {
  name = "${local.prefix}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.devopsgpt.id
    stage  = aws_api_gateway_stage.devopsgpt.stage_name
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }

  tags = local.common_tags
}

resource "aws_api_gateway_usage_plan_key" "devopsgpt" {
  key_id        = aws_api_gateway_api_key.devopsgpt.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.devopsgpt.id
}
