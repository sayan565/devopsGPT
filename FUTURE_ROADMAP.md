# DevOpsGPT — Future Roadmap

This document outlines the planned feature enhancements for DevOpsGPT beyond the MVP release.
Each item references the existing codebase foundation it builds upon.

---

## FS1 — Predictive AI Failure Analysis

**Priority:** HIGH  
**Status:** Planned — Sprint 3

### Current Foundation
- `frontend/lib/widgets/server_chart_widget.dart` — renders real-time CPU/Memory charts
- `backend/lambdas/data_collector/handler.py` — collects 5-minute metric snapshots to DynamoDB
- `backend/lambdas/ai_analysis/handler.py` — Bedrock integration for root cause analysis

### Next Implementation Step
1. Accumulate 30 days of metric history in `MetricsTable` (already TTL-configured for 7 days — extend to 30)
2. Export metric history to S3 in CSV format via a new `ml_exporter` Lambda
3. Train AWS SageMaker Autopilot model on the exported dataset
4. Deploy SageMaker endpoint and call it from `ai_analysis` Lambda before Bedrock analysis
5. Add `predictionScore` and `predictedFailureTime` fields to the AI response
6. Display prediction confidence in `server_chart_widget.dart` as a trend overlay

### Estimated Sprint Effort
**3 sprints (6 weeks):** 1 sprint for data pipeline, 1 for SageMaker training, 1 for UI integration

---

## FS2 — Auto-Scaling Automation

**Priority:** HIGH  
**Status:** Planned — Sprint 4

### Current Foundation
- `backend/lambdas/fix_executor/handler.py` — `SCALE_UP` fix type already implemented
- `infrastructure/terraform/eventbridge.tf` — EventBridge rules for scheduled triggers
- `infrastructure/terraform/iam.tf` — `autoscaling:SetDesiredCapacity` permission already granted

### Next Implementation Step
1. Add `confidence` field to `ai_analysis` response (already in Bedrock prompt)
2. Create `auto_executor` Lambda that reads from `FixHistoryTable` and checks confidence score
3. If `confidence >= 95%` and `riskLevel == LOW`, auto-execute the fix without human approval
4. Add `requiresHumanReview: false` path in `fix_executor` for auto-approved fixes
5. Send pre-execution notification via SNS with 5-minute cancellation window
6. Log all auto-executions to `FixHistoryTable` with `autoExecuted: true` flag

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for confidence scoring, 1 for auto-execution pipeline

---

## FS3 — Real-Time WebSocket Streaming

**Priority:** MEDIUM  
**Status:** Feature-flagged — foundation complete

### Current Foundation
- `frontend/lib/services/websocket_service.dart` — fully implemented, gated behind `WEBSOCKET_ENABLED = false`
- `backend/lambdas/websocket_handler/handler.py` — WebSocket connect/disconnect/message handler
- `infrastructure/terraform/api_gateway.tf` — API Gateway REST API (WebSocket API to be added)

### Next Implementation Step
1. Add `aws_apigatewayv2_api` WebSocket resource to `api_gateway.tf`
2. Create connection manager Lambda that stores `connectionId` in `devopsgpt-dev-ws_conns` table
3. Modify `data_collector` Lambda to broadcast metrics to all active WebSocket connections
4. Set `WEBSOCKET_ENABLED = true` in `websocket_service.dart`
5. Update `WebSocketConfig.url` default to the new WebSocket API endpoint
6. Remove REST polling fallback from `dashboard_screen.dart`

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for backend WebSocket API, 1 for Flutter integration

---

## FS4 — Multi-Cloud Support

**Priority:** MEDIUM  
**Status:** Planned — Sprint 6

### Current Foundation
- `frontend/lib/services/api_service.dart` — abstracted HTTP layer with `ApiConfig.baseUrl`
- `backend/lambdas/list_servers/handler.py` — EC2-specific but abstracted via `get_client()`
- `backend/lambdas/shared/aws_clients.py` — client factory pattern ready for extension

### Next Implementation Step
1. Define abstract `MetricCollector` interface in `backend/lambdas/shared/collector_interface.py`
2. Implement `AwsMetricCollector` (existing) and `GcpMetricCollector` (new) classes
3. Add `cloudProvider` field to `ServersTable` and tenant registration
4. Create GCP Cloud Monitoring adapter using `google-cloud-monitoring` Python SDK
5. Add Azure Monitor adapter using `azure-monitor-query` SDK
6. Update `aws_connect_screen.dart` to support GCP/Azure credential input
7. Add provider-specific CloudFormation/Deployment Manager templates

### Estimated Sprint Effort
**4 sprints (8 weeks):** 1 per cloud provider + 1 for UI/UX

---

## FS5 — Role-Based Access Control (RBAC)

**Priority:** HIGH  
**Status:** Planned — Sprint 2

### Current Foundation
- `frontend/lib/screens/auth/login_screen.dart` — Firebase Auth with email/password
- `backend/lambdas/tenant_onboarding/handler.py` — tenant registration with `uid` field
- `backend/lambdas/shared/aws_clients.py` — all Lambda calls already pass `tenant_id`

### Next Implementation Step
1. Define roles: `ADMIN`, `OPERATOR`, `VIEWER` in Firebase custom claims
2. Set custom claims via Firebase Admin SDK in `tenant_onboarding` Lambda after registration
3. Create API Gateway Lambda authorizer that validates JWT claims and role
4. Add role check middleware to `fix_executor` (only `ADMIN`/`OPERATOR` can execute fixes)
5. Update Flutter app to read role from Firebase ID token and hide/show UI elements
6. Add role management screen in settings for `ADMIN` users

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for backend authorizer, 1 for Flutter RBAC UI

---

## FS6 — AI Conversation Memory

**Priority:** LOW  
**Status:** Planned — Sprint 5

### Current Foundation
- `frontend/lib/screens/ai/ai_chat_screen.dart` — full chat UI with conversation history in memory
- `backend/lambdas/ai_analyzer/handler.py` — `_save_chat()` already writes to `devopsgpt-dev-chat`
- `frontend/lib/services/api_service.dart` — `sendAiMessageWithHistory()` passes history array

### Next Implementation Step
1. Load conversation history from `devopsgpt-dev-chat` DynamoDB table on chat screen open
2. Add `GET /chat-history?tenant_id=&session_id=` API endpoint backed by new Lambda
3. Implement sliding context window: keep last 20 messages to stay within Bedrock token limit
4. Add session management: list past sessions, resume any session by `session_id`
5. Add "Clear conversation" button that archives (not deletes) the session in DynamoDB
6. Implement semantic search over past conversations using Bedrock embeddings + DynamoDB

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for persistence API, 1 for Flutter session management UI

---

## Summary Table

| ID  | Feature                      | Priority | Sprint | Foundation File |
|-----|------------------------------|----------|--------|-----------------|
| FS1 | Predictive AI Failure Analysis | HIGH   | 3      | `server_chart_widget.dart` |
| FS2 | Auto-Scaling Automation       | HIGH    | 4      | `fix_executor/handler.py` |
| FS3 | Real-Time WebSocket Streaming | MEDIUM  | 1      | `websocket_service.dart` |
| FS4 | Multi-Cloud Support           | MEDIUM  | 6      | `api_service.dart` |
| FS5 | Role-Based Access Control     | HIGH    | 2      | `login_screen.dart` |
| FS6 | AI Conversation Memory        | LOW     | 5      | `ai_chat_screen.dart` |
