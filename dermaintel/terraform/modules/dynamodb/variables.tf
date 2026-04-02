################################################################################
# Variables - DynamoDB Module
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
  description = "Name of the project, used for tagging"
  type        = string
  default     = "dermaintel"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
