variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
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

variable "callback_urls" {
  description = "List of allowed callback URLs for the User Pool client"
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
}

variable "logout_urls" {
  description = "List of allowed logout URLs for the User Pool client"
  type        = list(string)
  default     = ["http://localhost:3000/logout"]
}
