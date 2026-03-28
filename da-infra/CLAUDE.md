# Da — Claude Code Context

This is the infrastructure repository for **Da**, a dating app built on AWS with Terraform.

## Read first

Before doing anything in this repo, read [`docs/PRD.md`](docs/PRD.md).
It contains the full product requirements, data model, architecture decisions, naming conventions,
SSM parameter paths, and module completion status.

## What this repo is

Terraform IaC only. No application code lives here.
This repo lives at `da/da-infra/` inside the `da` Turborepo monorepo.
Application code (React Native, Next.js, Lambda handlers) lives in the monorepo alongside this folder.

## Key rules — never violate these

- Every IAM role MUST include `permissions_boundary = var.boundary_policy_arn`
- Every SQS queue MUST have a paired DLQ — no standalone queues
- Every resource identifier MUST be published to SSM after creation at `/{env}/infrastructure/{service}/{property}`
- Secrets (passwords, API keys, tokens) MUST be `sensitive = true` variables — never hardcoded
- Provider `default_tags` MUST be set — every resource inherits `application_name`, `deployment_environment`, `deployment_source`, `project`
- All modules MUST include `versions.tf`, `data.tf`, `locals.tf`, `variables.tf`, `main.tf`, `outputs.tf`
- Naming prefix for all resources: `da-{env}-*` (lowercase) for AWS resources, `Da-{env}-*` for IAM roles

## Adding a new module

1. Copy `infrastructure/sqs_notification/` as a starting template
2. Follow the 6-file structure: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `versions.tf`
3. Add `var.boundary_policy_arn` to `variables.tf` if creating IAM roles
4. Publish all resource identifiers to SSM at the bottom of `main.tf`
5. Add the module call to both `environment/dev/main.tf` and `environment/prod/main.tf`
6. Update `docs/PRD.md` module completion status table

## Environments

- `dev` — `db.t4g.micro`, `multi_az = false`, log retention 14 days
- `prod` — `db.t4g.small`, `multi_az = true`, log retention 90 days, deletion_protection = true

## Monorepo & apps

- Root: `da/` monorepo using Turborepo (not NX)
- This Terraform repo lives at `da/da-infra/`
- Apps: `apps/mobile` (Expo bare), `apps/web` (Next.js), `apps/admin` (Next.js)
- Run a single app: `turbo dev --filter=@da/mobile`
- Admin portal is at apps/admin — Next.js, internal team only, email+password auth

## Mobile

- Expo BARE workflow — ios/ and android/ folders committed from day one
- EAS Build for native builds (30 free/month), EAS Update for OTA (unlimited)
- Bitrise is NOT used
- iOS payments: RevenueCat + Apple IAP (NOT Stripe — App Store rule 3.1.1)
- Android payments: RevenueCat + Google Play Billing
- Web payments: Stripe only

## Local development

- `bun run dev` starts everything simultaneously
- API server: http://localhost:4000 (all Lambda handlers via Hono, hot-reload)
- Infrastructure: `bun run dev:infra` (PostgreSQL, DynamoDB, ElasticMQ via Docker)
- Secrets: .env.local → localEnvMiddleware (same context.JWT_SECRET as production)
- Never call AWS locally — everything runs on Docker equivalents

## Backend runtime

- Runtime is Bun (`provided.al2023` + arm64 layer) — NOT Node.js 20
- TypeScript runs natively — no tsc, no esbuild, no dist/ folder
- All Lambdas use Middy via shared `createHandler()` in `packages/lambda-utils`
- Secrets come from `context` (injected by @middy/ssm) — never call SSM directly in handlers
- DB driver: `postgres` (pure JS, by porsager) + Drizzle ORM — never use `pg` (native bindings)
- Bun layer ARN (ap-southeast-1): arn:aws:lambda:ap-southeast-1:117169996103:layer:bun-arm64:8
- Pin the layer to a specific version number — never use $LATEST

## Secrets flow

HCP Vault Secrets → GitHub Actions → `TF_VAR_*` environment variables → `sensitive = true` Terraform variables → SSM SecureString parameters → Lambda reads at runtime via `ssm:GetParameter`

## Modules still to build

- `infrastructure/api_gateway` — HTTP API v2 + WebSocket API for chat
- `infrastructure/dynamodb_chat` — chat connections table + daily recommendations cache
