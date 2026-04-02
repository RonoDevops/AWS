################################################################################
# Variables - WAF Module
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

variable "api_gateway_stage_arn" {
  description = "ARN of the API Gateway stage to associate with the WAF Web ACL"
  type        = string
}
