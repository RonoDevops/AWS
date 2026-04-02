###############################################################################
# Cognito User Pool
###############################################################################

resource "aws_cognito_user_pool" "main" {
  name = "dermaintel-users-${var.environment}"

  # Sign-in configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Email verification
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "DermaIntel - Your verification code"
    email_message        = "Your verification code is {####}"
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Schema attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "tier"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 10
    }
  }

  schema {
    name                     = "queries_today"
    attribute_data_type      = "Number"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    number_attribute_constraints {
      min_value = "0"
      max_value = "10000"
    }
  }

  tags = merge(var.tags, {
    Module = "cognito"
  })
}

###############################################################################
# User Pool Domain (Cognito hosted)
###############################################################################

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "dermaintel-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}

###############################################################################
# User Pool Client (SPA - no client secret)
###############################################################################

resource "aws_cognito_user_pool_client" "web" {
  name         = "dermaintel-web-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Token validity
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent user-existence errors
  prevent_user_existence_errors = "ENABLED"
}

###############################################################################
# User Pool Groups
###############################################################################

resource "aws_cognito_user_group" "free" {
  name         = "free"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Free tier users"
  precedence   = 3
}

resource "aws_cognito_user_group" "pro" {
  name         = "pro"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Pro tier users"
  precedence   = 2
}

resource "aws_cognito_user_group" "premium" {
  name         = "premium"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Premium tier users"
  precedence   = 1
}
