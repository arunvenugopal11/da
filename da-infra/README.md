# Da — AWS Infrastructure

Terraform IaC for Da — a dating app backend on AWS. Follows enterprise patterns adapted for a 2-person startup.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  GitHub Actions                                         │
│  quality → plan-dev → plan-prod → deploy-dev          │
│  → deploy-prod (manual gate)                          │
└──────────────────────┬───────────────────────────────┘
                       │ TF_VAR_* injected from HCP Vault Secrets
┌──────────────────────▼───────────────────────────────┐
│  HCP Vault Secrets (free tier)                        │
│  /da-dev/db_password                           │
│  /da-dev/jwt_secret_key                        │
│  /da-prod/...                                  │
└──────────────────────────────────────────────────────┘
```

## Repo Structure

```
da-infra/
├── bootstrap/              # Run once: creates S3 state bucket + DynamoDB lock table
├── environment/
│   ├── dev/                # Dev environment — all module wiring
│   └── prod/               # Prod environment — same structure, different locals
├── infrastructure/         # Application modules
│   ├── common/             # VPC data, security groups, VPC endpoints, Lambda S3 bucket
│   ├── sqs_notification/   # Notification queue + DLQ + CloudWatch alarm
│   ├── sqs_matching/       # Matching queue + DLQ + CloudWatch alarm
│   ├── lambda_api/         # All Lambda functions + IAM roles
│   ├── rds_postgres/       # PostgreSQL + RDS Proxy
│   ├── s3_media/           # Profile photos bucket + CloudFront CDN
│   └── api_gateway/        # HTTP API + WebSocket API
└── resources/
    └── iam_boundary/       # Permission boundary policy — applied to all IAM roles
```

## First-Time Setup

### 1. Bootstrap state backend

```bash
cd bootstrap
terraform init
terraform apply -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
# Note the bucket name in outputs — paste into environment/*/provider.tf backend blocks
```

### 2. Create VPC (if not already existing)

Tag your VPC and subnets:
- VPC Name tag: `da-dev-vpc` / `da-prod-vpc`
- Private subnet Tier tag: `private`
- Public subnet Tier tag: `public`

### 3. Configure HCP Vault Secrets

1. Create a free account at https://portal.cloud.hashicorp.com
2. Create a project and two apps: `da-dev` and `da-prod`
3. Add secrets to each app:
   - `db_password`
   - `jwt_secret_key`
   - `stripe_webhook_secret`
   - `expo_push_token`
4. Create a service principal with **Viewer** role
5. Add `HCP_CLIENT_ID`, `HCP_CLIENT_SECRET`, `HCP_ORG_ID`, `HCP_PROJECT_ID` to GitHub Actions variables (masked)

### 4. Deploy dev

```bash
cd environment/dev
terraform init
# Export secrets locally for first run:
export TF_VAR_db_password="your-dev-password"
export TF_VAR_jwt_secret_key="your-jwt-secret"
export TF_VAR_stripe_webhook_secret="your-stripe-secret"
export TF_VAR_expo_push_token="your-expo-token"
export TF_VAR_lambda_zip_version="local"
terraform plan
terraform apply
```

## SSM Parameter Paths

All resource identifiers are published to SSM after creation:

| Path | Value |
|------|-------|
| `/{env}/infrastructure/common/vpc-id` | VPC ID |
| `/{env}/infrastructure/common/lambda-sg-id` | Lambda security group |
| `/{env}/infrastructure/sqs/notification-queue-url` | Notification queue URL |
| `/{env}/infrastructure/sqs/notification-queue-arn` | Notification queue ARN |
| `/{env}/infrastructure/sqs/notification-dlq-url` | Notification DLQ URL |
| `/{env}/infrastructure/rds/proxy-endpoint` | RDS Proxy endpoint |
| `/{env}/infrastructure/s3/media-bucket-name` | Media S3 bucket |
| `/{env}/infrastructure/cloudfront/media-cdn-domain` | CDN domain |
| `/{env}/infrastructure/lambda/{name}-arn` | Lambda function ARNs |
| `/{env}/app/jwt-secret-key` | JWT key (SecureString) |
| `/{env}/app/stripe-webhook-secret` | Stripe secret (SecureString) |
| `/{env}/app/expo-push-token` | Expo token (SecureString) |

## Cost Estimates

| Environment | Monthly cost |
|-------------|-------------|
| Dev | ~$28–35 |
| Prod (5k MAU) | ~$38–55 |
| Prod (100k MAU) | ~$123 |

## Naming Conventions

| Resource type | Pattern | Example |
|--------------|---------|---------|
| IAM role | `Da-{env}-{purpose}-role` | `Da-dev-auth-lambda-role` |
| SQS queue | `da-{env}-{purpose}` | `da-prod-notification` |
| SQS DLQ | `da-{env}-{purpose}-dlq` | `da-prod-notification-dlq` |
| Lambda | `da-{env}-{function}` | `da-dev-matching` |
| RDS | `da-{env}-postgres-{suffix}` | `da-prod-postgres-a1b2` |
| S3 bucket | `da-{env}-{purpose}-{account_id}` | `da-prod-media-123456789` |
| SSM parameter | `/{env}/infrastructure/{service}/{property}` | `/prod/infrastructure/rds/proxy-endpoint` |

## Adding a New Module

1. Copy `infrastructure/sqs_notification/` as a template
2. Add module block to `environment/dev/main.tf` and `environment/prod/main.tf`
3. Publish resource identifiers to SSM in the module's `main.tf`
4. Update this README with new SSM paths
