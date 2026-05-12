"""
Lambda: cloudwatch_poller
Trigger: EventBridge every 60 seconds
Desc: Polls EC2 CPU + Memory metrics, writes alerts to DynamoDB,
      publishes SNS for CRITICAL severity.
"""
import json
import logging
import os
import uuid
from datetime import datetime, timezone, timedelta

import boto3

# ── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── Environment variables ─────────────────────────────────────────────────────
ALERTS_TABLE      = os.environ.get("ALERTS_TABLE", "devopsgpt-dev-alerts")
METRICS_TABLE     = os.environ.get("METRICS_TABLE", "devopsgpt-dev-metrics")
SNS_TOPIC_ARN     = os.environ.get("SNS_TOPIC_ARN", "")
AWS_REGION        = os.environ.get("AWS_REGION", "us-east-1")
CPU_THRESHOLD     = float(os.environ.get("CPU_THRESHOLD", "80"))
MEMORY_THRESHOLD  = float(os.environ.get("MEMORY_THRESHOLD", "85"))

# ── Severity thresholds ───────────────────────────────────────────────────────
def _get_severity(value: float, metric_type: str) -> str | None:
    """Return severity level or None if below threshold."""
    threshold = CPU_THRESHOLD if metric_type == "CPU" else MEMORY_THRESHOLD
    if value < threshold:
        return None
    if value < threshold + 5:
        return "LOW"
    if value < threshold + 10:
        return "MEDIUM"
    if value < threshold + 15:
        return "HIGH"
    return "CRITICAL"


def _get_metric_statistics(cw_client, instance_id: str, metric_name: str) -> float:
    """Fetch the latest CloudWatch metric value for an EC2 instance."""
    now = datetime.now(timezone.utc)
    resp = cw_client.get_metric_statistics(
        Namespace="AWS/EC2",
        MetricName=metric_name,
        Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
        StartTime=now - timedelta(minutes=5),
        EndTime=now,
        Period=300,
        Statistics=["Average"],
    )
    datapoints = resp.get("Datapoints", [])
    if not datapoints:
        return 0.0
    latest = sorted(datapoints, key=lambda x: x["Timestamp"])[-1]
    return round(latest["Average"], 2)


def _write_alert(dynamodb, server_id: str, metric_type: str,
                 value: float, severity: str) -> str:
    """Write an alert record to DynamoDB. Returns alert_id."""
    alert_id  = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()
    dynamodb.put_item(
        TableName=ALERTS_TABLE,
        Item={
            "alert_id":    {"S": alert_id},
            "serverId":    {"S": server_id},
            "timestamp":   {"S": timestamp},
            "severity":    {"S": severity},
            "metricType":  {"S": metric_type},
            "value":       {"N": str(value)},
            "status":      {"S": "OPEN"},
            "ttl":         {"N": str(int((datetime.now(timezone.utc)
                                          + timedelta(days=30)).timestamp()))},
        },
    )
    logger.info("Alert written: server=%s metric=%s value=%.2f severity=%s",
                server_id, metric_type, value, severity)
    return alert_id


def _check_sla_breach(dynamodb, sns_client, instance_id: str,
                      cpu: float, memory: float) -> None:
    """
    SLA breach prevention — track consecutive threshold violations.
    Writes a violation counter to DynamoDB. If the same instance has been
    above threshold for SLA_BREACH_POLLS consecutive polls (default 3 = 3 min),
    publishes a pre-breach SLA warning so operators can act before SLA is broken.
    """
    SLA_BREACH_POLLS = int(os.environ.get("SLA_BREACH_POLLS", "3"))
    SLA_TABLE        = os.environ.get("ALERTS_TABLE", ALERTS_TABLE)

    if cpu < CPU_THRESHOLD and memory < MEMORY_THRESHOLD:
        # Reset counter — instance is healthy
        try:
            dynamodb.delete_item(
                TableName=SLA_TABLE,
                Key={"alert_id": {"S": f"sla-counter-{instance_id}"}},
            )
        except Exception:
            pass
        return

    try:
        # Increment violation counter
        resp = dynamodb.update_item(
            TableName=SLA_TABLE,
            Key={"alert_id": {"S": f"sla-counter-{instance_id}"}},
            UpdateExpression="SET violation_count = if_not_exists(violation_count, :zero) + :one, "
                             "last_updated = :ts, instance_id = :iid",
            ExpressionAttributeValues={
                ":zero": {"N": "0"},
                ":one":  {"N": "1"},
                ":ts":   {"S": datetime.now(timezone.utc).isoformat()},
                ":iid":  {"S": instance_id},
            },
            ReturnValues="UPDATED_NEW",
        )
        count = int(resp["Attributes"]["violation_count"]["N"])
        logger.info("[SLA] instance=%s consecutive_violations=%d", instance_id, count)

        if count >= SLA_BREACH_POLLS and SNS_TOPIC_ARN:
            # Pre-breach warning — SLA at risk
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"[DevOpsGPT] SLA BREACH WARNING — {instance_id}",
                Message=json.dumps({
                    "type":               "SLA_BREACH_WARNING",
                    "instanceId":         instance_id,
                    "consecutivePolls":   count,
                    "cpuPercent":         cpu,
                    "memoryPercent":      memory,
                    "message":            f"Instance {instance_id} has exceeded thresholds "
                                          f"for {count} consecutive minutes. SLA breach imminent.",
                    "timestamp":          datetime.now(timezone.utc).isoformat(),
                }),
            )
            logger.warning("[SLA] Pre-breach warning sent for %s (%d violations)",
                           instance_id, count)
    except Exception as e:
        logger.error("[SLA] breach check failed for %s: %s", instance_id, e)


