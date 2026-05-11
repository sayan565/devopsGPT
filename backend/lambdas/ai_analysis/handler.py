"""
Lambda: ai_analysis
Route:  POST /ai-analysis
Desc:   Deep infrastructure analysis via OpenRouter API.
        Receives {serverId, metricType, value, alertHistory},
        returns structured JSON with rootCause, recommendations, riskLevel.
        Saves result to DynamoDB FixHistoryTable.
"""
import json
import logging
import os
import uuid
import urllib.request
from datetime import datetime, timezone, timedelta

import boto3

# ── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── Environment variables ─────────────────────────────────────────────────────
FIX_HISTORY_TABLE  = os.environ.get("FIX_HISTORY_TABLE", "devopsgpt-dev-fix-history")
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_MODEL   = os.environ.get("OPENROUTER_MODEL", "openai/gpt-4o-mini")
OPENROUTER_URL     = "https://openrouter.ai/api/v1/chat/completions"
AWS_REGION         = os.environ.get("AWS_REGION", "us-east-1")

# ── Analysis prompt ───────────────────────────────────────────────────────────
ANALYSIS_PROMPT = """You are a senior AWS DevOps engineer. Analyze the following infrastructure alert.

Server ID: {server_id}
Metric Type: {metric_type}
Current Value: {value}%
Alert History (last 5): {alert_history}

Respond ONLY with valid JSON in this exact format:
{{
  "rootCause": "Brief description of the most likely root cause",
  "fixRecommendations": [
    "Step 1: Specific actionable fix",
    "Step 2: Another fix option",
    "Step 3: Preventive measure"
  ],
  "riskLevel": "LOW|MEDIUM|HIGH|CRITICAL",
  "estimatedFixTime": "e.g. 5-10 minutes",
  "confidence": 0.85,
  "requiresHumanReview": false
}}"""


def _call_openrouter(server_id: str, metric_type: str,
                     value: float, alert_history: list) -> dict:
    """Call OpenRouter API for deep infrastructure analysis."""
    prompt = ANALYSIS_PROMPT.format(
        server_id=server_id,
        metric_type=metric_type,
        value=value,
        alert_history=json.dumps(alert_history[-5:] if alert_history else []),
    )

    payload = json.dumps({
        "model": OPENROUTER_MODEL,
        "messages": [
            {"role": "user", "content": prompt}
        ],
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

    content = result["choices"][0]["message"]["content"]

    # Parse JSON response
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        import re
        match = re.search(r'\{.*\}', content, re.DOTALL)
        if match:
            return json.loads(match.group())
        raise ValueError(f"Could not parse response as JSON: {content[:200]}")


def _save_analysis(dynamodb, analysis_id: str, server_id: str,
                   metric_type: str, value: float, result: dict) -> None:
    """Save analysis result to DynamoDB FixHistoryTable."""
    timestamp = datetime.now(timezone.utc).isoformat()
    dynamodb.put_item(
        TableName=FIX_HISTORY_TABLE,
        Item={
            "fixId":       {"S": analysis_id},
            "timestamp":   {"S": timestamp},
            "serverId":    {"S": server_id},
            "fixType":     {"S": "AI_ANALYSIS"},
            "status":      {"S": "COMPLETED"},
            "executedAt":  {"S": timestamp},
            "result":      {"S": json.dumps(result)},
            "metricType":  {"S": metric_type},
            "metricValue": {"N": str(value)},
            "riskLevel":   {"S": result.get("riskLevel", "UNKNOWN")},
            "confidence":  {"N": str(result.get("confidence", 0))},
            "ttl":         {"N": str(int((datetime.now(timezone.utc)
                                          + timedelta(days=90)).timestamp()))},
        },
    )
    logger.info("Analysis saved: id=%s server=%s", analysis_id, server_id)


def handler(event, context):
    """Main Lambda handler for deep AI analysis requests."""
    logger.info("ai_analysis triggered")

    try:
        body          = json.loads(event.get("body") or "{}")
        server_id     = body.get("serverId", "").strip()
        metric_type   = body.get("metricType", "CPU").strip().upper()
        value         = float(body.get("value", 0))
        alert_history = body.get("alertHistory", [])

        if not server_id:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json",
                            "Access-Control-Allow-Origin": "*"},
                "body": json.dumps({"error": "serverId is required"}),
            }

        logger.info("Analyzing: server=%s metric=%s value=%.2f",
                    server_id, metric_type, value)

        dynamodb = boto3.client("dynamodb", region_name=AWS_REGION)

        # Call OpenRouter for analysis
        analysis_result = _call_openrouter(server_id, metric_type,
                                           value, alert_history)

        # Save to DynamoDB
        analysis_id = str(uuid.uuid4())
        _save_analysis(dynamodb, analysis_id, server_id,
                       metric_type, value, analysis_result)

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({
                "analysisId":         analysis_id,
                "analysis":           analysis_result.get("rootCause", ""),
                "recommendations":    analysis_result.get("fixRecommendations", []),
                "riskLevel":          analysis_result.get("riskLevel", "UNKNOWN"),
                "estimatedFixTime":   analysis_result.get("estimatedFixTime", "Unknown"),
                "confidence":         analysis_result.get("confidence", 0),
                "requiresHumanReview":analysis_result.get("requiresHumanReview", True),
                "timestamp":          datetime.now(timezone.utc).isoformat(),
            }),
        }

    except Exception as e:
        logger.error("ai_analysis error: %s", e, exc_info=True)
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
