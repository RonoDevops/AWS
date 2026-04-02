################################################################################
# Variables - Step Functions Module
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

variable "pubmed_fetcher_arn" {
  description = "ARN of the PubMed fetcher Lambda function"
  type        = string
}

variable "tree_builder_arn" {
  description = "ARN of the tree builder Lambda function"
  type        = string
}

variable "metadata_extractor_arn" {
  description = "ARN of the metadata extractor Lambda function"
  type        = string
}
