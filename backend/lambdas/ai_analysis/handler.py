"""
Lambda: ai_analysis
Route:  POST /ai-analysis
Desc:   Receives server metrics + alert history, calls AWS Bedrock
        for root cause analysis, saves result to DynamoDB FixHistoryTable.
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
BEDROCK_MODEL_ID  = os.environ.get("BEDROCK_MODEL_ID",
                                   "anthropic.claude-sonnet-4-20250514-v1:0")
AWS_REGION        = os.environ.get("AWS_REGION", "us-east-1")

# ── Analysis prompt template ──────────────────────────────────────────────────
ANALYSIS_PROMPT = """You are a senior AWS DevOps engineer. Analyze the following infrastructure alert and provide a structured response.

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
  "confidence": "HIGH|MEDIUM|LOW",
  "requiresHumanReview": true|false
}}"""


def _call_bedrock(bedrock_client, server_id: str, metric_type: str,
                  value: float, alert_history: list) -> dict:
    """Call AWS Bedrock Claude model for analysis."""
    prompt = ANALYSIS_PROMPT.format(
        server_id=server_id,
        metric_type=metric_type,
        value=value,
        alert_history=json.dumps(alert_history[-5:] if alert_history else []),
    )

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [
            {"role": "user", "content": prompt}
        ],
    }

    response = bedrock_client.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        body=json.dumps(request_body),
        contentType="application/json",
        accept="application/json",
    )

    response_body = json.loads(response["body"].read())
    content = response_body["content"][0]["text"]

    # Parse the JSON response from Claude
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        # Extract JSON from markdown code block if present
        import re
        match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", content, re.DOTALL)
        if match:
            return json.loads(match.group(1))
        raise ValueError(f"Could not parse Bedrock response as JSON: {content[:200]}")


def _save_analysis(dynamodb, analysis_id: str, server_id: str,
                   metric_type: str, value: float, result: dict) -> None:
    """Save AI analysis result to DynamoDB FixHistoryTable."""
    timestamp = datetime.now(timezone.utc).isoformat()
    dynamodb.put_item(
        TableName=FIX_HISTORY_TABLE,
        Item={
            "fixId":          {"S": analysis_id},
            "timestamp":      {"S": timestamp},
            "serverId":       {"S": server_id},
            "fixType":        {"S": "AI_ANALYSIS"},
            "status":         {"S": "COMPLETED"},
            "executedAt":     {"S": timestamp},
            "result":         {"S": json.dumps(result)},
            "metricType":     {"S": metric_type},
            "metricValue":    {"N": str(value)},
            "riskLevel":      {"S": result.get("riskLevel", "UNKNOWN")},
            "ttl":            {"N": str(int((datetime.now(timezone.utc)
                                             + timedelta(days=90)).timestamp()))},
        },
    )
    logger.info("Analysis saved: id=%s server=%s", analysis_id, server_id)


def handler(event, context):
    """Main Lambda handler for AI analysis requests."""
    logger.info("ai_analysis triggered")

    try:
        body = json.loads(event.get("body") or "{}")
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

        bedrock  = boto3.client("bedrock-runtime", region_name=AWS_REGION)
        dynamodb = boto3.client("dynamodb",         region_name=AWS_REGION)

        # Call Bedrock for analysis
        analysis_result = _call_bedrock(bedrock, server_id, metric_type,
                                        value, alert_history)

        # Save to DynamoDB
        analysis_id = str(uuid.uuid4())
        _save_analysis(dynamodb, analysis_id, server_id,
                       metric_type, value, analysis_result)

        response_payload = {
            "analysisId":      analysis_id,
            "analysis":        analysis_result.get("rootCause", ""),
            "recommendations": analysis_result.get("fixRecommendations", []),
            "riskLevel":       analysis_result.get("riskLevel", "UNKNOWN"),
            "estimatedFixTime":analysis_result.get("estimatedFixTime", "Unknown"),
            "confidence":      analysis_result.get("confidence", "MEDIUM"),
            "requiresHumanReview": analysis_result.get("requiresHumanReview", True),
            "timestamp":       datetime.now(timezone.utc).isoformat(),
        }

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"},
            "body": json.dumps(response_payload),
        }

    except Exception as e:
        logger.error("ai_analysis error: %s", e, exc_info=True)
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
