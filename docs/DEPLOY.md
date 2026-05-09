\# DevOpsGPT — Deploy Guide



\## Prerequisites

\- AWS CLI configured: `aws configure`

\- Terraform installed: `brew install terraform` or https://terraform.io/downloads

\- Your AWS account ID ready



\---



\## Step 1 — Restructure repo (one-time)

```bash

bash migrate\_to\_monorepo.sh

git add . \&\& git commit -m "refactor: monorepo layout"

git push

```



\---



\## Step 2 — Add GitHub Secrets

Go to your repo → Settings → Secrets → Actions. Add:



| Secret | Value |

|---|---|

| `AWS\_ACCESS\_KEY\_ID` | Your IAM user access key |

| `AWS\_SECRET\_ACCESS\_KEY` | Your IAM user secret key |

| `API\_BASE\_URL` | Filled after Step 4 |

| `API\_KEY` | Filled after Step 4 |

| `WS\_URL` | Filled after Step 4 |



\---



\## Step 3 — Deploy infrastructure with Terraform

```bash

cd infrastructure



\# Initialize (downloads providers)

terraform init



\# Preview what will be created

terraform plan -var-file=environments/dev/terraform.tfvars



\# Deploy everything

terraform apply -var-file=environments/dev/terraform.tfvars

```



Terraform will create:

\- ✅ 6 Lambda functions

\- ✅ REST API Gateway (5 routes)

\- ✅ WebSocket API

\- ✅ 5 DynamoDB tables

\- ✅ IAM roles

\- ✅ CloudWatch alarms + dashboard



\---



\## Step 4 — Get your URLs

After `terraform apply`, run:

```bash

terraform output

```



You'll see:

```

api\_gateway\_url = "https://xxxx.execute-api.us-east-1.amazonaws.com/dev"

websocket\_url   = "wss://yyyy.execute-api.us-east-1.amazonaws.com/dev"

api\_key\_id      = "abc123..."

```



Get the API key value:

```bash

aws apigateway get-api-key --api-key $(terraform output -raw api\_key\_id) --include-value

```



Update GitHub Secrets with these values.



\---



\## Step 5 — Run Flutter locally

```bash

cd frontend

flutter run \\

&#x20; --dart-define=API\_BASE\_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/dev \\

&#x20; --dart-define=API\_KEY=your-api-key-value \\

&#x20; --dart-define=WS\_URL=wss://yyyy.execute-api.us-east-1.amazonaws.com/dev

```



\---



\## Step 6 — Onboard a tenant (multi-account)



1\. Give the customer your master AWS Account ID

2\. They run in their account:

&#x20;  ```bash

&#x20;  aws cloudformation deploy \\

&#x20;    --template-file infrastructure/tenant\_onboarding\_role.yaml \\

&#x20;    --stack-name devopsgpt-monitoring \\

&#x20;    --parameter-overrides \\

&#x20;      DevOpsGPTMasterAccountId=YOUR\_ACCOUNT\_ID \\

&#x20;      TenantId=their-tenant-uuid \\

&#x20;      AllowAutoHealing=true \\

&#x20;    --capabilities CAPABILITY\_NAMED\_IAM

&#x20;  ```

3\. They send you the `RoleArn` output

4\. Register via API:

&#x20;  ```bash

&#x20;  curl -X POST https://xxxx.execute-api.us-east-1.amazonaws.com/dev/tenants/register \\

&#x20;    -H "x-api-key: YOUR\_KEY" \\

&#x20;    -H "Content-Type: application/json" \\

&#x20;    -d '{

&#x20;      "company": "Acme Corp",

&#x20;      "role\_arn": "arn:aws:iam::123456789:role/DevOpsGPTMonitoringRole",

&#x20;      "regions": \["us-east-1"]

&#x20;    }'

&#x20;  ```



\---



\## CI/CD — What happens automatically on git push



| What changed | Pipeline triggered | Result |

|---|---|---|

| `infrastructure/` | `terraform.yml` | Plan on PR, Apply on merge |

| `backend/` | `lambda-deploy.yml` | Zip + deploy all Lambdas |

| `frontend/` | `flutter.yml` | Test + build APK |



