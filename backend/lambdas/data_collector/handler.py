"""
Lambda: data_collector
Trigger: EventBridge every 5 minutes
Desc: Collects CPU, Memory, Disk, Network metrics from CloudWatch
      for all running EC2 instances and stores to DynamoDB MetricsTable.
"""
import json
import logging
import os
from datetime import datetime, timezone, timedelta

import boto3

# ── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── Environment variables ─────────────────────────────────────────────────────
METRICS_TABLE = os.environ.get("METRICS_TABLE", "devopsgpt-dev-metrics")
AWS_REGION    = os.environ.get("AWS_REGION", "us-east-1")


def _fetch_metric(cw_client, instance_id: str, namespace: str,
                  metric_name: str, period: int = 300) -> float:
    """Fetch a single CloudWatch metric value. Returns 0.0 if no data."""
    now = datetime.now(timezone.utc)
    try:
        resp = cw_client.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
            StartTime=now - timedelta(seconds=period * 2),
            EndTime=now,
            Period=period,
            Statistics=["Average"],
        )
        datapoints = resp.get("Datapoints", [])
        if not datapoints:
            return 0.0
        return round(
            sorted(datapoints, key=lambda x: x["Timestamp"])[-1]["Average"], 2
        )
    except Exception as e:
        logger.warning("Could not fetch %s for %s: %s", metric_name, instance_id, e)
        return 0.0


def _collect_instance_metrics(cw_client, instance_id: str) -> dict:
    """Collect all metrics for a single EC2 instance."""
    # Standard EC2 metrics (always available)
    cpu = _fetch_metric(cw_client, instance_id, "AWS/EC2", "CPUUtilization")

    # CloudWatch Agent metrics (require agent installed on instance)
    memory  = _fetch_metric(cw_client, instance_id,
                            "CWAgent", "mem_used_percent")
    disk    = _fetch_metric(cw_client, instance_id,
                            "CWAgent", "disk_used_percent")

    # Network metrics (standard EC2)
    net_in  = _fetch_metric(cw_client, instance_id,
                            "AWS/EC2", "NetworkIn")
    net_out = _fetch_metric(cw_client, instance_id,
                            "AWS/EC2", "NetworkOut")

    return {
        "cpu":        cpu,
        "memory":     memory,
        "disk":       disk,
        "networkIn":  net_in,
        "networkOut": net_out,
    }


def _store_metrics(dynamodb, instance_id: str, metrics: dict) -> None:
    """Store collected metrics to DynamoDB MetricsTable."""
    timestamp = datetime.now(timezone.utc).isoformat()
    dynamodb.put_item(
        TableName=METRICS_TABLE,
        Item={
            "serverId":   {"S": instance_id},
            "timestamp":  {"S": timestamp},
            "cpu":        {"N": str(metrics["cpu"])},
            "memory":     {"N": str(metrics["memory"])},
            "disk":       {"N": str(metrics["disk"])},
            "networkIn":  {"N": str(metrics["networkIn"])},
            "networkOut": {"N": str(metrics["networkOut"])},
            # TTL: keep metrics for 7 days
            "ttl": {"N": str(int((datetime.now(timezone.utc)
                                   + timedelta(days=7)).timestamp()))},
        },
    )


def handler(event, context):
    """Main Lambda handler — collects metrics for all running EC2 instances."""
    logger.info("data_collector triggered: %s", json.dumps(event))

    ec2      = boto3.client("ec2",        region_name=AWS_REGION)
    cw       = boto3.client("cloudwatch", region_name=AWS_REGION)
    dynamodb = boto3.client("dynamodb",   region_name=AWS_REGION)

    collected = 0
    errors    = 0
    summary   = []

    try:
        # Discover all running EC2 instances
        paginator = ec2.get_paginator("describe_instances")
        instance_ids = []
        for page in paginator.paginate(
            Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
        ):
            for reservation in page["Reservations"]:
                for inst in reservation["Instances"]:
                    instance_ids.append(inst["InstanceId"])

        logger.info("Collecting metrics for %d instances", len(instance_ids))

        for instance_id in instance_ids:
            try:
                metrics = _collect_instance_metrics(cw, instance_id)
                _store_metrics(dynamodb, instance_id, metrics)
                collected += 1
                summary.append({
                    "instanceId": instance_id,
                    "cpu":        metrics["cpu"],
                    "memory":     metrics["memory"],
                    "disk":       metrics["disk"],
                })
                logger.info("Metrics stored: %s cpu=%.1f%% mem=%.1f%%",
                            instance_id, metrics["cpu"], metrics["memory"])
            except Exception as inst_err:
                logger.error("Error collecting metrics for %s: %s",
                             instance_id, inst_err)
                errors += 1

    except Exception as e:
        logger.error("Fatal error in data_collector: %s", e, exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }

    result = {
        "collected":  collected,
        "errors":     errors,
        "timestamp":  datetime.now(timezone.utc).isoformat(),
        "instances":  summary,
    }
    logger.info("Collection complete: %s", json.dumps(result))
    return {"statusCode": 200, "body": json.dumps(result)}
