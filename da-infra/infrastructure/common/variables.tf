variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "boundary_policy_arn" {
  description = "ARN of the IAM permission boundary — from resources/iam_boundary output"
  type        = string
}
