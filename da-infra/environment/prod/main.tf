# Prod environment — all module instantiations live here.
# Each module is a separate folder in infrastructure/ with its own state.
# Outputs flow: iam_boundary → common → [lambda_api, rds_postgres, s3_media, sqs_*]
#
# NOTE: Only cognito_auth is active. All other modules are commented out until
# the login feature is live and ready to expand.

# ── 1. IAM Permission Boundary (must be first — all other modules depend on it) ──
module "iam_boundary" {
  source   = "../../resources/iam_boundary"
  env_name = local.env_name
}

# ── 2. Cognito User Pool — phone OTP authentication ──────────────────────────
module "cognito_auth" {
  source              = "../../infrastructure/cognito_auth"
  env_name            = local.env_name
  boundary_policy_arn = module.iam_boundary.boundary_policy_arn
  sms_external_id     = var.cognito_sms_external_id
}

# ── Pending: enable when backend Lambda services are ready ────────────────────

# module "common" {
#   source              = "../../infrastructure/common"
#   env_name            = local.env_name
#   boundary_policy_arn = module.iam_boundary.boundary_policy_arn
# }

# module "sqs_notification" {
#   source              = "../../infrastructure/sqs_notification"
#   env_name            = local.env_name
#   boundary_policy_arn = module.iam_boundary.boundary_policy_arn
#   producer_role_arns = [
#     module.lambda_api.execution_role_arns["matching"],
#     module.lambda_api.execution_role_arns["premium"],
#     module.lambda_api.execution_role_arns["chat"],
#   ]
#   consumer_role_arns = [
#     module.lambda_api.execution_role_arns["notifications"],
#   ]
# }

# module "sqs_matching" {
#   source              = "../../infrastructure/sqs_matching"
#   env_name            = local.env_name
#   boundary_policy_arn = module.iam_boundary.boundary_policy_arn
#   producer_role_arns = [module.lambda_api.execution_role_arns["profile"]]
#   consumer_role_arns = [module.lambda_api.execution_role_arns["matching"]]
# }

# module "rds_postgres" {
#   source               = "../../infrastructure/rds_postgres"
#   env_name             = local.env_name
#   boundary_policy_arn  = module.iam_boundary.boundary_policy_arn
#   vpc_id               = module.common.vpc_id
#   private_subnet_ids   = module.common.private_subnet_ids
#   rds_sg_id            = module.common.rds_sg_id
#   db_password          = var.db_password
#   instance_class       = local.rds_config.instance_class
#   allocated_storage_gb = local.rds_config.allocated_storage_gb
#   multi_az             = local.rds_config.multi_az
#   lambda_execution_role_arns = values(module.lambda_api.execution_role_arns)
# }

# module "lambda_api" {
#   source              = "../../infrastructure/lambda_api"
#   env_name            = local.env_name
#   boundary_policy_arn = module.iam_boundary.boundary_policy_arn
#   vpc_id              = module.common.vpc_id
#   private_subnet_ids  = module.common.private_subnet_ids
#   lambda_sg_id        = module.common.lambda_sg_id
#   lambda_code_bucket  = module.common.lambda_code_bucket
#   notification_queue_arn = module.sqs_notification.queue_arn
#   rds_proxy_endpoint     = module.rds_postgres.rds_proxy_endpoint
#   jwt_secret_key        = var.jwt_secret_key
#   stripe_webhook_secret = var.stripe_webhook_secret
#   expo_push_token       = var.expo_push_token
#   lambda_zip_version    = var.lambda_zip_version
# }

# module "s3_media" {
#   source   = "../../infrastructure/s3_media"
#   env_name = local.env_name
#   upload_role_arns = [module.lambda_api.execution_role_arns["profile"]]
# }
