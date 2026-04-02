################################################################################
# Variables - API Gateway Module (Swagger-driven)
################################################################################

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "dermaintel"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# -- Cognito (used to template into openapi.yaml) --

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID (for JWT issuer in Swagger)"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "Cognito App Client ID (for JWT audience in Swagger)"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito hosted UI domain prefix (for OAuth URL in Swagger)"
  type        = string
  default     = ""
}

# -- Lambda ARNs (templated into openapi.yaml x-amazon-apigateway-integration) --

variable "lambda_invoke_arns" {
  description = "Map of function key -> Lambda invoke ARN. Keys: query_orchestrator, chatbot, list_papers, get_paper, list_conditions, submit_feedback"
  type        = map(string)
}

variable "lambda_function_names" {
  description = "Map of function key -> Lambda function name (for IAM permissions)"
  type        = map(string)
}

# -- CORS --

variable "cors_allow_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["http://localhost:5173"]
}
