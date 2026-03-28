variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "boundary_policy_arn" {
  description = "IAM permission boundary ARN"
  type        = string
}

variable "producer_role_arns" {
  description = "IAM role ARNs permitted to send messages to this queue"
  type        = list(string)
  default     = []
}

variable "consumer_role_arns" {
  description = "IAM role ARNs permitted to receive/delete messages from this queue"
  type        = list(string)
  default     = []
}

variable "visibility_timeout_seconds" {
  description = "How long a received message is hidden from other consumers"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "How long messages stay in the queue if not consumed"
  type        = number
  default     = 86400 # 24 hours
}
