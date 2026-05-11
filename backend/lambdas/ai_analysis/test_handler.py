"""
Tests for ai_analysis/handler.py
Uses OpenRouter API (mocked via urllib.request).
Run: pytest backend/lambdas/ai_analysis/test_handler.py -v
"""
import json
import unittest
from unittest.mock import MagicMock, patch
from io import BytesIO


class TestAiAnalysisHandler(unittest.TestCase):
    """Unit tests for the ai_analysis Lambda handler."""

    def _make_openrouter_response(self, content: dict) -> MagicMock:
        """Helper: build a mock urllib response for OpenRouter."""
        mock_resp = MagicMock()
        mock_resp.read.return_value = json.dumps({
            "choices": [{"message": {"content": json.dumps(content)}}]
        }).encode("utf-8")
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        return mock_resp

    def _make_event(self, server_id="i-test", metric_type="CPU",
                    value=92.0, alert_history=None) -> dict:
        return {
            "body": json.dumps({
                "serverId":     server_id,
                "metricType":   metric_type,
                "value":        value,
                "alertHistory": alert_history or [],
            })
        }

    # ── Test 1: returns structured analysis ──────────────────────────────────
    @patch("boto3.client")
    @patch("urllib.request.urlopen")
    def test_returns_structured_analysis(self, mock_urlopen, mock_boto3):
        """Handler should return analysisId, recommendations, riskLevel."""
        mock_dynamodb = MagicMock()
        mock_boto3.return_value = mock_dynamodb
        mock_urlopen.return_value = self._make_openrouter_response({
            "rootCause":          "Memory leak in application process",
            "fixRecommendations": ["Restart the service", "Increase memory"],
            "riskLevel":          "HIGH",
            "estimatedFixTime":   "5-10 minutes",
            "confidence":         0.87,
            "requiresHumanReview": False,
        })

        from handler import handler
        result = handler(self._make_event(), None)

        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertIn("analysisId",      body)
        self.assertIn("recommendations", body)
        self.assertIn("riskLevel",       body)
        self.assertIn("confidence",      body)
        self.assertEqual(body["riskLevel"], "HIGH")
        self.assertGreater(len(body["recommendations"]), 0)

    # ── Test 2: DynamoDB write on successful analysis ─────────────────────────
    @patch("boto3.client")
    @patch("urllib.request.urlopen")
    def test_dynamodb_write_on_successful_analysis(self, mock_urlopen, mock_boto3):
        """DynamoDB put_item should be called after successful analysis."""
        mock_dynamodb = MagicMock()
        mock_boto3.return_value = mock_dynamodb
        mock_urlopen.return_value = self._make_openrouter_response({
            "rootCause":          "High CPU due to runaway process",
            "fixRecommendations": ["Kill process", "Restart instance"],
            "riskLevel":          "MEDIUM",
            "estimatedFixTime":   "2-5 minutes",
            "confidence":         0.75,
            "requiresHumanReview": True,
        })

        from handler import handler
        handler(self._make_event(), None)

        mock_dynamodb.put_item.assert_called_once()
        item = mock_dynamodb.put_item.call_args[1]["Item"]
        self.assertIn("fixId",    item)
        self.assertIn("serverId", item)
        self.assertEqual(item["fixType"]["S"], "AI_ANALYSIS")
        self.assertIn("confidence", item)

    # ── Test 3: returns 400 on missing serverId ───────────────────────────────
    @patch("boto3.client")
    @patch("urllib.request.urlopen")
    def test_returns_400_on_missing_server_id(self, mock_urlopen, mock_boto3):
        """Handler should return 400 when serverId is missing."""
        event = {"body": json.dumps({"metricType": "CPU", "value": 90.0})}

        from handler import handler
        result = handler(event, None)

        self.assertEqual(result["statusCode"], 400)
        body = json.loads(result["body"])
        self.assertIn("serverId", body["error"])

    # ── Test 4: error handling when OpenRouter fails ──────────────────────────
    @patch("boto3.client")
    @patch("urllib.request.urlopen")
    def test_error_handling_when_openrouter_fails(self, mock_urlopen, mock_boto3):
        """Handler should return 500 when OpenRouter API call fails."""
        mock_boto3.return_value = MagicMock()
        mock_urlopen.side_effect = Exception("OpenRouter service unavailable")

        from handler import handler
        result = handler(self._make_event(), None)

        self.assertEqual(result["statusCode"], 500)
        body = json.loads(result["body"])
        self.assertIn("error", body)

    # ── Test 5: alert history is included in prompt ───────────────────────────
    @patch("boto3.client")
    @patch("urllib.request.urlopen")
    def test_alert_history_passed_to_openrouter(self, mock_urlopen, mock_boto3):
        """Alert history should be included in the OpenRouter request."""
        mock_boto3.return_value = MagicMock()
        mock_urlopen.return_value = self._make_openrouter_response({
            "rootCause":          "Recurring CPU spike",
            "fixRecommendations": ["Scale up"],
            "riskLevel":          "HIGH",
            "estimatedFixTime":   "10 minutes",
            "confidence":         0.90,
            "requiresHumanReview": False,
        })

        alert_history = [
            {"severity": "HIGH", "timestamp": "2026-01-01T10:00:00Z"},
            {"severity": "HIGH", "timestamp": "2026-01-01T10:05:00Z"},
        ]

        from handler import handler
        result = handler(self._make_event(alert_history=alert_history), None)

        self.assertEqual(result["statusCode"], 200)
        # Verify urlopen was called with a request containing the history
        mock_urlopen.assert_called_once()
        call_args = mock_urlopen.call_args[0][0]
        request_body = json.loads(call_args.data.decode("utf-8"))
        prompt_text  = request_body["messages"][0]["content"]
        self.assertIn("2026-01-01", prompt_text)


if __name__ == "__main__":
    unittest.main()
