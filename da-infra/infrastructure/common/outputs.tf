output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — used by Lambda, RDS"
  value       = data.aws_subnets.private.ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs — used by ALB if added"
  value       = data.aws_subnets.public.ids
}

output "lambda_sg_id" {
  description = "Lambda security group ID"
  value       = aws_security_group.lambda.id
}

output "rds_sg_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "lambda_code_bucket" {
  description = "S3 bucket name for Lambda deployment packages"
  value       = aws_s3_bucket.lambda_code.id
}
