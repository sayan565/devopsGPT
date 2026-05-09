variable "prefix" {}

locals {
  tables = {
    tenants  = { hash_key = "tenant_id" }
    alerts   = { hash_key = "alert_id" }
    actions  = { hash_key = "action_id" }
    chat     = { hash_key = "session_id" }
    ws_conns = { hash_key = "connection_id" }
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

  dynamic "ttl" {
    for_each = each.key == "ws_conns" ? [1] : []
    content {
      attribute_name = "ttl"
      enabled        = true
    }
  }

  point_in_time_recovery { enabled = true }
}

output "table_arns"  { value = [for t in aws_dynamodb_table.tables : t.arn] }
output "table_names" { value = { for k, t in aws_dynamodb_table.tables : k => t.name } }