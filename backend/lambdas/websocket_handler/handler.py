"""
Lambda: websocket_handler
Routes: $connect, $disconnect, sendMetrics
Desc:   Manages WebSocket connections for real-time dashboard updates.
        Connection IDs stored in DynamoDB with TTL.
        Uses GSI (tenant_id-index) Query instead of Scan for broadcast.
"""
import json
import boto3
import os
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CONNECTIONS_TABLE  = os.environ.get("CONNECTIONS_TABLE", "devopsgpt-dev-ws_conns")
WEBSOCKET_ENDPOINT = os.environ.get("WEBSOCKET_ENDPOINT", "")
# GSI name on ws_conns table — hash key: tenant_id
TENANT_GSI         = os.environ.get("TENANT_GSI_NAME", "tenant_id-index")


def handler(event, context):
    route         = event.get("requestContext", {}).get("routeKey", "")
    connection_id = event.get("requestContext", {}).get("connectionId", "")

    if route == "$connect":
        return _on_connect(connection_id, event)
    elif route == "$disconnect":
        return _on_disconnect(connection_id)
    elif route == "sendMetrics":
        return _broadcast_metrics(event)
    else:
        return {"statusCode": 400, "body": "Unknown route"}


def _on_connect(connection_id: str, event: dict) -> dict:
    """Store new connection in DynamoDB."""
    tenant_id = (event.get("queryStringParameters") or {}).get("tenant_id", "default")
    try:
        dynamodb = boto3.client("dynamodb")
        dynamodb.put_item(
            TableName=CONNECTIONS_TABLE,
            Item={
                "connection_id": {"S": connection_id},
                "tenant_id":     {"S": tenant_id},
                "connected_at":  {"S": datetime.now(timezone.utc).isoformat()},
                # 2-hour TTL — auto-cleans stale connections
                "ttl": {"N": str(int(datetime.now(timezone.utc).timestamp()) + 7200)},
            },
        )
        logger.info("[ws] CONNECTED: %s tenant=%s", connection_id, tenant_id)
        return {"statusCode": 200, "body": "Connected"}
    except Exception as e:
        logger.error("[ws] connect error: %s", e)
        return {"statusCode": 500, "body": str(e)}


def _on_disconnect(connection_id: str) -> dict:
    """Remove connection from DynamoDB."""
    try:
        dynamodb = boto3.client("dynamodb")
        dynamodb.delete_item(
            TableName=CONNECTIONS_TABLE,
            Key={"connection_id": {"S": connection_id}},
        )
        logger.info("[ws] DISCONNECTED: %s", connection_id)
        return {"statusCode": 200, "body": "Disconnected"}
    except Exception as e:
        logger.error("[ws] disconnect error: %s", e)
        return {"statusCode": 500, "body": str(e)}


def _broadcast_metrics(event: dict) -> dict:
    """
    Push a metrics payload to all connected clients for a tenant.
    Uses GSI Query on tenant_id-index instead of full-table Scan.
    Called by data_collector Lambda — not the Flutter client directly.
    """
    try:
        body      = json.loads(event.get("body") or "{}")
        tenant_id = body.get("tenant_id", "default")
        payload   = body.get("payload", {})

        dynamodb = boto3.client("dynamodb")

        # ── GSI Query (O(connections_for_tenant)) instead of full Scan ────────
        result = dynamodb.query(
            TableName=CONNECTIONS_TABLE,
            IndexName=TENANT_GSI,
            KeyConditionExpression="tenant_id = :t",
            ExpressionAttributeValues={":t": {"S": tenant_id}},
        )
        connections = result.get("Items", [])
        logger.info("[ws] broadcasting to %d connections for tenant=%s",
                    len(connections), tenant_id)

        if not connections:
            return {"statusCode": 200, "body": "No active connections"}

        endpoint_url = f"https://{WEBSOCKET_ENDPOINT}"
        apigw = boto3.client(
            "apigatewaymanagementapi",
            endpoint_url=endpoint_url,
            region_name=os.environ.get("AWS_REGION", "us-east-1"),
        )

        sent  = 0
        stale = []
        for item in connections:
            cid = item["connection_id"]["S"]
            try:
                apigw.post_to_connection(
                    ConnectionId=cid,
                    Data=json.dumps(payload).encode("utf-8"),
                )
                sent += 1
            except apigw.exceptions.GoneException:
                # Connection no longer active — mark for cleanup
                stale.append(cid)
            except Exception as e:
                logger.warning("[ws] failed to push to %s: %s", cid, e)

        # Clean up stale connections in batch
        for cid in stale:
            try:
                dynamodb.delete_item(
                    TableName=CONNECTIONS_TABLE,
                    Key={"connection_id": {"S": cid}},
                )
                logger.info("[ws] cleaned stale connection: %s", cid)
            except Exception:
                pass

        return {
            "statusCode": 200,
            "body": json.dumps({
                "sent":  sent,
                "stale": len(stale),
                "total": len(connections),
            }),
        }

    except Exception as e:
        logger.error("[ws] broadcast error: %s", e)
        return {"statusCode": 500, "body": str(e)}
