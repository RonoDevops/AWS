################################################################################
# Variables - Monitoring Module
################################################################################

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dermaintel"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "lambda_function_names" {
  description = "Map of logical names to Lambda function names (e.g. { query_orchestrator = \"dermaintel-query-orchestrator-dev\" })"
  type        = map(string)
}

variable "api_gateway_name" {
  description = "Name of the API Gateway REST API for CloudWatch metrics"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to monitor for throttled requests"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive alarm notifications"
  type        = string
}
