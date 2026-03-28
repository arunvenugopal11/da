# Da — Product Requirements Document

> **AI ASSISTANT INSTRUCTIONS**
> This file is the authoritative product context for Da.
> Read this before answering any question about features, architecture, data models, or scope.
> If you are uncertain whether a change is in scope, refer to the feature list and user flows below.
> Do not suggest technologies or patterns that contradict the Architecture Decisions section.

---

## Product Overview

**Da** is a cross-platform dating app targeting users in India and other markets.

- **Mobile:** iOS + Android via React Native (Expo bare workflow)
- **Web:** Progressive Web App via Next.js 14 (App Router)
- **Backend:** AWS (Lean architecture) — Lambda, RDS PostgreSQL, API Gateway, SQS, S3, DynamoDB
- **Target scale:** 100,000 MAU initially, architected to reach 1,000,000 MAU without a rewrite

---

## Admin Portal (apps/admin)

Internal tool for the Da team. Next.js 14, hosted on Vercel, separate
from the user-facing web app.

**Auth:** Email + password. Role-based — admin, moderator, viewer.

**Features:**
- User management — view, suspend, delete accounts
- Verification queue — approve/reject selfie and govt ID submissions
- Banner management — create/edit/schedule home screen banners
- Subscription management — view/adjust premium status
- Reports — action user-reported profiles
- Analytics dashboard — DAU, MAU, match rate (read-only)

**Shared packages:** @da/types, @da/db, @da/ui

---

## Mobile App — Bottom Navigation (5 tabs)

| Tab | Route | Description |
|-----|-------|-------------|
| Home | `/home` | Dashboard — banners, premium matches, new matches, recent visitors |
| Matches | `/matches` | Tabbed match discovery |
| Interests | `/interests` | Likes/interests received from other profiles |
| Chat | `/chat` | Real-time conversations with matched users |
| Premium | `/premium` | Premium plan benefits and upgrade CTA |

---

## Home Page — 4 Sections

### 1. Notification / Ads Banner (dynamic)
- Pending verification alerts: selfie not done, govt ID not verified
- Profile incompleteness prompts: missing photos, bio, preferences
- Promotional banners: upgrade to premium, featured profiles, seasonal campaigns
- Rendered as horizontal scrollable carousel or single prominent banner
- Data source: `banners` table (Supabase/RDS) + real-time user state checks
- New banners can be added without a code deploy

### 2. Premium Matches
- Profiles with active premium subscriptions
- Horizontal scroll card list
- Blurred/locked for free users with upgrade CTA
- Source: `users` table filtered by `is_premium = true` + preference matching

### 3. New Matches
- Recently joined or recently active profiles
- Filtered by the viewing user's age/gender/location preferences

### 4. Recent Visitors
- Profiles that have viewed the current user's profile
- Free users: see count only
- Premium users: see full list with profile cards

---

## Matches Tab — 5 Sub-tabs

| Sub-tab | Description | Key tech |
|---------|-------------|----------|
| Search | Filter by age, location, height, profession, religion | RDS SQL with multi-condition WHERE |
| New Matches | Recently joined profiles matching user preferences | RDS, sorted by `created_at DESC` |
| Daily Recommendations | Algorithm-curated daily picks | Lambda cron → DynamoDB TTL cache |
| My Matches | Mutual matches (both users liked each other) | `matches` table join |
| Near Me | Location-based profiles | PostGIS `ST_DWithin` on `user_locations` |

---

## Premium Features

| Feature | Free | Premium |
|---------|------|---------|
| See who liked you | No | Yes |
| Recent visitors — full list | Count only | Full list |
| Premium Matches section | Blurred | Visible |
| Daily likes | 10/day | Unlimited |
| Superlikes | 1/day | 5/day |
| Profile boosts | — | 1/week |
| Read receipts in chat | No | Yes |

Premium billing: iOS via RevenueCat + Apple IAP, Android via RevenueCat + Google Play Billing, Web via Stripe. Plan status stored on `users.is_premium`. Activated/deactivated by `stripe_webhook` Lambda (web) and `revenuecat_webhook` Lambda (iOS + Android) on billing events.

