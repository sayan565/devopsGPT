"""
Lambda: ai_analyzer
Route:  POST /ai-chat
Desc:   Accepts a user message + optional conversation history.
        Loads the last N messages from DynamoDB for multi-turn context,
        calls OpenRouter API with full thread, stores the new exchange.
"""
import json
import sys
import os
import uuid
import urllib.request
from datetime import datetime, timezone

import boto3

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "shared"))

from aws_clients import get_client
from response import ok, error

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_MODEL   = os.environ.get("OPENROUTER_MODEL", "openai/gpt-4o-mini")
OPENROUTER_URL     = "https://openrouter.ai/api/v1/chat/completions"
CHAT_TABLE         = os.environ.get("CHAT_TABLE", "devopsgpt-dev-chat")

# Maximum number of past messages to include as context (sliding window)
MAX_HISTORY_MESSAGES = 10

SYSTEM_PROMPT = """You are DevOpsGPT, an expert AWS cloud infrastructure AI assistant.
You have access to real EC2 server data, CloudWatch metrics, and alert history.

Your role is to:
1. Analyze CloudWatch alarms, EC2 metrics, and application logs
2. Identify root causes of infrastructure incidents
3. Suggest specific, actionable remediation steps with AWS CLI commands
4. Explain AWS concepts clearly and concisely

When given alarm or metric context, always:
- State the likely root cause first
- Give a confidence level (High/Medium/Low)
- List 2-3 remediation steps
- Flag if human review is needed before auto-healing

IMPORTANT: When analyzing infrastructure alerts, respond in this JSON format:
{
  "explanation": "Human-readable markdown explanation of the root cause and fix",
  "root_cause": "Brief root cause summary",
  "recommended_action": "specific_action_slug e.g. restart_service, scale_up, clear_cache",
  "confidence": 0.85,
  "reasoning": "Why this confidence level was assigned",
  "requires_human_review": false
}

For general questions (not alerts), respond with plain markdown text.
Format responses in markdown. Be concise and precise."""


def handler(event, context):
    try:
        body         = json.loads(event.get("body") or "{}")
        message      = body.get("message", "").strip()
        tenant_id    = body.get("tenant_id", "default")
        session_id   = body.get("session_id") or str(uuid.uuid4())
        context_data = body.get("context", {})
        # Client may pass its own history array (from Flutter in-memory state)
        client_history = body.get("history", [])

        if not message:
            return error(400, "message is required")

        # ── Build the user message with optional infra context ────────────────
        user_content = _build_user_message(message, context_data)

        # ── Load conversation history from DynamoDB for multi-turn context ────
        # Prefer client-supplied history (already in memory) to avoid extra
        # DynamoDB reads; fall back to loading from DB if not provided.
        if client_history:
            # Client history format: [{role, content}, ...]
            # Keep only the last MAX_HISTORY_MESSAGES entries
            conversation_messages = client_history[-MAX_HISTORY_MESSAGES:]
        else:
            conversation_messages = _load_history(tenant_id, session_id)

        # ── Call OpenRouter with full conversation thread ──────────────────────
        response_text = _call_openrouter(user_content, conversation_messages)

        # ── Try to parse structured JSON response (for alert analysis) ────────
        confidence        = None
        recommended_action = None
        requires_human_review = True
        explanation       = response_text

        try:
            import re
            # Extract JSON block if present
            json_match = re.search(r'\{[^{}]*"confidence"[^{}]*\}', response_text, re.DOTALL)
            if json_match:
                parsed = json.loads(json_match.group())
                explanation            = parsed.get("explanation", response_text)
                confidence             = parsed.get("confidence")
                recommended_action     = parsed.get("recommended_action")
                requires_human_review  = parsed.get("requires_human_review", True)
        except Exception:
            pass  # Non-fatal — use raw response_text as explanation

        # ── Persist this exchange to DynamoDB ─────────────────────────────────
        _save_chat(tenant_id, session_id, message, explanation,
                   confidence=confidence, recommended_action=recommended_action)

        response_payload = {
            "explanation": explanation,
            "response":    explanation,   # backward-compat alias
            "session_id":  session_id,
            "model":       OPENROUTER_MODEL,
        }
        if confidence is not None:
            response_payload["confidence"]           = confidence
            response_payload["recommended_action"]   = recommended_action
            response_payload["requires_human_review"] = requires_human_review

        return ok(response_payload)

    except Exception as e:
        print(f"[ai_analyzer] ERROR: {e}")
        return error(500, str(e))


def _load_history(tenant_id: str, session_id: str) -> list:
    """
    Load the last MAX_HISTORY_MESSAGES exchanges from DynamoDB for this session.
    Returns a list of {role, content} dicts ready for the OpenRouter messages array.
    """
    try:
        dynamodb = boto3.client("dynamodb", region_name=os.environ.get("AWS_REGION", "us-east-1"))
        resp = dynamodb.query(
            TableName=CHAT_TABLE,
            KeyConditionExpression="session_id = :sid",
            ExpressionAttributeValues={":sid": {"S": session_id}},
            ScanIndexForward=False,          # newest first
            Limit=MAX_HISTORY_MESSAGES,
        )
        items = resp.get("Items", [])
        # Reverse so oldest message comes first (chronological order for the model)
        items.reverse()

        messages = []
        for item in items:
            q = item.get("question", {}).get("S", "")
            a = item.get("answer",   {}).get("S", "")
            if q:
                messages.append({"role": "user",      "content": q})
            if a:
                messages.append({"role": "assistant", "content": a})
        return messages

    except Exception as e:
        print(f"[ai_analyzer] history load failed (non-fatal): {e}")
        return []


def _build_user_message(message: str, context_data: dict) -> str:
    """Append infrastructure context to the user message if provided."""
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


def _call_openrouter(user_message: str, history: list) -> str:
    """
    Call OpenRouter API with the full conversation thread.
    history: list of {role, content} dicts from previous turns.
    """
    # Build messages array: system prompt + history + new user message
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    payload = json.dumps({
        "model":      OPENROUTER_MODEL,
        "messages":   messages,
        "max_tokens": 1024,
    }).encode("utf-8")

    req = urllib.request.Request(
        OPENROUTER_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type":  "application/json",
            "HTTP-Referer":  "https://github.com/sayan565/devopsGPT",
            "X-Title":       "DevOpsGPT",
        },
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read().decode("utf-8"))

    return result["choices"][0]["message"]["content"]


def _save_chat(tenant_id: str, session_id: str, question: str, answer: str,
               confidence: float = None, recommended_action: str = None) -> None:
    """Persist the question/answer pair to DynamoDB for future context loading."""
    try:
        dynamodb = boto3.client("dynamodb", region_name=os.environ.get("AWS_REGION", "us-east-1"))
        item = {
            "session_id": {"S": session_id},
            "timestamp":  {"S": datetime.now(timezone.utc).isoformat()},
            "tenant_id":  {"S": tenant_id},
            "question":   {"S": question[:2000]},
            "answer":     {"S": answer[:5000]},
        }
        # Log confidence score if present (enables FS2 auto-healing trigger)
        if confidence is not None:
            item["confidence"] = {"N": str(round(confidence, 4))}
        if recommended_action:
            item["recommended_action"] = {"S": recommended_action}

        dynamodb.put_item(TableName=CHAT_TABLE, Item=item)
    except Exception as e:
        print(f"[ai_analyzer] chat save failed (non-fatal): {e}")
