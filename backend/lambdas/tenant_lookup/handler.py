"""
Lambda: tenant_lookup
Route:  GET /tenants/by-email
Desc:   Returns tenant_id for a given email address
"""
import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from aws_clients import get_client
from response import ok, error

TENANTS_TABLE = os.environ.get("TENANTS_TABLE", "devopsgpt-dev-tenants")

def handler(event, context):
    try:
        qs = event.get("queryStringParameters") or {}
        email = qs.get("email", "").strip()

        if not email:
            return error(400, "email is required")

        dynamodb = get_client("dynamodb")

        result = dynamodb.scan(
            TableName=TENANTS_TABLE,
            FilterExpression="email = :e",
            ExpressionAttributeValues={":e": {"S": email}},
        )

        items = result.get("Items", [])
        if not items:
            return error(404, "Tenant not found")

        item = items[0]
        return ok({
            "tenant_id": item["tenant_id"]["S"],
            "name":      item.get("name", {}).get("S", ""),
            "status":    item.get("status", {}).get("S", "active"),
        })

    except Exception as e:
        print(f"[tenant_lookup] ERROR: {e}")
        return error(500, str(e))