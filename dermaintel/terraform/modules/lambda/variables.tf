################################################################################
# Variables - Lambda Module
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

variable "source_path" {
  description = "Path to the Lambda source code directory, relative to project root"
  type        = string
}

variable "papers_bucket_arn" {
  description = "ARN of the papers S3 bucket"
  type        = string
}

variable "papers_bucket_name" {
  description = "Name of the papers S3 bucket"
  type        = string
}

variable "papers_table_arn" {
  description = "ARN of the papers DynamoDB table"
  type        = string
}

variable "papers_table_name" {
  description = "Name of the papers DynamoDB table"
  type        = string
}

variable "feedback_table_arn" {
  description = "ARN of the feedback DynamoDB table"
  type        = string
}

variable "feedback_table_name" {
  description = "Name of the feedback DynamoDB table"
  type        = string
}

variable "bedrock_region" {
  description = "AWS region for Bedrock model invocation"
  type        = string
  default     = "ap-south-1"
}

variable "pubmed_email" {
  description = "Email address for PubMed API requests (required by NCBI)"
  type        = string
}
