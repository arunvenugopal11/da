output "function_arns" {
  description = "Map of function name → ARN for all Lambda functions"
  value       = { for k, v in aws_lambda_function.functions : k => v.arn }
}

output "function_names" {
  description = "Map of function name → function name"
  value       = { for k, v in aws_lambda_function.functions : k => v.function_name }
}

output "execution_role_arns" {
  description = "Map of function name → execution role ARN"
  value       = { for k, v in aws_iam_role.lambda : k => v.arn }
}

output "chat_function_arn" {
  description = "Chat Lambda ARN — wired to API Gateway WebSocket"
  value       = aws_lambda_function.functions["chat"].arn
}
