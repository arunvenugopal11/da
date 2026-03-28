locals {
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.name
  pool_name     = "da-${var.env_name}-users"
  sms_role_name = "Da-${var.env_name}-cognito-sms-role"
}
