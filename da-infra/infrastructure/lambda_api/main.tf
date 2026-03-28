# Lambda API module — creates all application Lambda functions with:
# - Shared execution role per function with permission boundary enforced
# - VPC placement in private subnets
# - Secrets from SSM Parameter Store (not env vars directly)
# - SQS event source mapping for async functions
# - Provisioned concurrency on auth + profile (eliminates cold starts)

# ── Shared Lambda Layer for common dependencies ────────────────────────────
resource "aws_lambda_layer_version" "common_deps" {
  layer_name          = "${local.prefix}-common-deps"
  description         = "Shared dependencies: postgres, drizzle-orm, middy, jose"
  s3_bucket           = var.lambda_code_bucket
  s3_key              = "layers/common-deps-${var.lambda_zip_version}.zip"
  compatible_runtimes = ["provided.al2023"]
}

# ── IAM: One execution role per Lambda function ───────────────────────────────
resource "aws_iam_role" "lambda" {
  for_each = local.functions

  name                 = "Da-${var.env_name}-${each.key}-lambda-role"
  description          = "Execution role for ${local.prefix}-${each.key} Lambda"
  permissions_boundary = var.boundary_policy_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  for_each   = local.functions
  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# SSM read access — all Lambdas read their own env config from Parameter Store
resource "aws_iam_role_policy" "lambda_ssm" {
  for_each = local.functions
  name     = "ssm-read-${var.env_name}"
  role     = aws_iam_role.lambda[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${var.env_name}/*"
    }]
  })
}

# Notifications Lambda needs SQS permissions
resource "aws_iam_role_policy" "notifications_sqs" {
  name = "sqs-consume"
  role = aws_iam_role.lambda["notifications"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = var.notification_queue_arn
    }]
  })
}

# ── Lambda Functions ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "functions" {
  for_each = local.functions

  function_name = "${local.prefix}-${each.key}"
  description   = each.value.description
  role          = aws_iam_role.lambda[each.key].arn
  handler       = each.value.handler
  runtime       = "provided.al2023"
  architectures = ["arm64"] # Graviton2: 20% faster init, 20% cheaper

  # Code pulled from S3 — CI/CD pipeline uploads zip before terraform apply
  s3_bucket = var.lambda_code_bucket
  s3_key    = "functions/${each.key}-${var.lambda_zip_version}.zip"

  timeout     = each.value.timeout
  memory_size = each.value.memory_mb

  layers = [
    "arn:aws:lambda:${local.region}:117169996103:layer:bun-arm64:8",
    aws_lambda_layer_version.common_deps.arn,
  ]

  # All in private VPC subnet — reaches RDS directly, no NAT Gateway needed
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      ENV_NAME       = var.env_name
      AWS_ACCOUNT_ID = local.account_id
      # Secrets passed via SSM path — Lambda reads at cold start, not hardcoded
      SSM_PREFIX     = "/${var.env_name}/app"
      RDS_PROXY_HOST = var.rds_proxy_endpoint
      LOG_LEVEL      = var.env_name == "prod" ? "warn" : "debug"
    }
  }

  tracing_config {
    mode = "Active" # X-Ray distributed tracing
  }

  lifecycle {
    # Prevent Terraform from reverting manual hotfix deployments mid-incident
    ignore_changes = [s3_key]
  }
}

# ── Provisioned Concurrency: auth + profile — eliminates cold starts ──────────
resource "aws_lambda_provisioned_concurrency_config" "warm" {
  for_each = var.env_name == "prod" ? toset(["auth", "profile"]) : toset([])

  function_name                     = aws_lambda_function.functions[each.key].function_name
  qualifier                         = aws_lambda_alias.live[each.key].name
  provisioned_concurrent_executions = 2
}

resource "aws_lambda_alias" "live" {
  for_each         = local.functions
  name             = "live"
  function_name    = aws_lambda_function.functions[each.key].function_name
  function_version = "$LATEST"
}

# ── SQS Event Source: Notifications Lambda ────────────────────────────────────
resource "aws_lambda_event_source_mapping" "notifications_sqs" {
  event_source_arn = var.notification_queue_arn
  function_name    = aws_lambda_function.functions["notifications"].arn
  batch_size       = 10
  enabled          = true
}

# ── SSM: Publish Lambda ARNs for cross-module discovery ──────────────────────
resource "aws_ssm_parameter" "lambda_arns" {
  for_each = local.functions
  name     = "/${var.env_name}/infrastructure/lambda/${each.key}-arn"
  type     = "String"
  value    = aws_lambda_function.functions[each.key].arn
}

# ── Secrets in SSM (written by CI/CD, read by Lambda at runtime) ─────────────
resource "aws_ssm_parameter" "jwt_secret" {
  name      = "/${var.env_name}/app/jwt-secret-key"
  type      = "SecureString"
  value     = var.jwt_secret_key
  overwrite = true
}

resource "aws_ssm_parameter" "stripe_webhook_secret" {
  name      = "/${var.env_name}/app/stripe-webhook-secret"
  type      = "SecureString"
  value     = var.stripe_webhook_secret
  overwrite = true
}

resource "aws_ssm_parameter" "expo_push_token" {
  name      = "/${var.env_name}/app/expo-push-token"
  type      = "SecureString"
  value     = var.expo_push_token
  overwrite = true
}
