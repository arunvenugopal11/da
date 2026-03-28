output "rds_endpoint" {
  description = "Direct RDS endpoint (do not use in application code — use proxy)"
  value       = aws_db_instance.main.address
}

output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint — use this in all Lambda environment variables"
  value       = aws_db_proxy.main.endpoint
}

output "db_name" {
  value = local.db_name
}

output "db_instance_id" {
  value = aws_db_instance.main.id
}
