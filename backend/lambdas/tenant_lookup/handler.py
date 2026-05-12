"""
Lambda: tenant_lookup
Route:  GET /tenants-lookup?email=xxx
Desc:   Returns tenant_id for a given email address.
        Uses GSI (email-index) Query instead of Scan for O(1) cost + scalability.
"""
import json
import sys
import os
import logging

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))
from aws_clients import get_client
from response import ok, error

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TENANTS_TABLE = os.environ.get("TENANTS_TABLE", "devopsgpt-dev-tenants")
# GSI name on the tenants table — hash key: email
EMAIL_GSI     = os.environ.get("EMAIL_GSI_NAME", "email-index")


def handler(event, context):
    try:
        qs    = event.get("queryStringParameters") or {}
        email = qs.get("email", "").strip().lower()

        if not email:
            return error(400, "email is required")

        dynamodb = get_client("dynamodb")

        # ── GSI Query (O(1) cost) instead of full-table Scan ─────────────────
        # Requires GSI on tenants table: hash_key=email, name=email-index
        result = dynamodb.query(
            TableName=TENANTS_TABLE,
            IndexName=EMAIL_GSI,
            KeyConditionExpression="email = :e",
            ExpressionAttributeValues={":e": {"S": email}},
            Limit=1,
        )

        items = result.get("Items", [])

        # Fallback to Scan if GSI not yet provisioned (graceful degradation)
        if not items:
            logger.warning("[tenant_lookup] GSI returned 0 items for %s — "
                           "falling back to Scan (ensure email-index GSI exists)", email)
            scan_result = dynamodb.scan(
                TableName=TENANTS_TABLE,
                FilterExpression="email = :e",
                ExpressionAttributeValues={":e": {"S": email}},
            )
            items = scan_result.get("Items", [])

        if not items:
            return error(404, "Tenant not found")

        item = items[0]
        logger.info("[tenant_lookup] found tenant for %s", email)
        return ok({
            "tenant_id": item["tenant_id"]["S"],
            "name":      item.get("name",   {}).get("S", ""),
            "status":    item.get("status", {}).get("S", "active"),
            "role_arn":  item.get("role_arn", {}).get("S", ""),
        })

    except Exception as e:
        logger.error("[tenant_lookup] ERROR: %s", e)
        return error(500, str(e))
