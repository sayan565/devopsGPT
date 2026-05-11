"""
Lambda: fix_executor
Route:  POST /fix-execute
Desc:   Executes automated fixes on AWS infrastructure.
        Supports: RESTART_SERVICE, SCALE_UP, CLEAR_CACHE, RESTART_EC2
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
FIX_HISTORY_TABLE = os.environ.get("FIX_HISTORY_TABLE", "devopsgpt-dev-fix-history")
AWS_REGION        = os.environ.get("AWS_REGION", "us-east-1")

# ── Supported fix types ───────────────────────────────────────────────────────
SUPPORTED_FIX_TYPES = {
    "RESTART_SERVICE",
    "SCALE_UP",
    "CLEAR_CACHE",
    "RESTART_EC2",
}


def _log_fix(dynamodb, fix_id: str, server_id: str, fix_type: str,
             status: str, result: dict) -> None:
    """Write fix execution record to DynamoDB."""
    timestamp = datetime.now(timezone.utc).isoformat()
    dynamodb.put_item(
        TableName=FIX_HISTORY_TABLE,
        Item={
            "fixId":      {"S": fix_id},
            "timestamp":  {"S": timestamp},
            "serverId":   {"S": server_id},
            "fixType":    {"S": fix_type},
            "status":     {"S": status},
            "executedAt": {"S": timestamp},
            "result":     {"S": json.dumps(result)},
            "ttl":        {"N": str(int((datetime.now(timezone.utc)
                                         + timedelta(days=90)).timestamp()))},
        },
    )
    logger.info("Fix logged: id=%s server=%s type=%s status=%s",
                fix_id, server_id, fix_type, status)


def _restart_ec2(ec2_client, server_id: str, parameters: dict) -> dict:
    """Reboot an EC2 instance."""
    instance_id = parameters.get("instanceId", server_id)
    ec2_client.reboot_instances(InstanceIds=[instance_id])
    logger.info("EC2 reboot initiated: %s", instance_id)
    return {"action": "reboot", "instanceId": instance_id, "status": "initiated"}


def _restart_service(ecs_client, server_id: str, parameters: dict) -> dict:
    """Force new ECS service deployment (restarts tasks)."""
    cluster = parameters.get("cluster", "default")
    service = parameters.get("service", server_id)
    ecs_client.update_service(
        cluster=cluster,
        service=service,
        forceNewDeployment=True,
    )
    logger.info("ECS service restart initiated: cluster=%s service=%s", cluster, service)
    return {"action": "restart_service", "cluster": cluster,
            "service": service, "status": "initiated"}


def _scale_up(autoscaling_client, server_id: str, parameters: dict) -> dict:
    """Increase Auto Scaling Group desired capacity."""
    asg_name        = parameters.get("asgName", server_id)
    current_desired = parameters.get("currentDesired", 1)
    new_desired     = current_desired + parameters.get("scaleIncrement", 1)
    max_size        = parameters.get("maxSize", 10)
    new_desired     = min(new_desired, max_size)

    autoscaling_client.set_desired_capacity(
        AutoScalingGroupName=asg_name,
        DesiredCapacity=new_desired,
        HonorCooldown=False,
    )
    logger.info("ASG scaled up: %s → desired=%d", asg_name, new_desired)
    return {"action": "scale_up", "asgName": asg_name,
            "newDesiredCapacity": new_desired, "status": "applied"}


def _clear_cache(ec2_client, ssm_client, server_id: str, parameters: dict) -> dict:
    """Clear application cache via SSM Run Command."""
    instance_id = parameters.get("instanceId", server_id)
    cache_type  = parameters.get("cacheType", "application")

    # Map cache type to shell command
    commands = {
        "application": "sudo systemctl restart application-cache || echo 'cache cleared'",
        "redis":       "redis-cli FLUSHALL",
        "memcached":   "echo 'flush_all' | nc localhost 11211",
        "system":      "sync && echo 3 > /proc/sys/vm/drop_caches",
    }
    command = commands.get(cache_type, commands["application"])

    response = ssm_client.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [command]},
    )
    command_id = response["Command"]["CommandId"]
    logger.info("Cache clear command sent: instance=%s commandId=%s",
                instance_id, command_id)
    return {"action": "clear_cache", "instanceId": instance_id,
            "commandId": command_id, "cacheType": cache_type, "status": "sent"}


def handler(event, context):
    """Main Lambda handler for fix execution."""
    logger.info("fix_executor triggered")

    try:
        body       = json.loads(event.get("body") or "{}")
        fix_type   = body.get("fixType", "").strip().upper()
        server_id  = body.get("serverId", "").strip()
        parameters = body.get("parameters", {})

        # Validate inputs
        if not fix_type:
            return {"statusCode": 400, "headers": {"Access-Control-Allow-Origin": "*"},
                    "body": json.dumps({"error": "fixType is required"})}
        if not server_id:
            return {"statusCode": 400, "headers": {"Access-Control-Allow-Origin": "*"},
                    "body": json.dumps({"error": "serverId is required"})}
        if fix_type not in SUPPORTED_FIX_TYPES:
            return {"statusCode": 400, "headers": {"Access-Control-Allow-Origin": "*"},
                    "body": json.dumps({"error": f"Unsupported fixType: {fix_type}",
                                        "supported": list(SUPPORTED_FIX_TYPES)})}

        fix_id   = str(uuid.uuid4())
        dynamodb = boto3.client("dynamodb",     region_name=AWS_REGION)
        ec2      = boto3.client("ec2",          region_name=AWS_REGION)
        ecs      = boto3.client("ecs",          region_name=AWS_REGION)
        asg      = boto3.client("autoscaling",  region_name=AWS_REGION)
        ssm      = boto3.client("ssm",          region_name=AWS_REGION)

        logger.info("Executing fix: id=%s type=%s server=%s",
                    fix_id, fix_type, server_id)

        # Execute the appropriate fix
        if fix_type == "RESTART_EC2":
            result = _restart_ec2(ec2, server_id, parameters)
        elif fix_type == "RESTART_SERVICE":
            result = _restart_service(ecs, server_id, parameters)
        elif fix_type == "SCALE_UP":
            result = _scale_up(asg, server_id, parameters)
        elif fix_type == "CLEAR_CACHE":
            result = _clear_cache(ec2, ssm, server_id, parameters)
        else:
            result = {"status": "unknown_fix_type"}

        # Log to DynamoDB
        _log_fix(dynamodb, fix_id, server_id, fix_type, "SUCCESS", result)

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({
                "fixId":     fix_id,
                "fixType":   fix_type,
                "serverId":  server_id,
                "status":    "SUCCESS",
                "result":    result,
                "executedAt": datetime.now(timezone.utc).isoformat(),
            }),
        }

    except Exception as e:
        logger.error("fix_executor error: %s", e, exc_info=True)
        # Attempt to log failure
        try:
            dynamodb = boto3.client("dynamodb", region_name=AWS_REGION)
            _log_fix(dynamodb, str(uuid.uuid4()),
                     body.get("serverId", "unknown"),
                     body.get("fixType", "unknown"),
                     "FAILED", {"error": str(e)})
        except Exception:
            pass
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
