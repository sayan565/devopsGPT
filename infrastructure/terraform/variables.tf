variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "devopsgpt"
}

variable "cpu_threshold" {
  description = "CPU utilization percentage threshold for alerts"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Memory utilization percentage threshold for alerts"
  type        = number
  default     = 85
}

variable "bedrock_model_id" {
  description = "AWS Bedrock model ID for AI analysis"
  type        = string
  default     = "anthropic.claude-sonnet-4-20250514-v1:0"
}

variable "sns_alert_email" {
  description = "Email address for CRITICAL alert SNS notifications"
  type        = string
  default     = ""
}

variable "lambda_code_bucket" {
  description = "S3 bucket containing Lambda deployment packages"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}
