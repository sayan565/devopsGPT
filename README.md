# DevOpsGPT — Multi-Tenant AI Cloud Monitoring & Auto-Healing Platform

A production-grade SaaS platform that monitors AWS infrastructure across multiple
customer accounts, performs AI-powered root cause analysis via Amazon Bedrock,
and auto-heals incidents using SSM Run Command — all without storing customer
access keys.

---

## Architecture

```
Flutter App (mobile/web)
        │  REST + WebSocket
        ▼
API Gateway (REST + WebSocket)
        │
        ▼
Lambda Functions
├── list_servers       → EC2 auto-discovery via describe_instances()
├── alert_processor    → CloudWatch alarm ingestion → DynamoDB
├── ai_analyzer        → Bedrock Claude root cause analysis
├── auto_healer        → SSM Run Command healing actions
├── metrics_streamer   → CloudWatch Logs reader
├── websocket_handler  → Real-time dashboard push
└── tenant_onboarding  → Cross-account IAM role registration
        │
        ▼
DynamoDB (tenants / alerts / actions / chat / ws-connections)
        │
        ▼  (STS AssumeRole — no access keys stored)
Customer AWS Accounts
├── CloudWatch alarms & metrics
├── EC2 instances
└── SSM agents
```

## Repository Structure

```
devopsgpt/
├── frontend/                  Flutter app
│   ├── lib/services/          api_service.dart, websocket_service.dart
│   └── test/                  Widget + unit tests
├── backend/
│   ├── lambdas/               One folder per Lambda function
│   ├── shared/                aws_clients.py, response.py
│   └── tests/                 pytest tests with moto mocks
├── infrastructure/
│   ├── main.tf                Root module
│   ├── variables.tf / outputs.tf / providers.tf
│   ├── modules/               lambda, api_gateway, websocket, dynamodb, iam, cloudwatch
│   ├── environments/          dev.tfvars, prod.tfvars
│   └── tenant_onboarding_role.yaml   CloudFormation for customer accounts
├── .github/workflows/
│   ├── terraform.yml          Plan on PR, Apply on merge
│   ├── lambda-deploy.yml      Zip + deploy all Lambdas
│   └── flutter.yml            Test + build APK
└── docs/
    └── DEPLOY.md              Step-by-step deploy guide
```

---

## Quick Start

### 1. Deploy infrastructure
```bash
cd infrastructure
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 2. Get URLs + API key
```bash
terraform output
aws apigateway get-api-key --api-key $(terraform output -raw api_key_id) --include-value
```

### 3. Run Flutter app locally
```bash
cd frontend
flutter run \
  --dart-define=API_BASE_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/dev \
  --dart-define=API_KEY=your-key \
  --dart-define=WS_URL=wss://yyyy.execute-api.us-east-1.amazonaws.com/dev
```

### 4. Run backend tests
```bash
cd backend
pip install -r requirements.txt
pytest -v
```

### 5. Run Flutter tests
```bash
cd frontend
flutter test
```

---

## Multi-Account Onboarding

Customers deploy one CloudFormation stack in their own AWS account:

```bash
aws cloudformation deploy \
  --template-file infrastructure/tenant_onboarding_role.yaml \
  --stack-name devopsgpt-monitoring \
  --parameter-overrides \
    DevOpsGPTMasterAccountId=YOUR_ACCOUNT_ID \
    TenantId=customer-uuid \
    AllowAutoHealing=true \
  --capabilities CAPABILITY_NAMED_IAM
```

This creates an IAM role trusted by DevOpsGPT. No access keys are ever stored.
DevOpsGPT uses `sts:AssumeRole` with `ExternalId` validation on every request.

---

## Security

- No hardcoded API keys or URLs in source code — all via `--dart-define`
- GitHub Secrets for CI/CD credentials
- IAM least-privilege: Lambda role has only the permissions it needs
- Cross-account access via `AssumeRole` + `ExternalId` (prevents confused-deputy attacks)
- API Gateway key required on all REST endpoints
- DynamoDB point-in-time recovery enabled on all tables

---

## CI/CD

| Trigger | Pipeline | Action |
|---|---|---|
| PR to main (infrastructure/) | terraform.yml | `terraform plan` |
| Push to main (infrastructure/) | terraform.yml | `terraform apply` |
| Push to main (backend/) | lambda-deploy.yml | Zip + deploy all Lambdas |
| Push to main (frontend/) | flutter.yml | Test + build APK artifact |

---

## Healing Actions

Pre-approved actions (no arbitrary command execution):

| Action | What it runs |
|---|---|
| `restart_nginx` | `systemctl restart nginx` |
| `restart_apache` | `systemctl restart apache2` |
| `clear_disk` | Clears journal + apt cache |
| `restart_docker` | `systemctl restart docker` |
| `check_memory` | `free -h` + top memory processes |
| `check_disk` | `df -h` + large files |
| `check_cpu` | `top -bn1` snapshot |
| `clear_logs` | Deletes log files >100MB |
