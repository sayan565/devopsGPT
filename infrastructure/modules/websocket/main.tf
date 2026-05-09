variable "prefix"          {}
variable "environment"     {}
variable "ws_handler_arn"  {}
variable "ws_handler_name" {}
variable "account_id"      {}
variable "aws_region"      {}

resource "aws_apigatewayv2_api" "ws" {
  name                       = "${var.prefix}-websocket"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

locals {
  ws_routes = ["$connect", "$disconnect", "sendMetrics"]
}

resource "aws_apigatewayv2_integration" "ws" {
  api_id             = aws_apigatewayv2_api.ws.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.ws_handler_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each  = toset(local.ws_routes)
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.ws.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.ws.id
  name        = var.environment
  auto_deploy = true
}

resource "aws_lambda_permission" "ws" {
  statement_id  = "AllowWebSocketAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.ws_handler_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws.execution_arn}/*/*"
}

output "endpoint" { value = "${aws_apigatewayv2_api.ws.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}" }
output "wss_url"  { value = "wss://${aws_apigatewayv2_api.ws.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}" }