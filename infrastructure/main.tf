locals {
  prefix = "${var.project_name}-${var.environment}"
}

module "iam" {
  source     = "./modules/iam"
  prefix     = local.prefix
  aws_region = var.aws_region
  account_id = data.aws_caller_identity.current.account_id
  tables     = module.dynamodb.table_arns
}

module "dynamodb" {
  source = "./modules/dynamodb"
  prefix = local.prefix
}

module "lambda" {
  source           = "./modules/lambda"
  prefix           = local.prefix
  lambda_role_arn  = module.iam.lambda_role_arn
  memory_mb        = var.lambda_memory_mb
  timeout_sec      = var.lambda_timeout_sec
  bedrock_model_id = var.bedrock_model_id
  aws_region       = var.aws_region
  tables           = module.dynamodb.table_names
  ws_endpoint      = module.websocket.endpoint
  source_dir       = "${path.root}/../backend"
}

module "api_gateway" {
  source      = "./modules/api_gateway"
  prefix      = local.prefix
  environment = var.environment
  lambdas     = module.lambda.function_arns
  account_id  = data.aws_caller_identity.current.account_id
  aws_region  = var.aws_region
}

module "websocket" {
  source            = "./modules/websocket"
  prefix            = local.prefix
  environment       = var.environment
  ws_handler_arn    = module.lambda.function_arns["websocket_handler"]
  ws_handler_name   = module.lambda.function_names["websocket_handler"]
  account_id        = data.aws_caller_identity.current.account_id
  aws_region        = var.aws_region
}

module "cloudwatch" {
  source             = "./modules/cloudwatch"
  prefix             = local.prefix
  lambda_names       = module.lambda.function_names
  log_retention_days = var.log_retention_days
}

data "aws_caller_identity" "current" {}