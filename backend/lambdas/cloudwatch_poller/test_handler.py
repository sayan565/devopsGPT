"""
Tests for cloudwatch_poller/handler.py
Run: pytest backend/lambdas/cloudwatch_poller/test_handler.py -v
"""
import json
import unittest
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch, call


class TestCloudwatchPollerHandler(unittest.TestCase):
    """Unit tests for the cloudwatch_poller Lambda handler."""

    def _make_cw_response(self, value: float) -> dict:
        """Helper: build a mock CloudWatch GetMetricStatistics response."""
        return {
            "Datapoints": [
                {
                    "Timestamp": datetime.now(timezone.utc),
                    "Average": value,
                    "Unit": "Percent",
                }
            ]
        }

    def _make_ec2_response(self, instance_ids: list) -> dict:
        """Helper: build a mock EC2 DescribeInstances response."""
        return {
            "Reservations": [
                {
                    "Instances": [
                        {"InstanceId": iid, "State": {"Name": "running"}}
                        for iid in instance_ids
                    ]
                }
            ]
        }

    # ── Test 1: handler returns alert on high CPU ─────────────────────────────
    @patch("boto3.client")
    def test_handler_returns_alert_on_high_cpu(self, mock_boto3_client):
        """When CPU > 80%, an alert should be written to DynamoDB."""
        mock_ec2      = MagicMock()
        mock_cw       = MagicMock()
        mock_dynamodb = MagicMock()
        mock_sns      = MagicMock()

        # Route boto3.client() calls to the right mock
        def client_factory(service, **kwargs):
            return {
                "ec2":        mock_ec2,
                "cloudwatch": mock_cw,
                "dynamodb":   mock_dynamodb,
                "sns":        mock_sns,
            }[service]

        mock_boto3_client.side_effect = client_factory

        # EC2 returns one running instance
        mock_ec2.get_paginator.return_value.paginate.return_value = [
            self._make_ec2_response(["i-0abc123"])
        ]

        # CloudWatch returns CPU = 92% (CRITICAL)
        mock_cw.get_metric_statistics.return_value = self._make_cw_response(92.0)

        from handler import handler
        result = handler({}, None)

        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertGreater(body["alertsWritten"], 0)
        # DynamoDB put_item should have been called
        mock_dynamodb.put_item.assert_called()

    # ── Test 2: no alert when CPU below threshold ─────────────────────────────
    @patch("boto3.client")
    def test_no_alert_when_cpu_below_threshold(self, mock_boto3_client):
        """When CPU < 80%, no alert should be written."""
        mock_ec2      = MagicMock()
        mock_cw       = MagicMock()
        mock_dynamodb = MagicMock()
        mock_sns      = MagicMock()

        def client_factory(service, **kwargs):
            return {"ec2": mock_ec2, "cloudwatch": mock_cw,
                    "dynamodb": mock_dynamodb, "sns": mock_sns}[service]

        mock_boto3_client.side_effect = client_factory

        mock_ec2.get_paginator.return_value.paginate.return_value = [
            self._make_ec2_response(["i-0abc123"])
        ]
        # CPU = 45% — below threshold
        mock_cw.get_metric_statistics.return_value = self._make_cw_response(45.0)

        from handler import handler
        result = handler({}, None)

        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertEqual(body["alertsWritten"], 0)
        mock_dynamodb.put_item.assert_not_called()

    # ── Test 3: DynamoDB write called with correct params ─────────────────────
    @patch("boto3.client")
    def test_dynamodb_write_called_with_correct_params(self, mock_boto3_client):
        """DynamoDB put_item should include serverId, severity, metricType."""
        mock_ec2      = MagicMock()
        mock_cw       = MagicMock()
        mock_dynamodb = MagicMock()
        mock_sns      = MagicMock()

        def client_factory(service, **kwargs):
            return {"ec2": mock_ec2, "cloudwatch": mock_cw,
                    "dynamodb": mock_dynamodb, "sns": mock_sns}[service]

        mock_boto3_client.side_effect = client_factory

        mock_ec2.get_paginator.return_value.paginate.return_value = [
            self._make_ec2_response(["i-test-001"])
        ]
        mock_cw.get_metric_statistics.return_value = self._make_cw_response(88.0)

        from handler import handler
        handler({}, None)

        # Verify put_item was called
        mock_dynamodb.put_item.assert_called()
        call_kwargs = mock_dynamodb.put_item.call_args[1]
        item = call_kwargs["Item"]

        self.assertIn("serverId",   item)
        self.assertIn("severity",   item)
        self.assertIn("metricType", item)
        self.assertIn("value",      item)
        self.assertEqual(item["serverId"]["S"], "i-test-001")

    # ── Test 4: SNS triggered for CRITICAL severity ───────────────────────────
    @patch("boto3.client")
    def test_sns_triggered_for_critical_severity(self, mock_boto3_client):
        """SNS publish should be called when CPU > 95% (CRITICAL)."""
        mock_ec2      = MagicMock()
        mock_cw       = MagicMock()
        mock_dynamodb = MagicMock()
        mock_sns      = MagicMock()

        def client_factory(service, **kwargs):
            return {"ec2": mock_ec2, "cloudwatch": mock_cw,
                    "dynamodb": mock_dynamodb, "sns": mock_sns}[service]

        mock_boto3_client.side_effect = client_factory

        mock_ec2.get_paginator.return_value.paginate.return_value = [
            self._make_ec2_response(["i-critical"])
        ]
        # CPU = 97% → CRITICAL
        mock_cw.get_metric_statistics.return_value = self._make_cw_response(97.0)

        import os
        os.environ["SNS_TOPIC_ARN"] = "arn:aws:sns:us-east-1:123456789:test-topic"

        from handler import handler
        handler({}, None)

        mock_sns.publish.assert_called()
        publish_kwargs = mock_sns.publish.call_args[1]
        self.assertIn("CRITICAL", publish_kwargs["Subject"])

    # ── Test 5: error handling when CloudWatch fails ──────────────────────────
    @patch("boto3.client")
    def test_error_handling_when_cloudwatch_fails(self, mock_boto3_client):
        """Handler should return 500 when EC2 describe_instances fails."""
        mock_ec2      = MagicMock()
        mock_cw       = MagicMock()
        mock_dynamodb = MagicMock()
        mock_sns      = MagicMock()

        def client_factory(service, **kwargs):
            return {"ec2": mock_ec2, "cloudwatch": mock_cw,
                    "dynamodb": mock_dynamodb, "sns": mock_sns}[service]

        mock_boto3_client.side_effect = client_factory

        # Simulate EC2 API failure
        mock_ec2.get_paginator.side_effect = Exception("EC2 API unavailable")

        from handler import handler
        result = handler({}, None)

        self.assertEqual(result["statusCode"], 500)
        body = json.loads(result["body"])
        self.assertIn("error", body)


if __name__ == "__main__":
    unittest.main()
