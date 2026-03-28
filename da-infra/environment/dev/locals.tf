locals {
  env_name     = "dev"
  aws_region   = "ap-south-1"
  account_name = "da-dev"

  # ── RDS config per environment ────────────────────────────────────────────
  rds_config = {
    instance_class       = "db.t4g.micro"
    allocated_storage_gb = 20
    multi_az             = false # no HA in dev — saves $15/mo
  }

  # ── Lambda config per environment ────────────────────────────────────────
  lambda_config = {
    zip_version = var.lambda_zip_version
  }
}
