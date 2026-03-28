# Common module — creates shared infrastructure consumed by all other modules.
# Every module reads outputs from this one via the environment main.tf.

# ── Security Groups ──────────────────────────────────────────────────────────

# Lambda functions security group
resource "aws_security_group" "lambda" {
  name        = "${local.prefix}-lambda-sg"
  description = "Outbound-only SG for Lambda functions inside VPC"
  vpc_id      = data.aws_vpc.main.id

  egress {
    description = "HTTPS to VPC (SSM, S3 endpoint, DynamoDB endpoint)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  tags = { Name = "${local.prefix}-lambda-sg" }
}

# RDS security group — only accepts connections from Lambda SG
resource "aws_security_group" "rds" {
  name        = "${local.prefix}-rds-sg"
  description = "RDS PostgreSQL — allows inbound from Lambda SG only"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = { Name = "${local.prefix}-rds-sg" }
}

# ── VPC Endpoints ─────────────────────────────────────────────────────────────
# Gateway endpoints are FREE — Lambdas in private subnets reach S3 and DynamoDB
# without needing a NAT Gateway (eliminates $33/mo cost)

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.main.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_subnets.private.ids

  tags = { Name = "${local.prefix}-s3-endpoint" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = data.aws_vpc.main.id
  service_name      = "com.amazonaws.${local.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_subnets.private.ids

  tags = { Name = "${local.prefix}-dynamodb-endpoint" }
}

# Interface endpoint for SSM — Lambdas in VPC read Parameter Store without NAT
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true

  tags = { Name = "${local.prefix}-ssm-endpoint" }
}

# ── Lambda Code S3 Bucket ─────────────────────────────────────────────────────
resource "aws_s3_bucket" "lambda_code" {
  bucket = "${local.prefix}-lambda-code-${local.account_id}"
  tags   = { Name = "${local.prefix}-lambda-code" }
}

resource "aws_s3_bucket_versioning" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_code" {
  bucket                  = aws_s3_bucket.lambda_code.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api_lambdas" {
  for_each          = toset(["auth", "profile", "matching", "premium", "chat", "notifications"])
  name              = "/aws/lambda/${local.prefix}-${each.key}"
  retention_in_days = var.env_name == "prod" ? 90 : 14
}

# ── SSM: Publish shared resource identifiers ─────────────────────────────────
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.env_name}/infrastructure/common/vpc-id"
  type  = "String"
  value = data.aws_vpc.main.id
}

resource "aws_ssm_parameter" "lambda_sg_id" {
  name  = "/${var.env_name}/infrastructure/common/lambda-sg-id"
  type  = "String"
  value = aws_security_group.lambda.id
}

resource "aws_ssm_parameter" "rds_sg_id" {
  name  = "/${var.env_name}/infrastructure/common/rds-sg-id"
  type  = "String"
  value = aws_security_group.rds.id
}

resource "aws_ssm_parameter" "lambda_code_bucket" {
  name  = "/${var.env_name}/infrastructure/common/lambda-code-bucket"
  type  = "String"
  value = aws_s3_bucket.lambda_code.id
}
