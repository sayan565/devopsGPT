variable "aws_region"       { default = "us-east-1" }
variable "project_name"     { default = "devopsgpt" }
variable "environment"      { default = "dev" }
variable "lambda_memory_mb" { default = 256 }
variable "lambda_timeout_sec" { default = 30 }
variable "bedrock_model_id" { default = "anthropic.claude-3-5-sonnet-20241022-v2:0" }
variable "log_retention_days" { default = 14 }
variable "openrouter_api_key" {
  description = "OpenRouter API key"
  sensitive   = true
  default     = ""
}