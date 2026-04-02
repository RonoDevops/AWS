# =============================================================================
# DermaIntel - Dev Environment Outputs
# =============================================================================

# Frontend
output "cloudfront_domain" {
  description = "CloudFront distribution domain name (frontend URL)"
  value       = module.cloudfront.distribution_domain_name
}

output "frontend_bucket" {
  description = "S3 bucket for frontend assets"
  value       = module.s3.frontend_bucket_name
}

# API
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

# Auth
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.cognito.user_pool_client_id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = module.cognito.user_pool_domain
}

# Storage
output "papers_bucket" {
  description = "S3 bucket for paper storage"
  value       = module.s3.papers_bucket_name
}

output "papers_table" {
  description = "DynamoDB papers table name"
  value       = module.dynamodb.papers_table_name
}

# Ingestion
output "ingestion_state_machine" {
  description = "Step Functions state machine ARN for ingestion pipeline"
  value       = module.step_functions.state_machine_arn
}

# Monitoring
output "alerts_topic" {
  description = "SNS topic ARN for alarm notifications"
  value       = module.monitoring.sns_topic_arn
}
