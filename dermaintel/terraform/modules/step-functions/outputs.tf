################################################################################
# Outputs - Step Functions Module
################################################################################

output "state_machine_arn" {
  description = "ARN of the ingestion pipeline state machine"
  value       = aws_sfn_state_machine.ingestion_pipeline.arn
}

output "state_machine_name" {
  description = "Name of the ingestion pipeline state machine"
  value       = aws_sfn_state_machine.ingestion_pipeline.name
}

output "role_arn" {
  description = "ARN of the IAM role used by the state machine"
  value       = aws_iam_role.step_functions.arn
}
