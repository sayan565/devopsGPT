"""
Lambda: websocket_handler
Routes: $connect, $disconnect, sendMetrics
Desc:   Manages WebSocket connections for real-time dashboard updates.
        Connection IDs stored in DynamoDB.
        metrics_streamer Lambda pushes data through here.
"""
import json
import boto3
import os
from datetime import datetime, timezone

CONNECTIONS_TABLE = os.environ.get("CONNECTIONS_TABLE", "devopsgpt-ws-connections")
WEBSOCKET_ENDPOINT = os.environ.get("WEBSOCKET_ENDPOINT", "")  # Set by Terraform output


def handler(event, context):
    route = event.get("requestContext", {}).get("routeKey", "")
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
                "ttl":           {"N": str(int(datetime.now(timezone.utc).timestamp()) + 7200)},  # 2hr TTL
            },
        )
        print(f"[ws] CONNECTED: {connection_id} tenant={tenant_id}")
        return {"statusCode": 200, "body": "Connected"}
    except Exception as e:
        print(f"[ws] connect error: {e}")
        return {"statusCode": 500, "body": str(e)}


def _on_disconnect(connection_id: str) -> dict:
    """Remove connection from DynamoDB."""
    try:
        dynamodb = boto3.client("dynamodb")
        dynamodb.delete_item(
            TableName=CONNECTIONS_TABLE,
            Key={"connection_id": {"S": connection_id}},
        )
        print(f"[ws] DISCONNECTED: {connection_id}")
        return {"statusCode": 200, "body": "Disconnected"}
    except Exception as e:
        print(f"[ws] disconnect error: {e}")
        return {"statusCode": 500, "body": str(e)}


def _broadcast_metrics(event: dict) -> dict:
    """
    Push a metrics payload to all connected clients for a tenant.
    Called by metrics_streamer Lambda (not the Flutter client directly).
    """
    try:
        body = json.loads(event.get("body") or "{}")
        tenant_id = body.get("tenant_id", "default")
        payload = body.get("payload", {})

        # Get all connections for this tenant
        dynamodb = boto3.client("dynamodb")
        result = dynamodb.scan(
            TableName=CONNECTIONS_TABLE,
            FilterExpression="tenant_id = :t",
            ExpressionAttributeValues={":t": {"S": tenant_id}},
        )

        endpoint_url = f"https://{WEBSOCKET_ENDPOINT}"
        apigw = boto3.client(
            "apigatewaymanagementapi",
            endpoint_url=endpoint_url,
            region_name=os.environ.get("AWS_REGION", "us-east-1"),
        )

        stale = []
        for item in result.get("Items", []):
            cid = item["connection_id"]["S"]
            try:
                apigw.post_to_connection(
                    ConnectionId=cid,
                    Data=json.dumps(payload).encode("utf-8"),
                )
            except apigw.exceptions.GoneException:
                stale.append(cid)

        # Clean up stale connections
        for cid in stale:
            dynamodb.delete_item(
                TableName=CONNECTIONS_TABLE,
                Key={"connection_id": {"S": cid}},
            )

        return {"statusCode": 200, "body": f"Pushed to {len(result.get('Items', [])) - len(stale)} clients"}

    except Exception as e:
        print(f"[ws] broadcast error: {e}")
        return {"statusCode": 500, "body": str(e)}