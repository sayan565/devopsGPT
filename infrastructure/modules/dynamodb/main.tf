variable "prefix" {}

locals {
  tables = {
    # Core application tables
    tenants  = { hash_key = "tenant_id",    range_key = null }
    alerts   = { hash_key = "alert_id",     range_key = null }
    actions  = { hash_key = "action_id",    range_key = null }
    chat     = { hash_key = "session_id",   range_key = null }
    ws_conns = { hash_key = "connection_id", range_key = null }

    # Metrics table — used by cloudwatch_poller and data_collector
    metrics  = { hash_key = "serverId",     range_key = null }

    # Fix history — used by ai_analysis and fix_executor
    fix-history = { hash_key = "fixId",     range_key = null }
  }
}

resource "aws_dynamodb_table" "tables" {
  for_each     = local.tables
  name         = "${var.prefix}-${each.key}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key

  attribute {
    name = each.value.hash_key
    type = "S"
  }

  # Enable TTL on time-series and connection tables
  dynamic "ttl" {
    for_each = contains(["ws_conns", "metrics", "alerts"], each.key) ? [1] : []
    content {
      attribute_name = "ttl"
      enabled        = true
    }
  }

  point_in_time_recovery { enabled = true }

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
    Table     = each.key
  }
}

# ── GSI: tenants table — email-index for O(1) tenant lookup by email ─────────
resource "aws_dynamodb_table" "tenants_gsi" {
  name         = "${var.prefix}-tenants"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenant_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }
  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }

  lifecycle {
    ignore_changes = [name]
  }

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
    Table     = "tenants"
  }
}

# ── GSI: ws_conns table — tenant_id-index for O(1) broadcast by tenant ───────
resource "aws_dynamodb_table" "ws_conns_gsi" {
  name         = "${var.prefix}-ws_conns"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "connection_id"

  attribute {
    name = "connection_id"
    type = "S"
  }
  attribute {
    name = "tenant_id"
    type = "S"
  }

  global_secondary_index {
    name            = "tenant_id-index"
    hash_key        = "tenant_id"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery { enabled = true }

  lifecycle {
    ignore_changes = [name]
  }

  tags = {
    Project   = "DevOpsGPT"
    ManagedBy = "Terraform"
    Table     = "ws_conns"
  }
}

output "table_arns"  { value = [for t in aws_dynamodb_table.tables : t.arn] }
output "table_names" { value = { for k, t in aws_dynamodb_table.tables : k => t.name } }
