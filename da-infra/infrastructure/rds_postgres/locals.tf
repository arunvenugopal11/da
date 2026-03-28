locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  prefix      = "da-${var.env_name}"
  db_name     = "da"
  db_username = "da_admin"
}
