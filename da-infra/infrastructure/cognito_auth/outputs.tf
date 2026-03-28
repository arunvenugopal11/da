output "user_pool_id" {
  description = "Cognito User Pool ID — used by Lambda auth handler and Amplify config"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN — used in IAM policies for Lambda auth handler"
  value       = aws_cognito_user_pool.main.arn
}

output "mobile_client_id" {
  description = "App client ID for the React Native mobile app — no secret, safe to embed"
  value       = aws_cognito_user_pool_client.mobile.id
}
