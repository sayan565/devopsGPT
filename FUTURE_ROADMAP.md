# DevOpsGPT — Future Roadmap

This document outlines planned enhancements beyond the current MVP.
Each item references the existing codebase it builds upon and is honest
about what is already delivered vs. what remains to be built.

---

## FS1 — Predictive AI Failure Analysis

**Priority:** HIGH  
**Status:** Planned — Sprint 3

### Current Foundation
- `frontend/lib/widgets/server_chart_widget.dart` — renders real-time CPU/Memory charts
- `backend/lambdas/data_collector/handler.py` — collects 5-minute metric snapshots to DynamoDB MetricsTable
- `backend/lambdas/ai_analyzer/handler.py` — OpenRouter AI integration for root cause analysis

### What's Missing
The current system only alerts *after* a threshold is breached. There is no
predictive capability to warn before a breach occurs.

### Next Implementation Step
1. Enable **CloudWatch Anomaly Detection** on the `CPUUtilization` and
   `mem_used_percent` metrics — this uses ML-based band detection with zero
   SageMaker setup required
2. Add an `ANOMALY_DETECTION` alarm type to `cloudwatch_poller/handler.py`
   that fires when the metric exits the expected band, 15–30 minutes before
   a hard threshold breach
3. Surface the anomaly score in `server_chart_widget.dart` as a shaded
   confidence band on the existing line chart
4. Alternatively, enable **Amazon Lookout for Metrics** on the MetricsTable
   data stream for threshold-free anomaly detection across all metric dimensions

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for CloudWatch Anomaly Detection wiring,
1 sprint for UI confidence band overlay

---

## FS2 — Auto-Healing Confidence Scoring

**Priority:** HIGH  
**Status:** Partially delivered — Sprint 4

### Current Foundation
- `backend/lambdas/auto_healer/handler.py` — executes healing actions (restart, scale-up)
- `backend/lambdas/ai_analyzer/handler.py` — returns AI analysis but **no confidence score yet**
- `infrastructure/terraform/eventbridge.tf` — EventBridge rules for scheduled triggers

### What's Missing
The `auto_healer` Lambda exists and can execute fixes, but there is currently
no confidence scoring in the AI response. The >95% auto-trigger threshold
described below is the next step to implement.

### Next Implementation Step
1. Add a `confidence` field (0–100) to the `ai_analyzer` Lambda response,
   derived from the AI model's certainty about the root cause
2. Create an `auto_executor` Lambda that reads new entries from `FixHistoryTable`
   and checks `confidence >= 95` before calling `auto_healer`
3. For confidence < 95, send an SNS notification requiring human approval
4. Log all auto-executions with `autoExecuted: true` flag in `FixHistoryTable`

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for confidence scoring, 1 for auto-execution pipeline

---

## FS3 — Extended Real-Time WebSocket Streaming

**Priority:** MEDIUM  
**Status:** Foundation delivered — Sprint 1 extension

### Already Delivered
WebSocket infrastructure is **fully built and deployed**:
- `frontend/lib/services/websocket_service.dart` — WebSocket client (feature-flagged, `WEBSOCKET_ENABLED = false`)
- `backend/lambdas/websocket_handler/handler.py` — connect/disconnect/message handler
- DynamoDB `devopsgpt-dev-ws_conns` table — active connection registry
- API Gateway WebSocket endpoint: `wss://x5l8w1wmtl.execute-api.us-east-1.amazonaws.com/dev`

The feature is currently disabled in the Flutter app (`WEBSOCKET_ENABLED = false`)
pending the extension below.

### What's Missing
The current WebSocket only pushes alert notifications. The extension is to
push **live CPU/memory timeseries graph data** so `server_chart_widget.dart`
updates in real time without polling.

### Next Implementation Step
1. Modify `data_collector/handler.py` to broadcast metric snapshots to all
   active WebSocket connections after each 5-minute collection cycle
2. Update `websocket_service.dart` to parse `metrics_update` payloads and
   feed them directly into `server_chart_widget.dart`'s data stream
3. Set `WEBSOCKET_ENABLED = true` and remove the REST polling fallback
   from `dashboard_screen.dart`

### Estimated Sprint Effort
**1 sprint (2 weeks):** backend broadcast + Flutter chart integration

