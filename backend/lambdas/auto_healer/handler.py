"""
Lambda: auto_healer
Route:  POST /fix
Desc:   Runs remediation actions on EC2 via SSM Run Command.
        Supports: restart_service, clear_disk, restart_instance, custom_script.
        All actions are logged to DynamoDB with before/after state.
"""
import json
import sys
import os
import uuid
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client, get_tenant_role
from response import ok, error

ACTIONS_TABLE = os.environ.get("ACTIONS_TABLE", "devopsgpt-actions")

# Pre-approved healing scripts — never execute arbitrary user input
HEALING_SCRIPTS = {
    "restart_nginx": "sudo systemctl restart nginx && echo 'nginx restarted'",
    "restart_apache": "sudo systemctl restart apache2 && echo 'apache restarted'",
    "clear_disk": "sudo journalctl --vacuum-time=3d && sudo apt-get clean -y && df -h /",
    "restart_docker": "sudo systemctl restart docker && echo 'docker restarted'",
    "check_memory": "free -h && ps aux --sort=-%mem | head -10",
    "check_disk": "df -h && du -sh /var/log/* 2>/dev/null | sort -rh | head -10",
    "check_cpu": "top -bn1 | head -20",
    "clear_logs": "sudo find /var/log -name '*.log' -size +100M -delete && echo 'large logs cleared'",
    "update_packages": "sudo apt-get update -y && echo 'package list updated'",
}


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        instance_id = body.get("instance_id", "").strip()
        action = body.get("action", "").strip()
        tenant_id = body.get("tenant_id", "default")

        # Validate inputs
        if not instance_id:
            return error(400, "instance_id is required")
        if not action:
            return error(400, "action is required")
        if action not in HEALING_SCRIPTS:
            return error(400, f"Unknown action '{action}'. Allowed: {list(HEALING_SCRIPTS.keys())}")

        role_arn = get_tenant_role(tenant_id) if tenant_id != "default" else None
        ssm = get_client("ssm", role_arn)

        script = HEALING_SCRIPTS[action]
        action_id = str(uuid.uuid4())

        # Log action as STARTED
        _log_action(action_id, tenant_id, instance_id, action, "STARTED")

        # Send SSM command
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": [script]},
            Comment=f"DevOpsGPT auto-heal: {action}",
            TimeoutSeconds=60,
        )

        command_id = response["Command"]["CommandId"]

        # Poll for result (max 30s)
        output, status = _wait_for_result(ssm, command_id, instance_id)

        final_status = "SUCCESS" if status == "Success" else "FAILED"
        _log_action(action_id, tenant_id, instance_id, action, final_status, output)

        return ok({
            "action_id": action_id,
            "command_id": command_id,
            "action": action,
            "instance_id": instance_id,
            "status": final_status,
            "output": output,
        })

    except Exception as e:
        print(f"[auto_healer] ERROR: {e}")
        return error(500, str(e))


def _wait_for_result(ssm, command_id: str, instance_id: str, max_wait: int = 30):
    """Poll SSM command result for up to max_wait seconds."""
    for _ in range(max_wait // 2):
        time.sleep(2)
        try:
            result = ssm.get_command_invocation(
                CommandId=command_id,
                InstanceId=instance_id,
            )
            status = result["Status"]
            if status in ("Success", "Failed", "Cancelled", "TimedOut"):
                output = result.get("StandardOutputContent", "") or result.get("StandardErrorContent", "")
                return output.strip()[:2000], status
        except ssm.exceptions.InvocationDoesNotExist:
            continue
        except Exception as e:
            return str(e), "Failed"

    return "Command timed out waiting for result", "TimedOut"


def _log_action(action_id, tenant_id, instance_id, action, status, output=""):
    try:
        import boto3
        dynamodb = boto3.client("dynamodb")
        dynamodb.put_item(
            TableName=ACTIONS_TABLE,
            Item={
                "action_id":   {"S": action_id},
                "timestamp":   {"S": datetime.now(timezone.utc).isoformat()},
                "tenant_id":   {"S": tenant_id},
                "instance_id": {"S": instance_id},
                "action":      {"S": action},
                "status":      {"S": status},
                "output":      {"S": output[:2000]},
            },
        )
    except Exception as e:
        print(f"[auto_healer] action log failed (non-fatal): {e}")