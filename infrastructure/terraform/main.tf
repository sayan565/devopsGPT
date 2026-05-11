terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend for remote state — configure bucket before running terraform init
  backend "s3" {
    bucket         = "devopsgpt-terraform-state"
    key            = "devopsgpt/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "devopsgpt-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── Local variables ───────────────────────────────────────────────────────────
locals {
  prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lambda_functions = [
    "cloudwatch_poller",
    "ai_analysis",
    "fix_executor",
    "data_collector",
  ]
}

# ── SNS Topic for CRITICAL alerts ─────────────────────────────────────────────
resource "aws_sns_topic" "critical_alerts" {
  name = "${local.prefix}-critical-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alert" {
  count     = var.sns_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_alert_email
}
