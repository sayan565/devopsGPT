"""
Lambda: tenant_onboarding
Route:  POST /tenant/onboard
Desc:   Registers a new tenant in DynamoDB.
        Stores tenant_id, name, AWS account ID, and role ARN.
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
        body = json.loads(event.get("body") or "{}")
        name = body.get("name", "").strip()
        aws_account_id = body.get("aws_account_id", "").strip()
        role_arn = body.get("role_arn", "").strip()

        # Validate inputs
        if not name:
            return error(400, "name is required")
        if not aws_account_id:
            return error(400, "aws_account_id is required")
        if not role_arn:
            return error(400, "role_arn is required")

        tenant_id = str(uuid.uuid4())
        dynamodb = get_client("dynamodb")

        dynamodb.put_item(
            TableName=TENANTS_TABLE,
            Item={
                "tenant_id":      {"S": tenant_id},
                "name":           {"S": name},
                "aws_account_id": {"S": aws_account_id},
                "role_arn":       {"S": role_arn},
                "status":         {"S": "active"},
                "created_at":     {"S": datetime.now(timezone.utc).isoformat()},
            },
            ConditionExpression="attribute_not_exists(tenant_id)",
        )

        return ok({
            "tenant_id": tenant_id,
            "name": name,
            "status": "active",
            "message": "Tenant onboarded successfully",
        })

    except Exception as e:
        print(f"[tenant_onboarding] ERROR: {e}")
        return error(500, str(e))