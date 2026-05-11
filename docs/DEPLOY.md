# DevOpsGPT — Deployment Guide

## Prerequisites

- AWS CLI v2 configured: `aws configure`
- Terraform 1.5+: [terraform.io/downloads](https://terraform.io/downloads)
- Flutter SDK 3.x: [flutter.dev](https://flutter.dev/docs/get-started/install)
- Python 3.11+
- Your AWS Account ID ready

---

## Step 1 — Add GitHub Secrets

Go to your repo → Settings → Secrets → Actions. Add:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `API_BASE_URL` | API Gateway URL (filled after Step 3) |
| `API_KEY` | API Gateway key value (filled after Step 3) |
| `WS_URL` | WebSocket API URL (filled after Step 3) |
| `FIREBASE_API_KEY` | Firebase project API key |
| `FIREBASE_APP_ID` | Firebase app ID |

---

## Step 2 — Deploy Infrastructure with Terraform

```bash
cd infrastructure

# Initialize (downloads providers)
terraform init

# Preview what will be created
terraform plan -var-file=environments/dev/terraform.tfvars

# Deploy everything
terraform apply -var-file=environments/dev/terraform.tfvars
```

Terraform creates:
- 8 Lambda functions
- REST API Gateway (7 routes)
- WebSocket API Gateway
- 5 DynamoDB tables
- IAM roles with least-privilege policies
- CloudWatch alarms + dashboard
- EventBridge rules (1-min poller, 5-min collector)

---

## Step 3 — Get Your URLs

After `terraform apply`, run:

```bash
terraform output
```

Output:
```
api_gateway_url = "https://xxxx.execute-api.us-east-1.amazonaws.com/dev"
websocket_url   = "wss://yyyy.execute-api.us-east-1.amazonaws.com/dev"
api_key_id      = "abc123..."
```

Get the API key value:
```bash
aws apigateway get-api-key \
  --api-key $(terraform output -raw api_key_id) \
  --include-value \
  --query "value" \
  --output text
```

Update GitHub Secrets with these values.

---

## Step 4 — Run Flutter Locally

```bash
cd frontend
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/dev \
  --dart-define=API_KEY=your-api-key-value \
  --dart-define=WS_URL=wss://yyyy.execute-api.us-east-1.amazonaws.com/dev \
  --dart-define=FIREBASE_API_KEY=your-firebase-key
```

---

## Step 5 — Onboard a New Tenant

1. User signs up in the app
2. App shows the AWS Connect screen
3. User clicks **Deploy to My AWS** — opens CloudFormation with pre-filled parameters
4. CloudFormation creates `DevOpsGPTMonitorRole` in their account (read-only)
5. User copies the `RoleArn` from CloudFormation Outputs tab
6. User pastes it in the app → clicks **Connect My AWS Account**
7. Dashboard loads their EC2 instances automatically

The CloudFormation template is hosted at:
```
https://devopsgpt-cfn-templates.s3.amazonaws.com/tenant_onboarding_role.yaml
```

---

## CI/CD — Automatic on Git Push

| Files changed | Pipeline | Result |
|---------------|----------|--------|
| `infrastructure/**` | `terraform.yml` | Plan on PR, Apply on merge to main |
| `backend/**` | `deploy-backend.yml` | Zip + deploy all Lambdas + smoke tests |
| `frontend/**` | `ci.yml` | Lint + test + build APK |
| Push to `main` | `deploy-flutter.yml` | Signed APK + Firebase App Distribution |

---

## Running Tests

```bash
# Flutter tests
cd frontend
flutter test --coverage

# Python backend tests
pip install pytest pytest-cov boto3 moto
pytest backend/ -v --cov=backend/lambdas
```
