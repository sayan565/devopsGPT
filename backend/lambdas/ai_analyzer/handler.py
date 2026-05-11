"""
Lambda: ai_analyzer
Route:  POST /ai-chat
Desc:   Accepts a user message + optional context (alarm, logs, metrics).
        Calls OpenRouter API (Claude via HTTP) for AI root cause analysis.
        Stores conversation in DynamoDB for history.
"""
import json
import sys
import os
import uuid
import urllib.request
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client
from response import ok, error

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_MODEL = os.environ.get("OPENROUTER_MODEL", "anthropic/claude-3.5-sonnet")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
CHAT_TABLE = os.environ.get("CHAT_TABLE", "devopsgpt-chat-history")

SYSTEM_PROMPT = """You are DevOpsGPT, an expert AWS cloud infrastructure AI assistant.
Your role is to:
1. Analyze CloudWatch alarms, EC2 metrics, and application logs
2. Identify root causes of infrastructure incidents
3. Suggest specific, actionable remediation steps
4. Explain AWS concepts clearly

When given alarm or metric context, always:
- State the likely root cause first
- Give confidence level (High/Medium/Low)
- List 2-3 remediation steps with AWS CLI commands when relevant
- Flag if human review is needed before auto-healing

Be concise and precise. Format responses in markdown."""


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        message = body.get("message", "").strip()
        tenant_id = body.get("tenant_id", "default")
        session_id = body.get("session_id") or str(uuid.uuid4())
        context_data = body.get("context", {})

        if not message:
            return error(400, "message is required")

        user_content = _build_user_message(message, context_data)
        response_text = _call_openrouter(user_content)
        _save_chat(tenant_id, session_id, message, response_text)

        return ok({
            "explanation": response_text,
            "response": response_text,
            "session_id": session_id,
            "model": OPENROUTER_MODEL,
        })

    except Exception as e:
        print(f"[ai_analyzer] ERROR: {e}")
        return error(500, str(e))


def _build_user_message(message: str, context_data: dict) -> str:
    if not context_data:
        return message

    ctx_parts = [message, "\n\n**Infrastructure Context:**"]

    if context_data.get("alarm"):
        alarm = context_data["alarm"]
        ctx_parts.append(
            f"- Alarm: {alarm.get('name')} | State: {alarm.get('state')} "
            f"| Metric: {alarm.get('metric')} | Threshold: {alarm.get('threshold')}"
        )
    if context_data.get("cpu"):
        ctx_parts.append(f"- CPU Utilization: {context_data['cpu']}%")
    if context_data.get("logs"):
        ctx_parts.append("- Recent log errors:")
        for log in context_data["logs"][:5]:
            ctx_parts.append(f"  `{log}`")
    if context_data.get("instance_id"):
        ctx_parts.append(f"- Instance: {context_data['instance_id']}")

    return "\n".join(ctx_parts)


def _call_openrouter(user_message: str) -> str:
    """Call OpenRouter API using only stdlib (no requests needed in Lambda)."""
    payload = json.dumps({
        "model": OPENROUTER_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ],
        "max_tokens": 1024,
    }).encode("utf-8")

    req = urllib.request.Request(
        OPENROUTER_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com/sayan565/devopsGPT",
            "X-Title": "DevOpsGPT",
        },
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read().decode("utf-8"))

    return result["choices"][0]["message"]["content"]


def _save_chat(tenant_id: str, session_id: str, question: str, answer: str):
    try:
        import boto3
        dynamodb = boto3.client("dynamodb")
        dynamodb.put_item(
            TableName=CHAT_TABLE,
            Item={
                "session_id": {"S": session_id},
                "timestamp":  {"S": datetime.now(timezone.utc).isoformat()},
                "tenant_id":  {"S": tenant_id},
                "question":   {"S": question[:2000]},
                "answer":     {"S": answer[:5000]},
            },
        )
    except Exception as e:
        print(f"[ai_analyzer] chat save failed (non-fatal): {e}")