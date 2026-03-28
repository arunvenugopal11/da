# Da — Architecture

> Last updated: March 2026 · Stack: React Native · Next.js · AWS Lean · Terraform · GitHub Actions

---

## Contents

1. [System Overview](#1-system-overview)
2. [Client Layer](#2-client-layer)
3. [AWS Infrastructure](#3-aws-infrastructure)
4. [Data Layer](#4-data-layer)
5. [Service Layer](#5-service-layer)
6. [Async & Eventing](#6-async--eventing)
7. [Security Model](#7-security-model)
8. [Local Development](#8-local-development)
9. [CI/CD Pipeline](#9-cicd-pipeline)
10. [Secrets Management](#10-secrets-management)
11. [Cost Profile](#11-cost-profile)
12. [Architecture Decisions](#12-architecture-decisions)
13. [Scaling Path](#13-scaling-path)

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│                                                                 │
│   React Native (Expo)              Next.js 14 (Vercel)          │
│   iOS + Android                    Web PWA                      │
│   Expo Router · NativeWind         App Router · Tailwind        │
│                                                                 │
│   Shared: Zustand · TanStack Query · Supabase-less API calls    │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTPS + WSS
┌──────────────────────▼──────────────────────────────────────────┐
│                      EDGE LAYER                                 │
│                                                                 │
│        Route53 · CloudFront CDN · API Gateway HTTP v2           │
│                  API Gateway WebSocket (chat)                   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│              SERVICE LAYER  (AWS Lambda arm64)                  │
│                                                                 │
│  auth    profile    matching    premium    chat    stripe_wh    │
│                                                                 │
│          notifications  ←── SQS trigger                        │
│                                                                 │
│  All Lambdas: VPC private subnet · RDS Proxy · SSM secrets      │
└──────────┬──────────────────────┬───────────────────────────────┘
           │                      │
┌──────────▼──────────┐  ┌────────▼────────────────────────────┐
│    DATA LAYER       │  │        ASYNC LAYER                  │
│                     │  │                                     │
│  RDS PostgreSQL     │  │  SQS notification queue + DLQ       │
│  + RDS Proxy        │  │  SQS matching queue + DLQ           │
│  + PostGIS          │  │  EventBridge Scheduler (cron)       │
│                     │  │                                     │
│  DynamoDB           │  └─────────────────────────────────────┘
│  chat-connections   │
│  daily-recs cache   │  ┌─────────────────────────────────────┐
│                     │  │       THIRD-PARTY SERVICES          │
│  S3 + CloudFront    │  │                                     │
│  profile media      │  │  Stripe · Expo Push · Resend SES    │
└─────────────────────┘  └─────────────────────────────────────┘
```

---

## 2. Client Layer

### Mobile — React Native (Expo)

| Concern | Choice | Notes |
|---------|--------|-------|
| Framework | React Native + Expo bare workflow | Bare workflow from day one — `npx expo prebuild` before first commit. EAS Build, EAS Update (OTA), and all Expo SDK packages work identically in bare workflow. |
| Navigation | Expo Router | File-based, typed routes, deep links |
| State | Zustand | Lightweight, no boilerplate |
| Server state | TanStack Query | Caching, background refetch, optimistic updates |
| Styling | NativeWind (Tailwind) | Shared design tokens with web |
| Animations | Reanimated 3 | 60fps on UI thread |
| CI/CD | EAS Build + EAS Submit | Cloud builds, automatic App Store / Play Store submission |

### Web — Next.js 14 (apps/web)

| Concern | Choice |
|---------|--------|
| Framework | Next.js 14, App Router, RSC |
| Hosting | Vercel (free → Pro as traffic grows) |
| Styling | Tailwind CSS |
| PWA | Enabled — installable, offline chat history |

### Admin portal — Next.js 14 (apps/admin)

| Concern | Choice |
|---------|--------|
| Framework | Next.js 14, App Router |
| Hosting | Vercel |
| Auth | Email + password, role-based (admin / moderator / viewer) |
| Purpose | User management, verification queue, banner management, analytics |
| Shared packages | @da/types, @da/db, @da/ui |

### Mobile App — Navigation Structure

```
Bottom tabs
├── Home
│   ├── Notification / ads banner  (dynamic, from banners table)
│   ├── Premium matches            (is_premium users, blurred for free)
│   ├── New matches                (recent profiles, preference-filtered)
│   └── Recent visitors            (count only for free, full list for premium)
├── Matches
│   ├── Search                     (multi-filter: age, distance, religion, height)
│   ├── New matches
│   ├── Daily recommendations      (pre-computed, DynamoDB TTL cache)
│   ├── My matches                 (mutual likes)
│   └── Near me                    (PostGIS ST_DWithin)
├── Interests                      (likes received)
├── Chat                           (WebSocket, real-time)
└── Premium                        (plan benefits + upgrade CTA)
```

---

## 3. AWS Infrastructure

### Design principles

- **No NAT Gateway** — VPC Gateway Endpoints (free) for S3 + DynamoDB. Notification/Stripe Lambdas outside VPC. Saves $33/mo permanently.
- **No ALB** — API Gateway HTTP v2 at $1/million requests replaces ALB ($18/mo fixed).
- **No ECS** — Lambda handles all compute including WebSocket chat via API Gateway WebSocket API.
- **No ElastiCache** — DynamoDB TTL replaces Redis for the shared cache use case.
- **RDS Proxy is mandatory** — Lambda + RDS without a proxy = connection exhaustion at scale.

### VPC split

```
VPC: da-{env}-vpc
│
├── Private subnets (2 AZs)
│   ├── Lambda functions (auth, profile, matching, premium, chat)
│   ├── RDS PostgreSQL
│   └── RDS Proxy
│
└── Public subnets (2 AZs)
    └── [reserved for ALB if added later]

Outside VPC:
└── Lambda functions (notifications, stripe_webhook)
    └── Reach Expo Push / Stripe via internet directly
        No NAT Gateway needed — these have no RDS dependency

Free VPC Gateway Endpoints:
├── com.amazonaws.{region}.s3          → Lambdas reach S3 free
└── com.amazonaws.{region}.dynamodb    → Lambdas reach DynamoDB free

Interface Endpoints (small cost):
└── com.amazonaws.{region}.ssm        → Lambdas read Parameter Store without NAT
```

### Region setup

| Provider | Region | Purpose |
|----------|--------|---------|
| Primary | `ap-south-1` | All application resources |
| Virginia alias | `us-east-1` | CloudFront ACM certificates |

---

## 4. Data Layer

### RDS PostgreSQL

**Instance sizing:**

| Environment | Instance | Multi-AZ | Max connections |
|-------------|----------|----------|----------------|
| dev | db.t4g.micro | No | 87 |
| prod | db.t4g.small | Yes | 170 |

**RDS Proxy** (mandatory): Pools Lambda connections. Without it, 100 concurrent Lambda invocations exhaust the connection limit and every query fails.

**Key tables:**

```
users               id, auth_id, phone, name, dob, gender, bio, is_premium,
                    is_verified, last_active

user_locations      user_id, location geography(POINT,4326), city
                    → PostGIS index enables Near Me queries

user_preferences    user_id, looking_for[], age_min, age_max,
                    max_distance_km, religion[], height_min, height_max

profile_photos      user_id, storage_path (S3 key), is_primary, order_index

interactions        from_user_id, to_user_id, type (like/superlike/pass)
                    UNIQUE(from_user_id, to_user_id)

matches             user_id_1, user_id_2, matched_at
                    Created by trigger when both users liked each other

messages            match_id, sender_id, content, read_at
                    Persisted chat history

profile_views       viewer_id, viewed_id, viewed_at  → Recent Visitors

subscriptions       user_id, stripe_sub_id, plan, status, period dates

verifications       user_id, type (selfie|govt_id), status, verified_at

banners             type, title, body, cta_action, target_segment[],
                    priority, active_from, active_until
```

### DynamoDB

Two tables with on-demand billing (cost = $0 when idle):

| Table | Partition key | Sort key | TTL | Purpose |
|-------|--------------|----------|-----|---------|
| `da-{env}-chat-connections` | `connectionId` | — | `ttl` | WebSocket connection → userId mapping |
| `da-{env}-daily-recommendations` | `userId` | — | `expiresAt` (24hr) | Pre-computed daily match list, refreshed by cron Lambda |

### S3 + CloudFront

- Bucket: `da-{env}-media-{account_id}` — private, KMS encrypted
- CloudFront OAC — only CloudFront can read the bucket, never public
- Lambda uploads via presigned URL — client uploads directly to S3, no Lambda proxy
- CDN domain published to SSM at `/{env}/infrastructure/cloudfront/media-cdn-domain`

---

## 5. Service Layer

All Lambda functions: Bun runtime (`provided.al2023`), `arm64` Graviton2. Bun runs TypeScript source files natively — no `tsc`, no `esbuild`, no `dist/` folder. Cold starts ~70ms in VPC (4× faster than Node.js 20's ~300ms). Every function is wrapped with Middy via a shared `createHandler()` in `packages/lambda-utils`. Secrets are injected into `context` by `@middy/ssm` at cold start and cached for the Lambda lifetime — no manual SSM calls in handler code. VPC private subnet (except notifications and stripe_webhook).

| Function | Trigger | VPC | Purpose |
|----------|---------|-----|---------|
| `da-{env}-auth` | API GW HTTP | Yes | Phone OTP, JWT issuance, token refresh |
| `da-{env}-profile` | API GW HTTP | Yes | Profile CRUD, S3 presigned URL for photo upload |
| `da-{env}-matching` | API GW HTTP | Yes | Discovery, search filters, Near Me, like/pass |
| `da-{env}-premium` | API GW HTTP | Yes | Premium feature gating, plan status |
| `da-{env}-chat` | API GW WebSocket | Yes | `$connect`, `$disconnect`, `$default` |
| `da-{env}-notifications` | SQS | No | Expo Push sender |
| `da-{env}-stripe_webhook` | API GW HTTP | No | Stripe billing events → activate/deactivate premium (web) |
| `da-{env}-revenuecat_webhook` | API GW HTTP | No | RevenueCat billing events → activate/deactivate premium (iOS + Android) |

**Provisioned concurrency** (prod only): `auth` and `profile` keep 2 warm instances each, eliminating cold starts on the critical path.

**Secrets at runtime**: Lambdas read from SSM Parameter Store (`/{env}/app/*`) at cold start. No secrets in environment variables.

---

## 6. Async & Eventing

### SQS queues

Every queue follows this pattern — enforced by the Terraform module:

```
Primary queue
├── maxReceiveCount: 3           (retry 3 times before DLQ)
├── Deny non-SSL access          (queue policy)
└── DLQ (7-day retention)
    └── CloudWatch alarm         (triggers when DLQ receives any message)
```

| Queue | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `da-{env}-notification` | matching, premium, chat | notifications Lambda | Push notification fan-out |
| `da-{env}-matching` | profile | matching Lambda | Async match score computation |

### EventBridge Scheduler

Daily cron at 02:00 UTC triggers the `matching` Lambda to pre-compute recommendations for all active users and write to `da-{env}-daily-recommendations` DynamoDB table (24hr TTL).

---

## 7. Security Model

### IAM permission boundaries

Every IAM role in the project has `permissions_boundary = Da-{env}-PermissionBoundary` set. This caps the maximum permissions regardless of what the role's own policy grants. Even a wildcard `Action: "*"` role cannot exceed what the boundary allows.

The boundary explicitly denies: `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`, `organizations:*`.

### Network controls

```
Lambda security group:
  Egress: TCP 443 → VPC CIDR (SSM, S3 endpoint, DynamoDB endpoint)
  Egress: TCP 5432 → VPC CIDR (RDS)
  No ingress rules

RDS security group:
  Ingress: TCP 5432 from Lambda SG only
  No other ingress
```

### RDS access

Lambdas connect to RDS via RDS Proxy using **IAM authentication** — no database password in application code or Lambda environment variables. The proxy authenticates via `rds-db:connect` IAM permission.

### Secret flow

```
HCP Vault Secrets (free tier)
    → GitHub Actions (fetched at deploy time)
        → TF_VAR_* environment variables  (never logged, masked)
            → SSM Parameter Store SecureString  (KMS encrypted at rest)
                → Lambda reads at cold start via ssm:GetParameter
                    → Used in application code (never logged)
```

### S3 media access

S3 bucket has no public access. CloudFront uses Origin Access Control (OAC) with SigV4 signing — only CloudFront can read objects. Clients receive a presigned URL from the `profile` Lambda for direct uploads (PUT only, scoped to their own user prefix).

---

## 8. Local Development

All apps run simultaneously with `bun run dev`.

| Service | Port | Notes |
|---------|------|-------|
| API (all Lambdas via Hono) | 4000 | Hot-reload, no AWS needed |
| Web app | 3000 | Next.js dev server |
| Admin portal | 3001 | Next.js dev server |
| Mobile | 8081 | Expo dev server |
| PostgreSQL | 5432 | Docker — PostGIS + seed data |
| DynamoDB Local | 8000 | Docker — in-memory |
| ElasticMQ (SQS) | 9324/9325 | Docker — pre-creates all queues |

Secrets in local dev: `.env.local` → `localEnvMiddleware` in lambda-utils.
Production secrets: HCP Vault → SSM → `@middy/ssm` via `createHandler()`.
Handler code is identical in both environments.

---

## 9. CI/CD Pipeline

### Workflows

```
.github/workflows/
├── terraform-ci.yml    Runs on: PR + push to main
└── terraform-cd.yml    Runs on: after CI passes on main
```

### CI flow (terraform-ci.yml)

```
PR opened / push to main
│
├── fmt-check        terraform fmt -check -recursive
├── validate         terraform validate (dev + prod)
├── tfsec            Security scan — minimum severity MEDIUM
├── plan-dev         terraform plan → artifact saved
└── plan-prod        terraform plan → artifact saved (main only)
```

### CD flow (terraform-cd.yml)

```
CI passed on main
│
├── deploy-dev       terraform apply tfplan.dev  ← automatic
│
└── deploy-prod      [waits for manual approval via GitHub Environment]
                     terraform apply tfplan.prod ← click "Approve and deploy"
```

### AWS authentication

No static IAM access keys stored in GitHub. GitHub Actions authenticates via **OIDC** — assumes an IAM role using a short-lived token. The IAM role trusts `token.actions.githubusercontent.com` as the identity provider.

### GitHub Environment setup (required)

```
GitHub repo → Settings → Environments

dev:   no protection rules  (deploys automatically)
prod:  Required reviewers: [your username]  (manual gate)
```

---

## 10. Secrets Management

**HCP Vault Secrets** (free tier — 25 secrets, unlimited reads).

Two apps mirror the two environments:

| HCP App | Environment | Secrets |
|---------|-------------|---------|
| `da-dev` | dev | db_password, jwt_secret_key, stripe_webhook_secret, expo_push_token |
| `da-prod` | prod | db_password, jwt_secret_key, stripe_webhook_secret, expo_push_token |

GitHub repository secrets (Settings → Secrets → Actions):

| Secret | Purpose |
|--------|---------|
| `HCP_CLIENT_ID` | HCP service principal |
| `HCP_CLIENT_SECRET` | HCP service principal (masked) |
| `HCP_ORG_ID` | HCP organisation ID |
| `HCP_PROJECT_ID` | HCP project ID |
| `AWS_ROLE_ARN` | IAM role for OIDC assume-role |

---

## 11. Cost Profile

| Stage | MAU | Lean AWS | Standard AWS | Supabase |
|-------|-----|----------|-------------|----------|
| Dev | 5 | ~$12/mo | ~$127/mo | $0/mo |
| Launch | 5k | ~$38/mo | ~$205/mo | $25/mo |
| Growth | 100k | ~$123/mo | ~$1,074/mo | ~$57/mo |
| Scale | 1M | ~$1,050/mo | ~$9,415/mo | ~$985/mo |

**What makes lean AWS cheap:**

| Removed | Standard cost | Lean replacement | Saving |
|---------|--------------|-----------------|--------|
| NAT Gateway | $33/mo | VPC Gateway Endpoints (free) | $33/mo |
| ALB | $18/mo | API Gateway HTTP v2 | $18/mo |
| ECS Fargate | $30–60/mo | Lambda (pay per invocation) | $30–60/mo |
| ElastiCache | $15/mo | DynamoDB TTL | $15/mo |

---

## 12. Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Compute | Lambda arm64, Bun runtime | Scale to zero, Graviton2 20% cheaper, ~70ms cold start |
| Lambda runtime | Bun `provided.al2023` | Native TypeScript, no compile step, 4× faster than Node.js 20 |
| Lambda middleware | Middy | Composable middleware for SSM secrets, JSON parsing, CORS, error handling |
| DB driver | `postgres` + Drizzle ORM | Pure JS (LLRT-compatible), type-safe, works with RDS Proxy IAM auth |
| API routing | API Gateway HTTP v2 | $1/million vs ALB $18/mo fixed |
| Chat | API GW WebSocket + Lambda | No ECS needed, 2hr timeout handled by client reconnect |
| Primary DB | RDS PostgreSQL + PostGIS | Complex queries, geo support, multi-condition filters |
| Cache | DynamoDB TTL (not ElastiCache) | Shared cache at near-zero cost, no always-on instance |
| Auth | Cognito (until 80k MAU) | Free up to 50k MAU — replace with custom JWT at scale |
| Media | S3 + CloudFront OAC | Private bucket, CDN delivery, presigned upload URLs |
| IaC | Terraform ≥ 1.5 | Enterprise module pattern, remote state, reproducible |
| State | S3 + DynamoDB lock | Remote, encrypted, per-environment, team-safe |
| Secrets | HCP Vault Secrets | Free tier, clean separation from IaC, CI/CD native |
| Monorepo tool | Turborepo | Low config overhead for solo dev; NX revisit when team grows or 30+ packages |
| React Native workflow | Expo bare (prebuild on day one) | IDWise SDK, RevenueCat, WebRTC all require bare; EAS Build/Update still work |
| Mobile CI/CD | EAS Build + GitHub Actions | Bitrise free (300 credits ≈ 5 builds/mo) insufficient; EAS free = 30 builds/mo |
| iOS payments | RevenueCat + Apple IAP | Apple 3.1.1 rule — Stripe rejected on iOS; RevenueCat handles IAP + Play Billing |
| Android payments | RevenueCat + Google Play Billing | Unified RevenueCat webhook to backend |
| Web payments | Stripe only | No Apple restriction on web |
| Local dev | Docker + Hono local server | All Lambda handlers on one port, no AWS needed, instant hot-reload |
| Notifications | Expo Push SDK | Abstracts FCM + APNs, free, no SNS mobile push cost |
| Environments | dev + prod | Two-environment startup pattern, clean separation |

---

## 13. Scaling Path

| Threshold | Action | Cost impact |
|-----------|--------|-------------|
| RDS CPU > 40% | Upgrade instance class or add read replica | +$15–30/mo |
| Cognito MAU > 80k | Replace with custom JWT Lambda authorizer | -$275/mo |
| Lambda cold starts hurting UX | Add provisioned concurrency to auth + profile | +$15/mo |
| DynamoDB costs > $50/mo | Evaluate Upstash Redis or ElastiCache t4g.micro | Depends |
| S3 egress > $30/mo | Migrate media to Cloudflare R2 (zero egress) | Reduce |
| 500k users | Add RDS read replica, review Lambda concurrency limits | +$100–150/mo |
| 1M users | Full architecture review: Aurora Serverless, multi-region | Major |

**Services that do NOT change regardless of scale:**
- Lambda function code
- DynamoDB table structure
- S3 bucket configuration
- API Gateway routing rules
- Terraform module structure

---

## Repo Structure

```
da/                              ← monorepo root (parent repo, Turborepo)
├── da-infra/                    ← This Terraform repo (git history preserved)
│   ├── ARCHITECTURE.md         ← This file
│   ├── CLAUDE.md               ← Auto-loaded by Claude Code
│   ├── .cursorrules            ← Auto-loaded by Cursor IDE
│   ├── docs/PRD.md             ← Full product requirements
│   ├── bootstrap/              ← S3 state + DynamoDB lock (run once)
│   ├── environment/dev/ + prod/
│   ├── infrastructure/         ← common, sqs_*, lambda_api, rds, s3, api_gw, dynamo
│   └── resources/iam_boundary/
│
├── apps/
│   ├── mobile/                 ← Expo bare workflow (ios/ + android/ committed)
│   ├── web/                    ← Next.js 14 (user-facing PWA)
│   └── admin/                  ← Next.js 14 (internal admin portal)
│
├── packages/
│   ├── types/ · db/ · lambda-utils/ · config/ · ui/ · local-server/
│
└── services/                   ← Lambda functions (Bun runtime)
    ├── auth/ · profile/ · matching/ · chat/
    ├── notifications/ · premium/
    ├── stripe-webhook/         ← Web purchases
    └── revenuecat-webhook/     ← iOS + Android purchases
```
