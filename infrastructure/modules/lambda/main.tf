variable "prefix"           {}
variable "lambda_role_arn"  {}
variable "memory_mb"        { type = number }
variable "timeout_sec"      { type = number }
variable "bedrock_model_id" {}
variable "aws_region"       {}
variable "source_dir"       {}
variable "tables"           { type = map(string) }
variable "ws_endpoint"      { default = "" }

locals {
  functions = {
    list_servers      = "lambdas/list_servers"
    alert_processor   = "lambdas/alert_processor"
    ai_analyzer       = "lambdas/ai_analyzer"
    auto_healer       = "lambdas/auto_healer"
    metrics_streamer  = "lambdas/metrics_streamer"
    websocket_handler = "lambdas/websocket_handler"
    tenant_onboarding = "lambdas/tenant_onboarding"
    tenant_lookup = "lambdas/tenant_lookup"
  }

  common_env = {
    TENANTS_TABLE      = var.tables["tenants"]
    ALERTS_TABLE       = var.tables["alerts"]
    ACTIONS_TABLE      = var.tables["actions"]
    CHAT_TABLE         = var.tables["chat"]
    CONNECTIONS_TABLE  = var.tables["ws_conns"]
    # METRICS_TABLE used by cloudwatch_poller and data_collector
    METRICS_TABLE      = lookup(var.tables, "metrics", "${var.prefix}-metrics")
    # FIX_HISTORY_TABLE used by ai_analysis and fix_executor
    FIX_HISTORY_TABLE  = lookup(var.tables, "fix-history", "${var.prefix}-fix-history")
    WEBSOCKET_ENDPOINT = var.ws_endpoint
    AWS_ACCOUNT_REGION = var.aws_region
    # bedrock_model_id kept for future Bedrock integration (FS spec requirement)
    BEDROCK_MODEL_ID   = var.bedrock_model_id
    LOG_LEVEL          = "INFO"
  }
}

data "archive_file" "zips" {
  for_each    = local.functions
  type        = "zip"
  output_path = "${path.module}/zips/${each.key}.zip"
  source_dir  = var.source_dir
}

resource "aws_lambda_function" "fns" {
  for_each         = local.functions
  function_name    = "${var.prefix}-${each.key}"
  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "${each.value}/handler.handler"
  filename         = data.archive_file.zips[each.key].output_path
  source_code_hash = data.archive_file.zips[each.key].output_base64sha256
  memory_size      = var.memory_mb
  timeout          = each.key == "ai_analyzer" ? 120 : var.timeout_sec

  environment {
    variables = local.common_env
  }

  depends_on = [aws_cloudwatch_log_group.logs]
}

resource "aws_cloudwatch_log_group" "logs" {
  for_each          = local.functions
  name              = "/aws/lambda/${var.prefix}-${each.key}"
  retention_in_days = 14
}

output "function_arns"  { value = { for k, f in aws_lambda_function.fns : k => f.arn } }
output "function_names" { value = { for k, f in aws_lambda_function.fns : k => f.function_name } }
output "invoke_arns"    { value = { for k, f in aws_lambda_function.fns : k => f.invoke_arn } }