---

## User Verification

Two verification types tracked in `verifications` table:

| Type | Status values | Shown in banner if incomplete |
|------|--------------|-------------------------------|
| `selfie` | pending / verified / failed | Yes |
| `govt_id` | pending / verified / failed | Yes |

---

## Core Data Model

### Key tables (PostgreSQL on RDS)

```
users               — profile data, is_premium, is_verified, last_active
user_locations      — geography(POINT, 4326) for PostGIS Near Me queries
user_preferences    — looking_for, age_min/max, max_distance_km, religion, height
profile_photos      — storage_path (S3), is_primary, order_index
interactions        — from_user_id, to_user_id, type (like/superlike/pass)
matches             — mutual match record, created when both users liked each other
messages            — match_id, sender_id, content, read_at (persisted chat history)
profile_views       — viewer_id, viewed_id, viewed_at (Recent Visitors feature)
subscriptions       — stripe_sub_id, plan, status, period dates
verifications       — user_id, type (selfie/govt_id), status
banners             — type, title, body, cta_action, target_segment, priority, active dates
```

### DynamoDB tables

```
da-{env}-chat-connections      — WebSocket connectionId → userId mapping (TTL)
da-{env}-daily-recommendations — userId → pre-computed profile list (24hr TTL)
```

---

## Backend Services (Lambda Functions)

| Function | Trigger | Responsibility |
|----------|---------|----------------|
| `auth` | API Gateway HTTP | Phone OTP, JWT issuance, token refresh |
| `profile` | API Gateway HTTP | User profile CRUD, photo upload (S3 presigned URL) |
| `matching` | API Gateway HTTP | Profile discovery, search filters, Near Me, interactions (like/pass) |
| `premium` | API Gateway HTTP | Premium feature gating, plan status checks |
| `chat` | API Gateway WebSocket | Connect/disconnect/message — WebSocket handler |
| `notifications` | SQS trigger | Push notification sender via Expo Push API |
| `stripe_webhook` | API Gateway HTTP | Stripe billing events → activate/deactivate premium (web) |
| `revenuecat_webhook` | API Gateway HTTP | RevenueCat billing events → activate/deactivate premium (iOS + Android) |

---

## Architecture Decisions (do not contradict these)

| Decision | Choice | Reason |
|----------|--------|--------|
| Compute | Lambda arm64 — Bun runtime | Scale to zero, Graviton2 20% cheaper, Bun cuts cold starts from ~300ms to ~70ms |
| Lambda runtime | Bun (`provided.al2023` + layer) | Runs TypeScript natively, no compile step, 4× faster cold start than Node.js 20 |
| Lambda middleware | Middy | Eliminates boilerplate — JSON parsing, SSM secrets, CORS, error handling as middleware |
| DB driver | `postgres` (pure JS) + Drizzle ORM | Pure JS, LLRT-compatible for future migration, works with RDS Proxy IAM auth |
| API layer | API Gateway HTTP v2 | $1/million requests — no ALB |
| Chat transport | API Gateway WebSocket + Lambda | No ECS for chat — Lambda handles connect/message/disconnect |
| Database | RDS PostgreSQL t4g + RDS Proxy | Complex queries, PostGIS, connection pooling |
| Cache | DynamoDB TTL (not ElastiCache) | Shared cache at near-zero cost |
| Media | S3 + CloudFront OAC | Private bucket, CDN delivery |
| Auth | AWS Cognito (until 80k MAU), then custom JWT | Cognito free up to 50k MAU |
| Secrets | HCP Vault Secrets (free tier) | Injected as TF_VAR_* by GitHub Actions CI |
| IaC | Terraform >= 1.5, AWS provider >= 5.0 | Enterprise pattern, remote state in S3 |
| Environments | dev + prod only | Two-environment startup pattern |
| State backend | S3 + DynamoDB lock | Remote state, encrypted, per-environment key |
| IAM | Permission boundaries on all roles | Prevents privilege escalation |
| NAT Gateway | Not used | VPC Gateway Endpoints for S3/DynamoDB, split VPC for Lambda |
| Monorepo tool | Turborepo | Low config overhead for solo dev; NX revisit when team grows or 30+ packages |
| React Native workflow | Expo bare (prebuild on day one) | IDWise SDK, RevenueCat, WebRTC all require bare; EAS Build/Update still work |
| Mobile CI/CD | EAS Build + GitHub Actions | Bitrise free (300 credits ≈ 5 builds/mo) insufficient; EAS free = 30 builds/mo |
| iOS payments | RevenueCat + Apple IAP | Apple 3.1.1 rule — Stripe rejected on iOS; RevenueCat handles IAP + Play Billing |
| Android payments | RevenueCat + Google Play Billing | Unified RevenueCat webhook to backend |
| Web payments | Stripe only | No Apple restriction on web |
| Local dev | Docker + Hono local server | All Lambda handlers on one port, no AWS needed, instant hot-reload |
| Notifications | Expo Push SDK | Abstracts FCM + APNs, free |

