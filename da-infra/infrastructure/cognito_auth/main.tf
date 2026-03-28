# Cognito User Pool — phone number OTP authentication for Da mobile app
# Auth flow: mobile sends phone → Cognito dispatches SMS OTP → mobile confirms OTP → JWT issued
#
# Flow used by Amplify: CUSTOM_AUTH (signIn → confirmSignIn with OTP challenge)

# ── IAM Role: allow Cognito to publish SMS via SNS ────────────────────────────
resource "aws_iam_role" "cognito_sms" {
  name                = local.sms_role_name
  permissions_boundary = var.boundary_policy_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cognito-idp.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "sts:ExternalId" = var.sms_external_id }
      }
    }]
  })

  tags = { Name = local.sms_role_name }
}

resource "aws_iam_role_policy" "cognito_sms_publish" {
  name = "allow-sns-publish"
  role = aws_iam_role.cognito_sms.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = "*" # Cognito requires * — SMS publishing has no specific ARN
    }]
  })
}

# ── Cognito User Pool ─────────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = local.pool_name

  # Phone number is the only sign-in identifier
  username_attributes      = ["phone_number"]
  auto_verified_attributes = ["phone_number"]

  username_configuration {
    case_sensitive = false
  }

  # OTP delivered via SMS
  sms_configuration {
    external_id    = var.sms_external_id
    sns_caller_arn = aws_iam_role.cognito_sms.arn
    sns_region     = local.region
  }

  # MFA optional — Amplify custom auth flow handles OTP as a challenge
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = false # TOTP disabled — SMS OTP only
  }

  # Password policy — relaxed since auth is OTP-based (password is never used by users)
  password_policy {
    minimum_length                   = 8
    require_lowercase                = false
    require_uppercase                = false
    require_numbers                  = false
    require_symbols                  = false
    temporary_password_validity_days = 1
  }

  # Account recovery via phone (not email — we don't collect email at sign-up)
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 1
    }
  }

  # Delete protection in prod — must be overridden manually if tearing down
  deletion_protection = var.env_name == "prod" ? "ACTIVE" : "INACTIVE"

  tags = { Name = local.pool_name }
}

# ── App Client: mobile (no client secret — React Native can't keep secrets) ──
resource "aws_cognito_user_pool_client" "mobile" {
  name         = "da-${var.env_name}-mobile"
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret — mobile apps are public clients
  generate_secret = false

  # Auth flows required by Amplify CUSTOM_WITHOUT_SRP
  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Token validity
  access_token_validity  = 60  # minutes
  id_token_validity      = 60  # minutes
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED" # Don't leak whether a phone is registered
}

# ── SSM: Publish identifiers for runtime use by Lambda auth handler ───────────
resource "aws_ssm_parameter" "user_pool_id" {
  name  = "/${var.env_name}/infrastructure/cognito/user-pool-id"
  type  = "String"
  value = aws_cognito_user_pool.main.id
}

resource "aws_ssm_parameter" "user_pool_arn" {
  name  = "/${var.env_name}/infrastructure/cognito/user-pool-arn"
  type  = "String"
  value = aws_cognito_user_pool.main.arn
}

resource "aws_ssm_parameter" "mobile_client_id" {
  name  = "/${var.env_name}/infrastructure/cognito/mobile-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.mobile.id
}
