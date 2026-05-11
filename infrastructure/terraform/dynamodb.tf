# ── AlertsTable ───────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "alerts" {
  name         = "${local.prefix}-alerts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "serverId"
  range_key    = "timestamp"

  attribute {
    name = "serverId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
  attribute {
    name = "severity"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, { Name = "${local.prefix}-alerts" })
}

# ── MetricsTable ──────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "metrics" {
  name         = "${local.prefix}-metrics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "serverId"
  range_key    = "timestamp"

  attribute {
    name = "serverId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }

  global_secondary_index {
    name            = "timestamp-index"
    hash_key        = "timestamp"
    projection_type = "KEYS_ONLY"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, { Name = "${local.prefix}-metrics" })
}

# ── FixHistoryTable ───────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "fix_history" {
  name         = "${local.prefix}-fix-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "fixId"
  range_key    = "timestamp"

  attribute {
    name = "fixId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
  attribute {
    name = "serverId"
    type = "S"
  }
  attribute {
    name = "fixType"
    type = "S"
  }

  global_secondary_index {
    name            = "serverId-index"
    hash_key        = "serverId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "fixType-index"
    hash_key        = "fixType"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, { Name = "${local.prefix}-fix-history" })
}

# ── ServersTable ──────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "servers" {
  name         = "${local.prefix}-servers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "serverId"

  attribute {
    name = "serverId"
    type = "S"
  }
  attribute {
    name = "tenantId"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "tenantId-index"
    hash_key        = "tenantId"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "KEYS_ONLY"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, { Name = "${local.prefix}-servers" })
}
