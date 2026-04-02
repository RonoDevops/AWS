# =============================================================================
# DermaIntel - Dev Environment Root Module
# AI-Powered Clinical Intelligence for Dermatology
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Remote state - uncomment after first apply
  # backend "s3" {
  #   bucket         = "dermaintel-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "dermaintel-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "DermaIntel"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "NK-AheadConsulting"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  environment  = var.environment
  project_name = var.project_name
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
  }
}

# -----------------------------------------------------------------------------
# Module: S3 Buckets (Papers Storage + Frontend Hosting)
# -----------------------------------------------------------------------------
module "s3" {
  source = "../../modules/s3"

  environment  = local.environment
  project_name = local.project_name
  tags         = local.common_tags
}

# -----------------------------------------------------------------------------
# Module: DynamoDB (Single-Table Design)
# -----------------------------------------------------------------------------
module "dynamodb" {
  source = "../../modules/dynamodb"

  environment  = local.environment
  project_name = local.project_name
  tags         = local.common_tags
}

# -----------------------------------------------------------------------------
# Module: Cognito (User Authentication)
# -----------------------------------------------------------------------------
module "cognito" {
  source = "../../modules/cognito"

  environment   = local.environment
  project_name  = local.project_name
  tags          = local.common_tags
  callback_urls = ["https://${module.cloudfront.distribution_domain_name}", "http://localhost:5173"]
  logout_urls   = ["https://${module.cloudfront.distribution_domain_name}", "http://localhost:5173"]
}

# -----------------------------------------------------------------------------
# Module: Lambda Functions (All Backend Logic)
# -----------------------------------------------------------------------------
module "lambda" {
  source = "../../modules/lambda"

  environment          = local.environment
  project_name         = local.project_name
  tags                 = local.common_tags
  source_path          = "${path.module}/../../../src"
  papers_bucket_arn    = module.s3.papers_bucket_arn
  papers_bucket_name   = module.s3.papers_bucket_name
  papers_table_arn     = module.dynamodb.papers_table_arn
  papers_table_name    = module.dynamodb.papers_table_name
  feedback_table_arn   = module.dynamodb.feedback_table_arn
  feedback_table_name  = module.dynamodb.feedback_table_name
  bedrock_region       = var.aws_region
  pubmed_email         = var.pubmed_email
  chat_history_table_name = module.dynamodb.chat_history_table_name
  chat_history_table_arn  = module.dynamodb.chat_history_table_arn
}

# -----------------------------------------------------------------------------
# Module: API Gateway (HTTP API)
# -----------------------------------------------------------------------------
module "api_gateway" {
  source = "../../modules/api-gateway"

  environment                = local.environment
  project_name               = local.project_name
  tags                       = local.common_tags
  cognito_user_pool_arn      = module.cognito.user_pool_arn
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
  lambda_invoke_arns         = module.lambda.invoke_arns
  lambda_function_names      = module.lambda.function_names
}

# -----------------------------------------------------------------------------
# Module: CloudFront (CDN + Frontend Delivery)
# -----------------------------------------------------------------------------
module "cloudfront" {
  source = "../../modules/cloudfront"

  environment                          = local.environment
  project_name                         = local.project_name
  tags                                 = local.common_tags
  frontend_bucket_arn                  = module.s3.frontend_bucket_arn
  frontend_bucket_id                   = module.s3.frontend_bucket_id
  frontend_bucket_regional_domain_name = module.s3.frontend_bucket_regional_domain_name
  api_gateway_endpoint                 = module.api_gateway.api_endpoint
}

# -----------------------------------------------------------------------------
# Module: Step Functions (Ingestion Pipeline Orchestration)
# -----------------------------------------------------------------------------
module "step_functions" {
  source = "../../modules/step-functions"

  environment            = local.environment
  project_name           = local.project_name
  tags                   = local.common_tags
  pubmed_fetcher_arn     = module.lambda.ingestion_function_arns["pubmed_fetcher"]
  tree_builder_arn       = module.lambda.ingestion_function_arns["tree_builder"]
  metadata_extractor_arn = module.lambda.ingestion_function_arns["metadata_extractor"]
}

# -----------------------------------------------------------------------------
# Module: EventBridge (Daily Ingestion Schedule)
# -----------------------------------------------------------------------------
module "eventbridge" {
  source = "../../modules/eventbridge"

  environment       = local.environment
  project_name      = local.project_name
  tags              = local.common_tags
  state_machine_arn = module.step_functions.state_machine_arn
}

# -----------------------------------------------------------------------------
# Module: WAF (API Protection)
# -----------------------------------------------------------------------------
module "waf" {
  source = "../../modules/waf"

  environment            = local.environment
  project_name           = local.project_name
  tags                   = local.common_tags
  api_gateway_stage_arn  = module.api_gateway.stage_arn
}

# -----------------------------------------------------------------------------
# Module: Monitoring (CloudWatch + Alarms + SNS)
# -----------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  environment          = local.environment
  project_name         = local.project_name
  tags                 = local.common_tags
  lambda_function_names = module.lambda.function_names
  api_gateway_name     = module.api_gateway.api_name
  dynamodb_table_name  = module.dynamodb.papers_table_name
  alert_email          = var.alert_email
}
