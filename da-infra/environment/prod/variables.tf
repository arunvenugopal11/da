# All variables here are sensitive — sourced from HCP Vault via GitLab CI/CD.
# Never set default values for sensitive variables.
# In CI: export TF_VAR_db_password=$(hcp vault-secrets secrets open db_password --app da-dev --format=json | jq -r .static_version.value)

variable "db_password" {
  description = "RDS master password — from HCP Vault secret: da-dev/db_password"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT signing key — from HCP Vault secret: da-dev/jwt_secret_key"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook secret — from HCP Vault secret: da-dev/stripe_webhook_secret"
  type        = string
  sensitive   = true
}

variable "expo_push_token" {
  description = "Expo push access token — from HCP Vault secret: da-dev/expo_push_token"
  type        = string
  sensitive   = true
}

variable "cognito_sms_external_id" {
  description = "External ID for Cognito SMS IAM role trust — from HCP Vault secret: da-prod/cognito_sms_external_id"
  type        = string
  sensitive   = true
}

variable "lambda_zip_version" {
  description = "Lambda deployment version — set by CI/CD pipeline (git SHA)"
  type        = string
  default     = "latest"
}
