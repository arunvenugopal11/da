# User notification events (new match, message, visitor)
# Creates: DLQ + Primary Queue + Queue Policy + SSM parameters
# Every queue in this project follows this exact pattern.

# ── Dead Letter Queue ─────────────────────────────────────────────────────────
resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  message_retention_seconds = 604800 # 7 days — enough time to investigate failures

  tags = { Name = local.dlq_name, Purpose = "DLQ for ${local.queue_name}" }
}

# ── Primary Queue ─────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "main" {
  name                       = local.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3 # After 3 failed processing attempts, move to DLQ
  })

  tags = { Name = local.queue_name }
}

# ── Queue Policy ──────────────────────────────────────────────────────────────
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowProducers"
        Effect    = "Allow"
        Principal = { AWS = length(var.producer_role_arns) > 0 ? var.producer_role_arns : ["arn:aws:iam::${local.account_id}:root"] }
        Action    = ["sqs:SendMessage"]
        Resource  = aws_sqs_queue.main.arn
      },
      {
        Sid       = "AllowConsumers"
        Effect    = "Allow"
        Principal = { AWS = length(var.consumer_role_arns) > 0 ? var.consumer_role_arns : ["arn:aws:iam::${local.account_id}:root"] }
        Action    = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource  = aws_sqs_queue.main.arn
      },
      {
        Sid       = "DenyNonSSL"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.main.arn
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# ── DLQ Policy ────────────────────────────────────────────────────────────────
resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRedriveFromMain"
        Effect    = "Allow"
        Principal = { Service = "sqs.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.dlq.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_sqs_queue.main.arn }
        }
      },
      {
        Sid       = "DenyNonSSL"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "sqs:*"
        Resource  = aws_sqs_queue.dlq.arn
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# ── CloudWatch Alarm: DLQ not empty ──────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${local.dlq_name}-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Messages in ${local.dlq_name} — investigate failed processing"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}

# ── SSM: Publish queue URLs for runtime service discovery ────────────────────
resource "aws_ssm_parameter" "queue_url" {
  name  = "/${var.env_name}/infrastructure/sqs/notification-queue-url"
  type  = "String"
  value = aws_sqs_queue.main.url
}

resource "aws_ssm_parameter" "queue_arn" {
  name  = "/${var.env_name}/infrastructure/sqs/notification-queue-arn"
  type  = "String"
  value = aws_sqs_queue.main.arn
}

resource "aws_ssm_parameter" "dlq_url" {
  name  = "/${var.env_name}/infrastructure/sqs/notification-dlq-url"
  type  = "String"
  value = aws_sqs_queue.dlq.url
}
