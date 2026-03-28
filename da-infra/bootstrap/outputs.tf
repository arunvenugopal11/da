output "state_bucket_name" {
  description = "S3 bucket name — paste into environment provider.tf backend blocks"
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "DynamoDB lock table name — paste into environment provider.tf backend blocks"
  value       = aws_dynamodb_table.tflock.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN — paste as AWS_ROLE_ARN in GitHub Actions secrets"
  value       = aws_iam_role.github_terraform.arn
}