def _publish_sns(sns_client, server_id: str, metric_type: str,
                 value: float, alert_id: str) -> None:
    """Publish SNS notification for CRITICAL alerts."""
    if not SNS_TOPIC_ARN:
        logger.warning("SNS_TOPIC_ARN not set — skipping notification")
        return
    message = {
        "alertId":    alert_id,
        "serverId":   server_id,
        "metricType": metric_type,
        "value":      value,
        "severity":   "CRITICAL",
        "timestamp":  datetime.now(timezone.utc).isoformat(),
        "message":    f"CRITICAL: {metric_type} at {value:.1f}% on {server_id}",
    }
    sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[DevOpsGPT] CRITICAL Alert — {server_id}",
        Message=json.dumps(message),
    )
    logger.info("SNS published for CRITICAL alert on %s", server_id)


def handler(event, context):
    """Main Lambda handler — polls all running EC2 instances."""
    logger.info("cloudwatch_poller triggered: %s", json.dumps(event))

    ec2       = boto3.client("ec2",        region_name=AWS_REGION)
    cw        = boto3.client("cloudwatch", region_name=AWS_REGION)
    dynamodb  = boto3.client("dynamodb",   region_name=AWS_REGION)
    sns       = boto3.client("sns",        region_name=AWS_REGION)

    alerts_written = 0
    errors         = 0
    instances_checked = 0

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

        logger.info("Found %d running instances", len(instance_ids))

        for instance_id in instance_ids:
            instances_checked += 1
            try:
                # Check CPU
                cpu_value = _get_metric_statistics(cw, instance_id, "CPUUtilization")
                cpu_severity = _get_severity(cpu_value, "CPU")
                if cpu_severity:
                    alert_id = _write_alert(dynamodb, instance_id, "CPU",
                                            cpu_value, cpu_severity)
                    if cpu_severity == "CRITICAL":
                        _publish_sns(sns, instance_id, "CPU", cpu_value, alert_id)
                    alerts_written += 1

                # Check Memory (requires CloudWatch agent on instance)
                mem_value = _get_metric_statistics(cw, instance_id, "mem_used_percent")
                mem_severity = _get_severity(mem_value, "MEMORY")
                if mem_severity:
                    alert_id = _write_alert(dynamodb, instance_id, "MEMORY",
                                            mem_value, mem_severity)
                    if mem_severity == "CRITICAL":
                        _publish_sns(sns, instance_id, "MEMORY", mem_value, alert_id)
                    alerts_written += 1

                # SLA breach prevention — track consecutive threshold violations
                # If CPU or Memory has been above threshold for 3+ consecutive polls
                # (3 minutes), publish a pre-breach SLA warning via SNS
                _check_sla_breach(dynamodb, sns, instance_id, cpu_value, mem_value)

            except Exception as inst_err:
                logger.error("Error processing instance %s: %s", instance_id, inst_err)
                errors += 1

    except Exception as e:
        logger.error("Fatal error in cloudwatch_poller: %s", e)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }

    summary = {
        "instancesChecked": instances_checked,
        "alertsWritten":    alerts_written,
        "errors":           errors,
        "timestamp":        datetime.now(timezone.utc).isoformat(),
    }
    logger.info("Poll complete: %s", json.dumps(summary))
    return {"statusCode": 200, "body": json.dumps(summary)}
