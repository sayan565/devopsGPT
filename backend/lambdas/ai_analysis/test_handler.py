"""
Tests for ai_analysis/handler.py
Run: pytest backend/lambdas/ai_analysis/test_handler.py -v
"""
import json
import unittest
from unittest.mock import MagicMock, patch
from io import BytesIO


class TestAiAnalysisHandler(unittest.TestCase):
    """Unit tests for the ai_analysis Lambda handler."""

    def _make_bedrock_response(self, content: dict) -> dict:
        """Helper: build a mock Bedrock invoke_model response."""
        body_str = json.dumps({
            "content": [{"text": json.dumps(content)}]
        })
        return {"body": BytesIO(body_str.encode("utf-8"))}

    def _make_event(self, server_id="i-test", metric_type="CPU",
                    value=92.0, alert_history=None) -> dict:
        """Helper: build a mock API Gateway event."""
        return {
            "body": json.dumps({
                "serverId":     server_id,
                "metricType":   metric_type,
                "value":        value,
                "alertHistory": alert_history or [],
            })
        }

    # ── Test 1: returns structured analysis from Bedrock ─────────────────────
    @patch("boto3.client")
    def test_returns_structured_analysis_from_bedrock(self, mock_boto3_client):
        """Handler should return analysisId, recommendations, riskLevel."""
        mock_bedrock  = MagicMock()
        mock_dynamodb = MagicMock()

        def client_factory(service, **kwargs):
            return {"bedrock-runtime": mock_bedrock,
                    "dynamodb": mock_dynamodb}[service]

        mock_boto3_client.side_effect = client_factory

        mock_bedrock.invoke_model.return_value = self._make_bedrock_response({
            "rootCause":          "Memory leak in application process",
            "fixRecommendations": ["Restart the service", "Increase memory"],
            "riskLevel":          "HIGH",
            "estimatedFixTime":   "5-10 minutes",
            "confidence":         "HIGH",
            "requiresHumanReview": False,
        })

        from handler import handler
        result = handler(self._make_event(), None)

        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertIn("analysisId",      body)
        self.assertIn("recommendations", body)
        self.assertIn("riskLevel",       body)
        self.assertEqual(body["riskLevel"], "HIGH")
        self.assertIsInstance(body["recommendations"], list)
        self.assertGreater(len(body["recommendations"]), 0)

    # ── Test 2: DynamoDB write on successful analysis ─────────────────────────
    @patch("boto3.client")
    def test_dynamodb_write_on_successful_analysis(self, mock_boto3_client):
        """DynamoDB put_item should be called after successful Bedrock call."""
        mock_bedrock  = MagicMock()
        mock_dynamodb = MagicMock()

        def client_factory(service, **kwargs):
            return {"bedrock-runtime": mock_bedrock,
                    "dynamodb": mock_dynamodb}[service]

        mock_boto3_client.side_effect = client_factory

        mock_bedrock.invoke_model.return_value = self._make_bedrock_response({
            "rootCause":          "High CPU due to runaway process",
            "fixRecommendations": ["Kill process", "Restart instance"],
            "riskLevel":          "MEDIUM",
            "estimatedFixTime":   "2-5 minutes",
            "confidence":         "MEDIUM",
            "requiresHumanReview": True,
        })

        from handler import handler
        handler(self._make_event(), None)

        mock_dynamodb.put_item.assert_called_once()
        call_kwargs = mock_dynamodb.put_item.call_args[1]
        item = call_kwargs["Item"]
        self.assertIn("fixId",    item)
        self.assertIn("serverId", item)
        self.assertIn("fixType",  item)
        self.assertEqual(item["fixType"]["S"], "AI_ANALYSIS")

    # ── Test 3: raises on missing serverId ────────────────────────────────────
    @patch("boto3.client")
    def test_raises_on_missing_server_id(self, mock_boto3_client):
        """Handler should return 400 when serverId is missing."""
        mock_bedrock  = MagicMock()
        mock_dynamodb = MagicMock()

        def client_factory(service, **kwargs):
            return {"bedrock-runtime": mock_bedrock,
                    "dynamodb": mock_dynamodb}[service]

        mock_boto3_client.side_effect = client_factory

        event = {"body": json.dumps({"metricType": "CPU", "value": 90.0})}

        from handler import handler
        result = handler(event, None)

        self.assertEqual(result["statusCode"], 400)
        body = json.loads(result["body"])
        self.assertIn("error", body)
        self.assertIn("serverId", body["error"])

    # ── Test 4: error handling when Bedrock fails ─────────────────────────────
    @patch("boto3.client")
    def test_error_handling_when_bedrock_fails(self, mock_boto3_client):
        """Handler should return 500 when Bedrock API call fails."""
        mock_bedrock  = MagicMock()
        mock_dynamodb = MagicMock()

        def client_factory(service, **kwargs):
            return {"bedrock-runtime": mock_bedrock,
                    "dynamodb": mock_dynamodb}[service]

        mock_boto3_client.side_effect = client_factory

        # Simulate Bedrock failure
        mock_bedrock.invoke_model.side_effect = Exception(
            "Bedrock service unavailable"
        )

        from handler import handler
        result = handler(self._make_event(), None)

        self.assertEqual(result["statusCode"], 500)
        body = json.loads(result["body"])
        self.assertIn("error", body)

    # ── Test 5: alert history is included in prompt ───────────────────────────
    @patch("boto3.client")
    def test_alert_history_passed_to_bedrock(self, mock_boto3_client):
        """Alert history should be included in the Bedrock request."""
        mock_bedrock  = MagicMock()
        mock_dynamodb = MagicMock()

        def client_factory(service, **kwargs):
            return {"bedrock-runtime": mock_bedrock,
                    "dynamodb": mock_dynamodb}[service]

        mock_boto3_client.side_effect = client_factory

        mock_bedrock.invoke_model.return_value = self._make_bedrock_response({
            "rootCause":          "Recurring CPU spike",
            "fixRecommendations": ["Scale up"],
            "riskLevel":          "HIGH",
            "estimatedFixTime":   "10 minutes",
            "confidence":         "HIGH",
            "requiresHumanReview": False,
        })

        alert_history = [
            {"severity": "HIGH", "timestamp": "2026-01-01T10:00:00Z"},
            {"severity": "HIGH", "timestamp": "2026-01-01T10:05:00Z"},
        ]

        from handler import handler
        result = handler(
            self._make_event(alert_history=alert_history), None
        )

        self.assertEqual(result["statusCode"], 200)
        # Verify Bedrock was called with a prompt containing the history
        mock_bedrock.invoke_model.assert_called_once()
        call_kwargs = mock_bedrock.invoke_model.call_args[1]
        request_body = json.loads(call_kwargs["body"])
        prompt_text  = request_body["messages"][0]["content"]
        self.assertIn("2026-01-01", prompt_text)


if __name__ == "__main__":
    unittest.main()
