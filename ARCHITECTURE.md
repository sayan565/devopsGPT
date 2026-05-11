# DevOpsGPT — Architecture Decision Record

## System Overview

DevOpsGPT is a multi-tenant SaaS platform for AI-powered AWS infrastructure monitoring
and automated remediation. It follows a serverless, event-driven architecture on AWS.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App (Web/Android)                 │
│  Dashboard │ Alerts │ AI Chat │ EC2 Instances │ Logs │ Settings  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS + x-api-key
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AWS API Gateway (REST)                         │
│  GET /servers  GET /alerts  GET /logs  POST /ai-chat  POST /fix  │
│  POST /tenants  GET /tenants-lookup  POST /ai-analysis           │
└──┬──────┬──────┬──────┬──────┬──────┬──────┬────────────────────┘
   │      │      │      │      │      │      │
   ▼      ▼      ▼      ▼      ▼      ▼      ▼
list_  alert_ metrics_ ai_   auto_  tenant_ tenant_
servers proc  streamer analyzer healer onboard lookup
   │      │      │      │      │      │      │
   └──────┴──────┴──────┴──────┴──────┴──────┘
                           │
                           ▼ STS AssumeRole (per tenant)
                    ┌──────────────┐
                    │ Tenant AWS   │
                    │ Account      │
                    │ EC2/CW/Logs  │
                    └──────────────┘

EventBridge (1 min)  ──► cloudwatch_poller ──► DynamoDB AlertsTable
                                           ──► SNS (CRITICAL only)
EventBridge (5 min)  ──► data_collector   ──► DynamoDB MetricsTable

AI Chat ──► OpenRouter API (gpt-4o-mini)
         ──► DynamoDB ChatTable (conversation history)
```

---

## Key Design Decisions

### 1. Serverless-First Architecture
**Decision:** All backend logic runs as AWS Lambda functions.  
**Rationale:** Zero server management, automatic scaling, pay-per-request pricing.
Each Lambda has a single responsibility (list_servers, alert_processor, etc.).

### 2. Multi-Tenant Cross-Account Access via STS AssumeRole
**Decision:** Each tenant has an IAM role in their own AWS account. DevOpsGPT
assumes this role using `sts:AssumeRole` with an `ExternalId` (the tenant UUID).  
**Rationale:** This is the AWS-recommended pattern for cross-account access.
No tenant credentials are stored — only the role ARN. The ExternalId prevents
confused deputy attacks.  
**Implementation:** `backend/lambdas/shared/aws_clients.py` → `get_tenant_role()`
reads the ARN from DynamoDB and calls `sts.assume_role()` per request.

### 3. Tenant Onboarding via CloudFormation
**Decision:** New tenants deploy an IAM role via a one-click CloudFormation link.  
**Rationale:** Eliminates manual IAM setup. The template is hosted on S3 and
pre-fills all parameters (master account ID, tenant UUID). Users only click
"Create Stack" and copy one ARN.  
**Template:** `infrastructure/tenant_onboarding_role.yaml`

### 4. AI via OpenRouter exclusively
**Decision:** All AI functionality uses **OpenRouter API** (`openai/gpt-4o-mini` by default).
Both the conversational chat (`ai_analyzer`) and deep infrastructure analysis (`ai_analysis`)
use OpenRouter. The model is fully configurable via the `OPENROUTER_MODEL` environment variable
— switching to Claude, Llama, or any other OpenRouter-supported model requires zero code changes.  
**Rationale:** OpenRouter provides model flexibility, no AWS Marketplace subscription required,
and consistent API across all AI use cases. The `OPENROUTER_API_KEY` is injected via Lambda
environment variable — never hardcoded.

### 5. WebSocket Feature-Flagged
**Decision:** WebSocket infrastructure is fully built but disabled via
`WEBSOCKET_ENABLED = false` in `websocket_service.dart`.  
**Rationale:** The WebSocket API Gateway endpoint, connection manager Lambda,
and DynamoDB connections table are all deployed. The feature is disabled in the
Flutter client pending the extension to push live timeseries graph data
(see FUTURE_ROADMAP.md → FS3).

### 6. Conversation History in AI Context
**Decision:** The `ai_analyzer` Lambda loads the last 10 messages from DynamoDB
and passes them as context to every OpenRouter API call.  
**Rationale:** Enables coherent multi-turn conversations. The Flutter client
also passes its in-memory history array, which takes precedence to avoid
extra DynamoDB reads.

### 7. DynamoDB with TTL + PITR
**Decision:** All tables use PAY_PER_REQUEST billing, TTL for auto-expiry,
and Point-In-Time Recovery.  
**Rationale:** No capacity planning needed. TTL keeps storage costs low
(alerts: 30 days, metrics: 7 days, fix history: 90 days). PITR enables
recovery from accidental deletes.

---

## Data Flow — Alert Detection to Auto-Heal

```
1. EventBridge triggers cloudwatch_poller every 60 seconds
2. cloudwatch_poller calls EC2 DescribeInstances → gets all running instances
3. For each instance: calls CloudWatch GetMetricStatistics (CPU, Memory)
4. If metric > threshold: writes alert to DynamoDB AlertsTable
5. If CRITICAL: publishes to SNS → email notification
6. Flutter app polls GET /alerts every 30 seconds → displays in Alerts screen
7. User taps "AI Analysis" → POST /ai-chat with server context
8. ai_analyzer loads conversation history + calls OpenRouter → returns root cause
9. User taps "Fix" → POST /fix → auto_healer executes remediation
10. Fix logged to DynamoDB FixHistoryTable with status + result
```

---

## Security Model

| Layer | Mechanism |
|-------|-----------|
| API access | API Gateway x-api-key on all routes |
| Firebase Auth | Email/password + JWT token validation |
| Cross-account | STS AssumeRole + ExternalId per tenant |
| Secrets | All credentials via `--dart-define` / Lambda env vars |
| IAM | Least-privilege per Lambda (see `infrastructure/terraform/iam.tf`) |
| DynamoDB | Tenant isolation via `tenant_id` partition key on all queries |

---

## Repository Structure

```
devopsGPT/
├── backend/
│   ├── lambdas/           # 13 Lambda functions (Python 3.11)
│   │   ├── shared/        # Shared utilities (aws_clients, response)
│   │   ├── ai_analyzer/   # Conversational AI chat
│   │   ├── list_servers/  # EC2 discovery
│   │   ├── alert_processor/ # CloudWatch alarms
│   │   └── ...
│   └── schemas/           # DynamoDB table definitions
├── frontend/
│   ├── lib/
│   │   ├── screens/       # 6 screens (Dashboard, Alerts, AI, Servers, Logs, Auth)
│   │   ├── services/      # ApiService, WebSocketService
│   │   └── widgets/       # Reusable UI components
│   └── test/              # Unit + widget tests
├── infrastructure/
│   ├── terraform/         # New modular Terraform (9 files)
│   ├── modules/           # Existing Terraform modules
│   └── tenant_onboarding_role.yaml  # CloudFormation for tenant IAM
├── .github/workflows/     # CI/CD (ci, deploy-backend, deploy-flutter, terraform)
├── README.md
├── ARCHITECTURE.md        # This file
└── FUTURE_ROADMAP.md
```
