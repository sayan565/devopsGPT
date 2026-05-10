variable "prefix"      {}
variable "environment" {}
variable "lambdas"     { type = map(string) }
variable "account_id"  {}
variable "aws_region"  {}

resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.prefix}-api"
  description = "DevOpsGPT REST API"
  endpoint_configuration { types = ["REGIONAL"] }
}

locals {
  routes = {
    servers        = { path = "servers",        method = "GET",  lambda = "list_servers" }
    alerts         = { path = "alerts",         method = "GET",  lambda = "alert_processor" }
    logs           = { path = "logs",           method = "GET",  lambda = "metrics_streamer" }
    ai_chat        = { path = "ai-chat",        method = "POST", lambda = "ai_analyzer" }
    fix            = { path = "fix",            method = "POST", lambda = "auto_healer" }
    tenant_onboard = { path = "tenants", method = "POST", lambda = "tenant_onboarding" }
    tenant_lookup = { path = "tenants-lookup", method = "GET", lambda = "tenant_lookup" }
  }
}

resource "aws_api_gateway_resource" "resources" {
  for_each    = local.routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.value.path
}

resource "aws_api_gateway_method" "methods" {
  for_each         = local.routes
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.resources[each.key].id
  http_method      = each.value.method
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "integrations" {
  for_each                = local.routes
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resources[each.key].id
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambdas[each.value.lambda]}/invocations"
}

resource "aws_api_gateway_method" "options" {
  for_each      = local.routes
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resources[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each    = local.routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resources[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "options_200" {
  for_each    = local.routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resources[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each    = local.routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resources[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Api-Key,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_integration.options]
}

resource "aws_lambda_permission" "apigw" {
  for_each      = local.routes
  statement_id  = "AllowAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambdas[each.value.lambda]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resources,
      aws_api_gateway_method.methods,
      aws_api_gateway_integration.integrations,
    ]))
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment
}

resource "aws_api_gateway_api_key" "key" {
  name    = "${var.prefix}-api-key"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "plan" {
  name = "${var.prefix}-usage-plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }
  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
  quota_settings {
    limit  = 10000
    period = "MONTH"
  }
}

resource "aws_api_gateway_usage_plan_key" "plan_key" {
  key_id        = aws_api_gateway_api_key.key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.plan.id
}

output "invoke_url" { value = aws_api_gateway_stage.stage.invoke_url }
output "api_key_id" { value = aws_api_gateway_api_key.key.id }