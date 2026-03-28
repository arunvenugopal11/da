locals {
  env_name     = "prod"
  aws_region   = "ap-southeast-1"
  account_name = "da-prod"

  rds_config = {
    instance_class       = "db.t4g.small" # Upgrade when load justifies it
    allocated_storage_gb = 50
    multi_az             = true # HA for prod — failover in ~60s
  }

  lambda_config = {
    zip_version = var.lambda_zip_version
  }
}
