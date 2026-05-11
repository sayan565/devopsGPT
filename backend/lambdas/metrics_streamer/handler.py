"""
Lambda: metrics_streamer
Route:  GET /logs
Desc:   Fetches recent log events from CloudWatch Logs.
        Supports ?log_group= and ?instance_id= filters.
"""
import sys
import os
from datetime import datetime, timezone, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client, get_tenant_role
from response import ok, error

DEFAULT_LOG_GROUPS = [
    "/aws/lambda",
    "/aws/ec2",
    "/var/log/syslog",
]
LOG_LIMIT = int(os.environ.get("LOG_LIMIT", "100"))


def handler(event, context):
    try:
        tenant_id = _get_tenant_id(event)
        role_arn    = get_tenant_role(tenant_id) if tenant_id else None
        qs          = event.get("queryStringParameters") or {}
        logs_client = get_client("logs", role_arn, tenant_id=tenant_id)

        # List available log groups
        log_groups = _list_log_groups(logs_client, qs.get("prefix", ""))

        # Fetch recent events from each group (up to 5 groups)
        all_events = []
        for group in log_groups[:5]:
            events = _fetch_events(logs_client, group, limit=20)
            all_events.extend(events)

        # Sort all events by timestamp descending
        all_events.sort(key=lambda x: x["timestamp"], reverse=True)

        return ok({
            "logs": all_events[:LOG_LIMIT],
            "log_groups": log_groups,
            "count": len(all_events[:LOG_LIMIT]),
        })

    except Exception as e:
        print(f"[metrics_streamer] ERROR: {e}")
        return error(500, str(e))


def _list_log_groups(logs_client, prefix: str = "") -> list[str]:
    groups = []
    kwargs = {}
    if prefix:
        kwargs["logGroupNamePrefix"] = prefix
    try:
        paginator = logs_client.get_paginator("describe_log_groups")
        for page in paginator.paginate(**kwargs):
            for g in page["logGroups"]:
                groups.append(g["logGroupName"])
    except Exception as e:
        print(f"[metrics_streamer] list_log_groups error: {e}")
    return groups


def _fetch_events(logs_client, log_group: str, limit: int = 20) -> list[dict]:
    """Get the most recent events from a log group."""
    events = []
    try:
        # Get latest log stream
        streams = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy="LastEventTime",
            descending=True,
            limit=1,
        ).get("logStreams", [])

        if not streams:
            return events

        stream_name = streams[0]["logStreamName"]
        start_time = int(
            (datetime.now(timezone.utc) - timedelta(hours=1)).timestamp() * 1000
        )

        resp = logs_client.get_log_events(
            logGroupName=log_group,
            logStreamName=stream_name,
            startTime=start_time,
            limit=limit,
            startFromHead=False,
        )

        for ev in resp.get("events", []):
            events.append({
                "log_group": log_group,
                "stream": stream_name,
                "timestamp": ev["timestamp"],
                "time_str": datetime.fromtimestamp(
                    ev["timestamp"] / 1000, tz=timezone.utc
                ).isoformat(),
                "message": ev["message"].strip(),
            })

    except Exception as e:
        print(f"[metrics_streamer] fetch_events error for {log_group}: {e}")

    return events


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