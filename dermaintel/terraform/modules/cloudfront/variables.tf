variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dermaintel"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "frontend_bucket_arn" {
  description = "ARN of the S3 bucket hosting the frontend assets"
  type        = string
}

variable "frontend_bucket_id" {
  description = "ID (name) of the S3 bucket hosting the frontend assets"
  type        = string
}

variable "frontend_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "api_gateway_endpoint" {
  description = "API Gateway endpoint URL for /api/* cache behavior (optional)"
  type        = string
  default     = ""
}