---

## Backend code structure

All Lambda handlers follow this pattern — business logic only, no boilerplate.

### Shared packages (packages/ in monorepo)

| Package | Purpose |
|---------|---------|
| `@da/lambda-utils` | `createHandler()` — wraps Middy middleware stack for all Lambdas |
| `@da/types` | Shared TypeScript interfaces: User, Match, Message, Profile, Banner |
| `@da/db` | Drizzle ORM schema + query helpers (uses `postgres` driver) |
| `@da/config` | Shared env var parsing, SSM path constants |
| `@da/ui` | Shared React components used by web and admin apps |
| `@da/local-server` | Hono dev server wrapping all Lambda handlers (port 4000) |

### Middleware stack (applied to all HTTP Lambda handlers)

1. `@middy/http-json-body-parser` — parses event.body automatically
2. `@middy/ssm` — fetches secrets from SSM at cold start, injects into context
3. `@middy/http-cors` — sets CORS headers on all responses
4. `@middy/http-error-handler` — serialises thrown errors to HTTP responses
5. `@middy/input-output-logger` — dev only

### Secrets in handlers

Secrets are never fetched manually in handler code. The Middy SSM middleware
injects them into `context` at cold start. Handlers access via `context.JWT_SECRET` etc.

---

## Mobile CI/CD

| Trigger | What runs | Build credit? |
|---------|-----------|--------------|
| PR opened | Type check + lint only | No |
| Merge to main | EAS Update (OTA push) | No |
| git tag v* | EAS Build + EAS Submit | Yes (1 per platform) |

EAS Build free tier: 30 iOS + 30 Android builds/month.
EAS Update: unlimited — covers ~90% of deployments (JS-only changes).

---

## Expo bare workflow

Da uses Expo bare workflow from day one (`npx expo prebuild` before first commit).

All Expo benefits are retained: EAS Build, EAS Update (OTA), Expo Router,
all Expo SDK packages (expo-camera, expo-location, expo-notifications, etc.),
NativeWind, Reanimated 3, Gesture Handler.

Native modules enabled by bare workflow:
- IDWise SDK — selfie + govt ID verification
- react-native-purchases (RevenueCat) — Apple IAP + Google Play Billing
- react-native-webrtc — video dates (future feature)

---

## Repo Structure

