################################################################################
# Outputs - DynamoDB Module
################################################################################

# Papers Index Table
output "papers_table_name" {
  description = "Name of the papers index DynamoDB table"
  value       = aws_dynamodb_table.papers_index.name
}

output "papers_table_arn" {
  description = "ARN of the papers index DynamoDB table"
  value       = aws_dynamodb_table.papers_index.arn
}

output "papers_table_stream_arn" {
  description = "Stream ARN of the papers index DynamoDB table"
  value       = try(aws_dynamodb_table.papers_index.stream_arn, "")
}

# Feedback Table
output "feedback_table_name" {
  description = "Name of the feedback DynamoDB table"
  value       = aws_dynamodb_table.feedback.name
}

output "feedback_table_arn" {
  description = "ARN of the feedback DynamoDB table"
  value       = aws_dynamodb_table.feedback.arn
}

# Chat History Table
output "chat_history_table_name" {
  description = "Name of the chat history DynamoDB table"
  value       = aws_dynamodb_table.chat_history.name
}

output "chat_history_table_arn" {
  description = "ARN of the chat history DynamoDB table"
  value       = aws_dynamodb_table.chat_history.arn
}
