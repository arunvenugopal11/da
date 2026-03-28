variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "boundary_policy_arn" {
  description = "IAM permission boundary — applied to all Lambda execution roles"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — from common module output"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC placement — from common module"
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Lambda security group ID — from common module"
  type        = string
}

variable "lambda_code_bucket" {
  description = "S3 bucket containing Lambda deployment packages — from common module"
  type        = string
}

variable "notification_queue_arn" {
  description = "Notification SQS queue ARN — triggers notifications Lambda"
  type        = string
}

variable "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint — passed to Lambda as env var"
  type        = string
  default     = ""
}

# Secrets — all sensitive = true, sourced from HCP Vault via CI/CD
variable "jwt_secret_key" {
  description = "JWT signing key from HCP Vault"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret from HCP Vault"
  type        = string
  sensitive   = true
}

variable "expo_push_token" {
  description = "Expo Push access token from HCP Vault"
  type        = string
  sensitive   = true
}

variable "lambda_zip_version" {
  description = "Version tag of Lambda zip to deploy — set by CI/CD pipeline"
  type        = string
  default     = "latest"
}
