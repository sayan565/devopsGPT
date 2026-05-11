"""
Lambda: alert_processor
Route:  GET /alerts
Desc:   Returns all CloudWatch alarms with state + history.
        Also writes new ALARM-state alerts to DynamoDB for persistence.
"""
import json
import sys
import os
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client, get_tenant_role
from response import ok, error

ALERTS_TABLE = os.environ.get("ALERTS_TABLE", "devopsgpt-alerts")


def handler(event, context):
    try:
        tenant_id = _get_tenant_id(event)
        role_arn = get_tenant_role(tenant_id) if tenant_id else None

        cw       = get_client("cloudwatch", role_arn, tenant_id=tenant_id)
        dynamodb = get_client("dynamodb")  # always master account

        alarms = []
        paginator = cw.get_paginator("describe_alarms")

        for page in paginator.paginate():
            for alarm in page["MetricAlarms"]:
                state = alarm["StateValue"]
                item = {
                    "id": alarm["AlarmArn"],
                    "name": alarm["AlarmName"],
                    "state": state,             # OK | ALARM | INSUFFICIENT_DATA
                    "description": alarm.get("AlarmDescription", ""),
                    "metric": alarm.get("MetricName", ""),
                    "namespace": alarm.get("Namespace", ""),
                    "threshold": alarm.get("Threshold", 0),
                    "updated_at": str(alarm.get("StateUpdatedTimestamp", "")),
                }
                alarms.append(item)

                # Persist ALARM-state items to DynamoDB
                if state == "ALARM":
                    _persist_alert(dynamodb, tenant_id, item)

        # Sort: ALARM first, then INSUFFICIENT_DATA, then OK
        priority = {"ALARM": 0, "INSUFFICIENT_DATA": 1, "OK": 2}
        alarms.sort(key=lambda x: priority.get(x["state"], 3))

        return ok({"alerts": alarms, "count": len(alarms)})

    except Exception as e:
        print(f"[alert_processor] ERROR: {e}")
        return error(500, str(e))


def _persist_alert(dynamodb, tenant_id: str, item: dict):
    """Write alert to DynamoDB (idempotent — uses alarm ARN as key)."""
    try:
        dynamodb.put_item(
            TableName=ALERTS_TABLE,
            Item={
                "alert_id":   {"S": item["id"]},
                "tenant_id":  {"S": tenant_id or "default"},
                "alarm_name": {"S": item["name"]},
                "state":      {"S": item["state"]},
                "metric":     {"S": item["metric"]},
                "threshold":  {"N": str(item["threshold"])},
                "updated_at": {"S": item["updated_at"]},
                "created_at": {"S": datetime.now(timezone.utc).isoformat()},
            },
            ConditionExpression="attribute_not_exists(alert_id)",
        )
    except dynamodb.exceptions.ConditionalCheckFailedException:
        pass  # Already exists, skip
    except Exception as e:
        print(f"[alert_processor] DynamoDB write failed: {e}")


def _get_tenant_id(event) -> str | None:
    qs = event.get("queryStringParameters") or {}
    if "tenant_id" in qs:
        return qs["tenant_id"]
    claims = (
        event.get("requestContext", {})
             .get("authorizer", {})
             .get("claims", {})
    )
    return claims.get("custom:tenant_id")