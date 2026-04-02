################################################################################
# API Gateway Module - DermaIntel
# Routes & methods defined via OpenAPI/Swagger spec (openapi.yaml)
# NO inline route/integration/method blocks in Terraform
################################################################################

data "aws_region" "current" {}

locals {
  api_name = "${var.project_name}-api-${var.environment}"
}

# ---------------------------------------------------------------------------
# API Gateway V2 HTTP API - Imported from OpenAPI spec
# All routes, methods, integrations, and authorizer config live in openapi.yaml
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "this" {
  name          = local.api_name
  protocol_type = "HTTP"
  description   = "DermaIntel API - AI Clinical Intelligence for Dermatology"

  # Import full API definition from OpenAPI 3.0 spec
  body = templatefile("${path.module}/openapi.yaml", {
    cognito_domain                = var.cognito_domain
    cognito_client_id             = var.cognito_user_pool_client_id
    cognito_user_pool_id          = var.cognito_user_pool_id
    region                        = data.aws_region.current.name
    query_orchestrator_invoke_arn = var.lambda_invoke_arns["query_orchestrator"]
    chatbot_invoke_arn            = var.lambda_invoke_arns["chatbot"]
    list_papers_invoke_arn        = var.lambda_invoke_arns["list_papers"]
    get_paper_invoke_arn          = var.lambda_invoke_arns["get_paper"]
    list_conditions_invoke_arn    = var.lambda_invoke_arns["list_conditions"]
    submit_feedback_invoke_arn    = var.lambda_invoke_arns["submit_feedback"]
  })

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key"]
    max_age       = 3600
  }

  tags = merge(var.tags, {
    Name = local.api_name
  })
}

# ---------------------------------------------------------------------------
# Stage with auto-deploy and access logging
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.environment
  auto_deploy = true
  description = "${var.environment} stage with auto-deploy"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn

    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      userAgent        = "$context.identity.userAgent"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  tags = merge(var.tags, {
    Name = "${local.api_name}-${var.environment}"
  })
}

# ---------------------------------------------------------------------------
# Lambda Permissions - Allow API GW to invoke each Lambda
# This is the ONLY Lambda-related config in Terraform (required for IAM)
# ---------------------------------------------------------------------------
resource "aws_lambda_permission" "api_gw" {
  for_each = var.lambda_function_names

  statement_id  = "AllowAPIGW-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
