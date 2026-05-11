"""
Lambda: list_servers
Route:  GET /servers
Desc:   Auto-discovers EC2 instances for a tenant.
        No hardcoded instance IDs — uses describe_instances().
"""
import json
import sys
import os

# Allow importing shared/ when running locally
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client, get_tenant_role
from response import ok, error


def handler(event, context):
    try:
        tenant_id = _get_tenant_id(event)
        role_arn = get_tenant_role(tenant_id) if tenant_id else None

        ec2 = get_client("ec2", role_arn, tenant_id=tenant_id)
        cw  = get_client("cloudwatch", role_arn, tenant_id=tenant_id)

        # Auto-discover all running/stopped EC2 instances
        paginator = ec2.get_paginator("describe_instances")
        servers = []

        for page in paginator.paginate(
            Filters=[{"Name": "instance-state-name", "Values": ["running", "stopped"]}]
        ):
            for reservation in page["Reservations"]:
                for inst in reservation["Instances"]:
                    name = _get_tag(inst, "Name") or inst["InstanceId"]
                    cpu = _get_cpu(cw, inst["InstanceId"])
                    servers.append({
                        "id": inst["InstanceId"],
                        "name": name,
                        "type": inst["InstanceType"],
                        "state": inst["State"]["Name"],
                        "az": inst["Placement"]["AvailabilityZone"],
                        "private_ip": inst.get("PrivateIpAddress", "N/A"),
                        "public_ip": inst.get("PublicIpAddress", "N/A"),
                        "launch_time": str(inst.get("LaunchTime", "")),
                        "cpu_percent": cpu,
                    })

        return ok({"servers": servers, "count": len(servers)})

    except Exception as e:
        print(f"[list_servers] ERROR: {e}")
        return error(500, str(e))


def _get_tenant_id(event) -> str | None:
    """Extract tenant_id from query string or JWT claims."""
    qs = event.get("queryStringParameters") or {}
    if "tenant_id" in qs:
        return qs["tenant_id"]
    # If using Cognito authorizer, tenant_id is in claims
    claims = (
        event.get("requestContext", {})
             .get("authorizer", {})
             .get("claims", {})
    )
    return claims.get("custom:tenant_id")


def _get_tag(instance: dict, key: str) -> str | None:
    for tag in instance.get("Tags", []):
        if tag["Key"] == key:
            return tag["Value"]
    return None


def _get_cpu(cw, instance_id: str) -> float:
    """Get latest CPU utilization from CloudWatch."""
    from datetime import datetime, timezone, timedelta
    try:
        resp = cw.get_metric_statistics(
            Namespace="AWS/EC2",
            MetricName="CPUUtilization",
            Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
            StartTime=datetime.now(timezone.utc) - timedelta(minutes=10),
            EndTime=datetime.now(timezone.utc),
            Period=300,
            Statistics=["Average"],
        )
        datapoints = resp.get("Datapoints", [])
        if datapoints:
            return round(sorted(datapoints, key=lambda x: x["Timestamp"])[-1]["Average"], 2)
    except Exception:
        pass
    return 0.0