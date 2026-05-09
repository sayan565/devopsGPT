"""Shared HTTP response helpers for all Lambda handlers."""
import json

def ok(body) -> dict:
    return {
        "statusCode": 200,
        "headers": _cors_headers(),
        "body": json.dumps(body, default=str),
    }

def error(status: int, message: str) -> dict:
    return {
        "statusCode": status,
        "headers": _cors_headers(),
        "body": json.dumps({"error": message}),
    }

def _cors_headers() -> dict:
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,X-Api-Key,Authorization",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    }