---

## FS4 — Multi-Cloud Support

**Priority:** MEDIUM  
**Status:** Planned — Sprint 6

### Current Foundation
- `frontend/lib/services/api_service.dart` — abstracted HTTP layer with `ApiConfig.baseUrl`
- `backend/lambdas/list_servers/handler.py` — EC2-specific but uses `get_client()` factory
- `backend/lambdas/shared/aws_clients.py` — client factory pattern ready for extension

### Next Implementation Step
1. Define abstract `MetricCollector` interface in `backend/lambdas/shared/collector_interface.py`
2. Implement `GcpMetricCollector` using `google-cloud-monitoring` Python SDK
3. Implement `AzureMetricCollector` using `azure-monitor-query` SDK
4. Add `cloudProvider` field to `ServersTable` and tenant registration
5. Update `aws_connect_screen.dart` to support GCP/Azure credential input

### Estimated Sprint Effort
**4 sprints (8 weeks):** 1 per cloud provider + 1 for UI/UX

---

## FS5 — Role-Based Access Control (RBAC)

**Priority:** HIGH  
**Status:** Planned — Sprint 2

### Current Foundation
- `frontend/lib/screens/auth/login_screen.dart` — Firebase Auth with email/password
- `backend/lambdas/tenant_onboarding/handler.py` — tenant registration with `uid` field
- Tenant isolation is already enforced via **STS AssumeRole + ExternalId** per tenant —
  this is the existing security boundary

### What's Missing
All authenticated users within a tenant currently have the same access level.
There is no distinction between read-only analysts and admins who can trigger fixes.

### Next Implementation Step
1. Add Firebase custom claims (`role: ADMIN | OPERATOR | VIEWER`) via Firebase
   Admin SDK in the `tenant_onboarding` Lambda after registration
2. Read the role from the Firebase ID token in the Flutter app and conditionally
   show/hide the "Fix" and "Scale Up" buttons based on role
3. Add a Lambda authorizer to API Gateway that validates the JWT role claim
   before allowing `POST /fix` and `POST /fix-execute` calls
4. This builds on top of the existing STS-based tenant isolation — RBAC adds
   per-user permission layers within each tenant

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for Firebase claims + Lambda authorizer,
1 sprint for Flutter role-aware UI

---

## FS6 — AI Conversation Memory (Multi-Turn Context)

**Priority:** LOW  
**Status:** Partially delivered — Sprint 5

### Already Delivered
- `frontend/lib/screens/ai/ai_chat_screen.dart` — full chat UI, passes `history` array
  to `sendAiMessageWithHistory()` on every message
- `backend/lambdas/ai_analyzer/handler.py` — **conversation history is now wired**:
  the last 10 messages from DynamoDB are loaded and passed as context into every
  OpenRouter API call, enabling coherent multi-turn analysis
- DynamoDB `devopsgpt-dev-chat` table — persists every question/answer pair with
  `session_id` + `tenant_id` + TTL

### What's Missing
Session management UI — users cannot yet browse past sessions or resume a
previous conversation by `session_id`.

### Next Implementation Step
1. Add `GET /chat-history?tenant_id=&session_id=` API endpoint backed by a
   new `chat_history` Lambda that queries the DynamoDB chat table
2. Add a session list drawer in `ai_chat_screen.dart` showing past sessions
3. Implement semantic search over past conversations using OpenRouter embeddings
   for "find similar past incidents" functionality

### Estimated Sprint Effort
**2 sprints (4 weeks):** 1 sprint for history API + session UI,
1 sprint for semantic search

---

## Summary Table

| ID  | Feature                          | Priority | Sprint | Status |
|-----|----------------------------------|----------|--------|--------|
| FS1 | Predictive AI (CloudWatch Anomaly Detection) | HIGH | 3 | Planned |
| FS2 | Auto-Healing Confidence Scoring  | HIGH     | 4      | Partial |
| FS3 | Extended WebSocket Timeseries    | MEDIUM   | 1 ext  | Foundation delivered |
| FS4 | Multi-Cloud Support              | MEDIUM   | 6      | Planned |
| FS5 | Role-Based Access Control        | HIGH     | 2      | Planned |
| FS6 | AI Conversation Memory           | LOW      | 5      | Partial |
