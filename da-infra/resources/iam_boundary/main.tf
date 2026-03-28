# IAM Permission Boundary — applied to every IAM role in the project.
# Even if a role's own policy grants Action:"*", the boundary silently caps
# what it can actually do. Prevents privilege escalation from misconfigured roles.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

data "aws_iam_policy_document" "boundary" {
  # Allow Lambda & ECS execution essentials
  statement {
    sid    = "AllowLambdaCore"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }

  # Allow VPC networking (required for Lambda in VPC)
  statement {
    sid    = "AllowVPCNetworking"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }

  # Allow access to own SSM parameters only
  statement {
    sid    = "AllowSSMRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${var.env_name}/*"
    ]
  }

  # Allow SQS operations on project queues only
  statement {
    sid    = "AllowSQS"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [
      "arn:aws:sqs:${local.region}:${local.account_id}:da-${var.env_name}-*"
    ]
  }

  # Allow S3 operations on project buckets only
  statement {
    sid    = "AllowS3ProjectBuckets"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::da-${var.env_name}-*",
      "arn:aws:s3:::da-${var.env_name}-*/*",
    ]
  }

  # Allow DynamoDB on project tables only
  statement {
    sid    = "AllowDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/da-${var.env_name}-*"
    ]
  }

  # Allow RDS Proxy connection
  statement {
    sid     = "AllowRDSProxy"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:*/da_*"
    ]
  }

  # Allow Cognito user pool operations
  statement {
    sid    = "AllowCognito"
    effect = "Allow"
    actions = [
      "cognito-idp:AdminGetUser",
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminUpdateUserAttributes",
      "cognito-idp:AdminDisableUser",
    ]
    resources = [
      "arn:aws:cognito-idp:${local.region}:${local.account_id}:userpool/*"
    ]
  }

  # Explicitly deny dangerous actions — even if a role policy tries to grant them
  statement {
    sid    = "DenyDangerousActions"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:CreateRole",
      "organizations:*",
      "account:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name        = "Da-${var.env_name}-PermissionBoundary"
  description = "Permission boundary applied to all IAM roles in da-${var.env_name}. Caps maximum permissions regardless of role policy."
  policy      = data.aws_iam_policy_document.boundary.json
}
