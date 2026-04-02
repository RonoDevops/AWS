################################################################################
# Outputs - API Gateway Module
################################################################################

output "api_endpoint" {
  description = "API Gateway invocation URL"
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.this.id
}

output "api_name" {
  description = "API Gateway name"
  value       = aws_apigatewayv2_api.this.name
}

output "execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_name" {
  description = "Deployed stage name"
  value       = aws_apigatewayv2_stage.this.name
}

output "stage_arn" {
  description = "Stage ARN (for WAF association)"
  value       = aws_apigatewayv2_stage.this.arn
}
