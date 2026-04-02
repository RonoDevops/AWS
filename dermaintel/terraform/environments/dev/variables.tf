# =============================================================================
# DermaIntel - Dev Environment Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dermaintel"
}

variable "pubmed_email" {
  description = "Email for PubMed NCBI E-utilities identification (required by NCBI)"
  type        = string
  default     = "admin@dermaintel.com"
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "alerts@dermaintel.com"
}
