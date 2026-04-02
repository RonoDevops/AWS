################################################################################
# Outputs - EventBridge Module
################################################################################

output "rule_arn" {
  description = "ARN of the daily ingestion EventBridge rule"
  value       = aws_cloudwatch_event_rule.daily_ingestion.arn
}

output "rule_name" {
  description = "Name of the daily ingestion EventBridge rule"
  value       = aws_cloudwatch_event_rule.daily_ingestion.name
}
