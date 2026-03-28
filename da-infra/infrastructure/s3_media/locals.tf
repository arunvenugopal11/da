locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  bucket_name = "da-${var.env_name}-media-${data.aws_caller_identity.current.account_id}"
}
