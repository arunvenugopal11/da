output "queue_url" {
  description = "Primary queue URL"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "Primary queue ARN — used in Lambda event source mapping"
  value       = aws_sqs_queue.main.arn
}

output "dlq_url" {
  description = "Dead letter queue URL"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "Dead letter queue ARN"
  value       = aws_sqs_queue.dlq.arn
}