```
da/                              ← monorepo root (parent repo)
├── package.json                 ← Turborepo workspace root
├── turbo.json
├── bun.lockb
├── docker/                      ← PostgreSQL, DynamoDB Local, ElasticMQ
│
├── da-infra/                    ← This Terraform repo
│   ├── environment/
│   ├── infrastructure/
│   ├── resources/
│   └── docs/
│
├── apps/
│   ├── mobile/                  ← React Native, Expo bare workflow
│   ├── web/                     ← Next.js 14 (user-facing PWA)
│   └── admin/                   ← Next.js 14 (internal admin portal)
│
├── packages/
│   ├── types/                   ← Shared TypeScript interfaces
│   ├── db/                      ← Drizzle ORM schema + queries
│   ├── lambda-utils/            ← createHandler() + Middy stack
│   ├── config/                  ← Env vars, SSM path constants
│   ├── ui/                      ← Shared React components (web + admin)
│   └── local-server/            ← Hono dev server wrapping all Lambdas
│
└── services/                    ← Lambda functions (Bun runtime)
    ├── auth/ · profile/ · matching/ · chat/
    ├── notifications/ · premium/
    ├── stripe-webhook/          ← Web purchases
    └── revenuecat-webhook/      ← iOS + Android purchases
```

---

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| IAM role | `Da-{env}-{purpose}-role` | `Da-dev-auth-lambda-role` |
| Lambda | `da-{env}-{function}` | `da-prod-matching` |
| SQS queue | `da-{env}-{purpose}` | `da-prod-notification` |
| SQS DLQ | `da-{env}-{purpose}-dlq` | `da-prod-notification-dlq` |
| DynamoDB | `da-{env}-{purpose}` | `da-prod-chat-connections` |
| S3 bucket | `da-{env}-{purpose}-{account_id}` | `da-prod-media-123456789` |
| SSM param | `/{env}/infrastructure/{service}/{property}` | `/prod/infrastructure/rds/proxy-endpoint` |
| VPC tag | `da-{env}-vpc` | `da-dev-vpc` |

---

## SSM Parameter Store — All Published Paths

| Path | Value |
|------|-------|
| `/{env}/infrastructure/common/vpc-id` | VPC ID |
| `/{env}/infrastructure/common/lambda-sg-id` | Lambda security group ID |
| `/{env}/infrastructure/common/rds-sg-id` | RDS security group ID |
| `/{env}/infrastructure/common/lambda-code-bucket` | Lambda deployment S3 bucket |
| `/{env}/infrastructure/sqs/notification-queue-url` | Notification queue URL |
| `/{env}/infrastructure/sqs/notification-queue-arn` | Notification queue ARN |
| `/{env}/infrastructure/sqs/notification-dlq-url` | Notification DLQ URL |
| `/{env}/infrastructure/sqs/matching-queue-url` | Matching queue URL |
| `/{env}/infrastructure/sqs/matching-queue-arn` | Matching queue ARN |
| `/{env}/infrastructure/sqs/matching-dlq-url` | Matching DLQ URL |
| `/{env}/infrastructure/rds/proxy-endpoint` | RDS Proxy endpoint |
| `/{env}/infrastructure/rds/db-name` | Database name |
| `/{env}/infrastructure/s3/media-bucket-name` | Media S3 bucket name |
| `/{env}/infrastructure/cloudfront/media-cdn-domain` | CloudFront CDN domain |
| `/{env}/infrastructure/lambda/{name}-arn` | Lambda function ARNs |
| `/{env}/app/jwt-secret-key` | JWT signing key (SecureString) |
| `/{env}/app/stripe-webhook-secret` | Stripe webhook secret (SecureString) |
| `/{env}/app/expo-push-token` | Expo push token (SecureString) |

---

## Cost Targets

| Stage | Users | Target infra cost |
|-------|-------|------------------|
| Development | 5 | ~$12/mo |
| Launch | 5k MAU | ~$38/mo |
| Growth | 100k MAU | ~$123/mo |
| Scale | 1M MAU | ~$1,050/mo |

---

## Module Completion Status

| Module | Status |
|--------|--------|
| `resources/iam_boundary` | Complete |
| `infrastructure/common` | Complete |
| `infrastructure/sqs_notification` | Complete |
| `infrastructure/sqs_matching` | Complete |
| `infrastructure/lambda_api` | Complete |
| `infrastructure/rds_postgres` | Complete |
| `infrastructure/s3_media` | Complete |
| `infrastructure/api_gateway` | **TODO** |
| `infrastructure/dynamodb_chat` | **TODO** |
