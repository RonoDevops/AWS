################################################################################
# Outputs - Lambda Module
################################################################################

# ---------------------------------------------------------------------------
# Ingestion Functions
# ---------------------------------------------------------------------------

output "ingestion_function_names" {
  description = "Map of ingestion Lambda function names"
  value       = { for k, v in aws_lambda_function.ingestion : k => v.function_name }
}

output "ingestion_function_arns" {
  description = "Map of ingestion Lambda function ARNs"
  value       = { for k, v in aws_lambda_function.ingestion : k => v.arn }
}

output "ingestion_invoke_arns" {
  description = "Map of ingestion Lambda invoke ARNs"
  value       = { for k, v in aws_lambda_function.ingestion : k => v.invoke_arn }
}

# ---------------------------------------------------------------------------
# Query Functions
# ---------------------------------------------------------------------------

output "query_function_names" {
  description = "Map of query Lambda function names"
  value       = { for k, v in aws_lambda_function.query : k => v.function_name }
}

output "query_function_arns" {
  description = "Map of query Lambda function ARNs"
  value       = { for k, v in aws_lambda_function.query : k => v.arn }
}

output "query_invoke_arns" {
  description = "Map of query Lambda invoke ARNs"
  value       = { for k, v in aws_lambda_function.query : k => v.invoke_arn }
}

# ---------------------------------------------------------------------------
# API Functions
# ---------------------------------------------------------------------------

output "api_function_names" {
  description = "Map of API Lambda function names"
  value       = { for k, v in aws_lambda_function.api : k => v.function_name }
}

output "api_function_arns" {
  description = "Map of API Lambda function ARNs"
  value       = { for k, v in aws_lambda_function.api : k => v.arn }
}

output "api_invoke_arns" {
  description = "Map of API Lambda invoke ARNs"
  value       = { for k, v in aws_lambda_function.api : k => v.invoke_arn }
}

# ---------------------------------------------------------------------------
# All Functions (merged)
# ---------------------------------------------------------------------------

output "all_function_names" {
  description = "Map of all Lambda function names"
  value = merge(
    { for k, v in aws_lambda_function.ingestion : k => v.function_name },
    { for k, v in aws_lambda_function.query : k => v.function_name },
    { for k, v in aws_lambda_function.api : k => v.function_name },
  )
}

output "all_function_arns" {
  description = "Map of all Lambda function ARNs"
  value = merge(
    { for k, v in aws_lambda_function.ingestion : k => v.arn },
    { for k, v in aws_lambda_function.query : k => v.arn },
    { for k, v in aws_lambda_function.api : k => v.arn },
  )
}

output "all_invoke_arns" {
  description = "Map of all Lambda invoke ARNs"
  value = merge(
    { for k, v in aws_lambda_function.ingestion : k => v.invoke_arn },
    { for k, v in aws_lambda_function.query : k => v.invoke_arn },
    { for k, v in aws_lambda_function.api : k => v.invoke_arn },
  )
}

# ---------------------------------------------------------------------------
# IAM Role ARNs
# ---------------------------------------------------------------------------

output "ingestion_role_arn" {
  description = "ARN of the ingestion Lambda IAM role"
  value       = aws_iam_role.ingestion.arn
}

output "query_role_arn" {
  description = "ARN of the query Lambda IAM role"
  value       = aws_iam_role.query.arn
}

output "api_role_arn" {
  description = "ARN of the API Lambda IAM role"
  value       = aws_iam_role.api.arn
}
