"""
Lambda: tenant_onboarding
Routes:
  POST /tenants              — register new tenant (ARN can be 'pending')
  POST /tenants (update_arn) — update existing tenant with real ARN
"""
import json
import sys
import os
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client
from response import ok, error

TENANTS_TABLE = os.environ.get("TENANTS_TABLE", "devopsgpt-tenants")


def handler(event, context):
    try:
        body   = json.loads(event.get("body") or "{}")
        action = body.get("action", "").strip()

        # ── UPDATE ARN on existing tenant ─────────────────────────────────
        if action == "update_arn":
            return _update_arn(body)

        # ── REGISTER new tenant ───────────────────────────────────────────
        return _register(body)

    except Exception as e:
        print(f"[tenant_onboarding] ERROR: {e}")
        return error(500, str(e))


def _register(body):
    name           = body.get("name", "").strip()
    aws_account_id = body.get("aws_account_id", "pending").strip() or "pending"
    role_arn       = body.get("role_arn", "pending").strip()       or "pending"
    email          = body.get("email", "").strip()
    uid            = body.get("uid", "").strip()

    if not name:
        return error(400, "name is required")

    tenant_id = str(uuid.uuid4())
    dynamodb  = get_client("dynamodb")

    item = {
        "tenant_id":      {"S": tenant_id},
        "name":           {"S": name},
        "aws_account_id": {"S": aws_account_id},
        "role_arn":       {"S": role_arn},
        "status":         {"S": "pending" if role_arn == "pending" else "active"},
        "created_at":     {"S": datetime.now(timezone.utc).isoformat()},
    }
    if email:
        item["email"] = {"S": email}
    if uid:
        item["uid"] = {"S": uid}

    dynamodb.put_item(
        TableName=TENANTS_TABLE,
        Item=item,
        ConditionExpression="attribute_not_exists(tenant_id)",
    )

    return ok({
        "tenant_id": tenant_id,
        "name":      name,
        "status":    item["status"]["S"],
        "message":   "Tenant registered successfully",
    })


def _update_arn(body):
    tenant_id      = body.get("tenant_id", "").strip()
    role_arn       = body.get("role_arn", "").strip()
    aws_account_id = body.get("aws_account_id", "").strip()

    if not tenant_id:
        return error(400, "tenant_id is required")
    if not role_arn or not role_arn.startswith("arn:aws:iam::"):
        return error(400, "valid role_arn is required")

    dynamodb = get_client("dynamodb")

    dynamodb.update_item(
        TableName=TENANTS_TABLE,
        Key={"tenant_id": {"S": tenant_id}},
        UpdateExpression=(
            "SET role_arn = :arn, "
            "aws_account_id = :acct, "
            "#st = :status, "
            "updated_at = :ts"
        ),
        ExpressionAttributeNames={"#st": "status"},
        ExpressionAttributeValues={
            ":arn":    {"S": role_arn},
            ":acct":   {"S": aws_account_id},
            ":status": {"S": "active"},
            ":ts":     {"S": datetime.now(timezone.utc).isoformat()},
        },
    )

    return ok({
        "tenant_id": tenant_id,
        "status":    "active",
        "message":   "AWS account connected successfully",
    })
