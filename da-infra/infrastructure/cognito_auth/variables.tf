variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "boundary_policy_arn" {
  description = "IAM permission boundary ARN — applied to the Cognito SMS IAM role"
  type        = string
}

variable "sms_external_id" {
  description = "External ID used in the Cognito SMS IAM role trust policy — prevents confused deputy attacks"
  type        = string
  sensitive   = true
}
