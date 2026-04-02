################################################################################
# Outputs - Monitoring Module
################################################################################

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "log_group_arns" {
  description = "Map of Lambda function logical names to their CloudWatch Log Group ARNs"
  value       = { for k, v in aws_cloudwatch_log_group.lambda : k => v.arn }
}
