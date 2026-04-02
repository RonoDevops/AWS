output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "client_id" {
  description = "ID of the User Pool web client"
  value       = aws_cognito_user_pool_client.web.id
}

output "domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "endpoint" {
  description = "Cognito User Pool endpoint for token operations"
  value       = aws_cognito_user_pool.main.endpoint
}
