locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  queue_name = "da-${var.env_name}-matching"
  dlq_name   = "da-${var.env_name}-matching-dlq"
}
