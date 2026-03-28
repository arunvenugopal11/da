output "state_bucket_name" {
  description = "S3 bucket name — paste into environment provider.tf backend blocks"
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "DynamoDB lock table name — paste into environment provider.tf backend blocks"
  value       = aws_dynamodb_table.tflock.name
}
