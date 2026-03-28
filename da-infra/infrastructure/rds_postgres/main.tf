# RDS PostgreSQL + RDS Proxy
# RDS Proxy is non-negotiable with Lambda — prevents connection exhaustion.
# A t4g.micro has 87 max connections. At 100 concurrent Lambdas without proxy,
# every new query fails. Proxy multiplexes connections — costs $18/mo, saves your prod.

resource "aws_db_subnet_group" "main" {
  name       = "${local.prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.prefix}-db-subnet-group" }
}

# Random suffix prevents name conflicts on replacement
resource "random_id" "db_suffix" {
  byte_length = 4
}

resource "aws_db_instance" "main" {
  identifier        = "${local.prefix}-postgres-${random_id.db_suffix.hex}"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = local.db_name
  username = local.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.env_name == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection       = var.env_name == "prod" ? true : false
  skip_final_snapshot       = var.env_name == "prod" ? false : true
  final_snapshot_identifier = var.env_name == "prod" ? "${local.prefix}-final-snapshot" : null

  performance_insights_enabled = var.env_name == "prod" ? true : false

  tags = { Name = "${local.prefix}-postgres" }
}

# ── RDS Proxy — connection pooler for Lambda ─────────────────────────────────
# IAM role for Proxy to access Secrets Manager (stores DB credentials)
resource "aws_iam_role" "rds_proxy" {
  name                 = "Da-${var.env_name}-rds-proxy-role"
  permissions_boundary = var.boundary_policy_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Store DB password in Secrets Manager — required by RDS Proxy
resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.prefix}-rds-password"
  tags = { Name = "${local.prefix}-rds-password" }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = local.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = local.db_name
  })
}

resource "aws_iam_role_policy" "rds_proxy_secrets" {
  name = "secrets-manager-read"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.db_password.arn
    }]
  })
}

resource "aws_db_proxy" "main" {
  name                   = "${local.prefix}-rds-proxy"
  debug_logging          = var.env_name != "prod"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [var.rds_sg_id]
  vpc_subnet_ids         = var.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED" # Lambda connects via IAM, no password in code
    secret_arn  = aws_secretsmanager_secret.db_password.arn
  }

  tags = { Name = "${local.prefix}-rds-proxy" }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "main" {
  db_instance_identifier = aws_db_instance.main.id
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
}

# ── SSM: Publish connection details ──────────────────────────────────────────
resource "aws_ssm_parameter" "rds_proxy_endpoint" {
  name  = "/${var.env_name}/infrastructure/rds/proxy-endpoint"
  type  = "String"
  value = aws_db_proxy.main.endpoint
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.env_name}/infrastructure/rds/db-name"
  type  = "String"
  value = local.db_name
}
