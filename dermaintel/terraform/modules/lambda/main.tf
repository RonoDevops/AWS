################################################################################
# Lambda Module - DermaIntel Function Definitions & IAM
# Creates all Lambda functions grouped by domain with least-privilege IAM roles
################################################################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "lambda"
  })

  name_prefix = "${var.project_name}-${var.environment}"

  # ---------------------------------------------------------------------------
  # Function definitions by group
  # ---------------------------------------------------------------------------
  ingestion_functions = {
    pubmed_fetcher = {
      handler     = "src/ingestion/pubmed_fetcher.handler"
      timeout     = 300
      memory_size = 512
      environment = {
        PAPERS_BUCKET = var.papers_bucket_name
        PUBMED_EMAIL  = var.pubmed_email
      }
    }
    tree_builder = {
      handler     = "src/ingestion/tree_builder.handler"
      timeout     = 600
      memory_size = 1024
      environment = {
        PAPERS_BUCKET  = var.papers_bucket_name
        BEDROCK_REGION = var.bedrock_region
      }
    }
    metadata_extractor = {
      handler     = "src/ingestion/metadata_extractor.handler"
      timeout     = 120
      memory_size = 512
      environment = {
        PAPERS_BUCKET  = var.papers_bucket_name
        PAPERS_TABLE   = var.papers_table_name
        BEDROCK_REGION = var.bedrock_region
      }
    }
  }

  query_functions = {
    query_orchestrator = {
      handler     = "src/query/orchestrator.handler"
      timeout     = 60
      memory_size = 1024
      environment = {
        PAPERS_BUCKET  = var.papers_bucket_name
        PAPERS_TABLE   = var.papers_table_name
        BEDROCK_REGION = var.bedrock_region
        FEEDBACK_TABLE = var.feedback_table_name
      }
    }
  }

  api_functions = {
    list_papers = {
      handler     = "src/api/list_papers.handler"
      timeout     = 10
      memory_size = 256
      environment = {
        PAPERS_TABLE = var.papers_table_name
      }
    }
    get_paper = {
      handler     = "src/api/get_paper.handler"
      timeout     = 10
      memory_size = 256
      environment = {
        PAPERS_TABLE  = var.papers_table_name
        PAPERS_BUCKET = var.papers_bucket_name
      }
    }
    list_conditions = {
      handler     = "src/api/list_conditions.handler"
      timeout     = 10
      memory_size = 256
      environment = {
        PAPERS_TABLE = var.papers_table_name
      }
    }
    submit_feedback = {
      handler     = "src/api/submit_feedback.handler"
      timeout     = 10
      memory_size = 256
      environment = {
        FEEDBACK_TABLE = var.feedback_table_name
      }
    }
  }

  # Merge all functions for outputs
  all_functions = merge(local.ingestion_functions, local.query_functions, local.api_functions)
}

################################################################################
# Lambda Layer - Shared Dependencies
################################################################################

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${var.source_path}/layers/shared"
  output_path = "${path.module}/.build/${local.name_prefix}-layer-shared.zip"
}

resource "aws_lambda_layer_version" "shared" {
  layer_name          = "${local.name_prefix}-shared-deps"
  filename            = data.archive_file.layer.output_path
  source_code_hash    = data.archive_file.layer.output_base64sha256
  compatible_runtimes = ["python3.12"]

  tags = local.common_tags
}

################################################################################
# Deployment Packages
################################################################################

data "archive_file" "functions" {
  for_each = local.all_functions

  type        = "zip"
  source_dir  = "${var.source_path}/${dirname(each.value.handler)}"
  output_path = "${path.module}/.build/${local.name_prefix}-${each.key}.zip"
}

################################################################################
# IAM - Ingestion Role
################################################################################

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---- Ingestion Role ----

resource "aws_iam_role" "ingestion" {
  name               = "${local.name_prefix}-lambda-ingestion"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ingestion" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name_prefix}-*:*",
    ]
  }

  # S3 read/write on papers bucket
  statement {
    sid    = "S3ReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      var.papers_bucket_arn,
      "${var.papers_bucket_arn}/*",
    ]
  }

  # DynamoDB write on papers table
  statement {
    sid    = "DynamoDBWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      var.papers_table_arn,
      "${var.papers_table_arn}/index/*",
    ]
  }

  # Bedrock invoke model
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:aws:bedrock:${var.bedrock_region}::foundation-model/*",
    ]
  }
}

resource "aws_iam_role_policy" "ingestion" {
  name   = "${local.name_prefix}-lambda-ingestion"
  role   = aws_iam_role.ingestion.id
  policy = data.aws_iam_policy_document.ingestion.json
}

# ---- Query Role ----

resource "aws_iam_role" "query" {
  name               = "${local.name_prefix}-lambda-query"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "query" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name_prefix}-*:*",
    ]
  }

  # S3 read on papers bucket
  statement {
    sid    = "S3Read"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.papers_bucket_arn,
      "${var.papers_bucket_arn}/*",
    ]
  }

  # DynamoDB read on papers table
  statement {
    sid    = "DynamoDBReadPapers"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
    ]
    resources = [
      var.papers_table_arn,
      "${var.papers_table_arn}/index/*",
    ]
  }

  # DynamoDB write on feedback table
  statement {
    sid    = "DynamoDBWriteFeedback"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      var.feedback_table_arn,
    ]
  }

  # Bedrock invoke model
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:aws:bedrock:${var.bedrock_region}::foundation-model/*",
    ]
  }
}

resource "aws_iam_role_policy" "query" {
  name   = "${local.name_prefix}-lambda-query"
  role   = aws_iam_role.query.id
  policy = data.aws_iam_policy_document.query.json
}

# ---- API Role ----

resource "aws_iam_role" "api" {
  name               = "${local.name_prefix}-lambda-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "api" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name_prefix}-*:*",
    ]
  }

  # DynamoDB read on papers table
  statement {
    sid    = "DynamoDBReadPapers"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
    ]
    resources = [
      var.papers_table_arn,
      "${var.papers_table_arn}/index/*",
    ]
  }

  # S3 read on papers bucket
  statement {
    sid    = "S3Read"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.papers_bucket_arn,
      "${var.papers_bucket_arn}/*",
    ]
  }

  # DynamoDB write on feedback table
  statement {
    sid    = "DynamoDBWriteFeedback"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      var.feedback_table_arn,
    ]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "${local.name_prefix}-lambda-api"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api.json
}

################################################################################
# CloudWatch Log Groups
################################################################################

resource "aws_cloudwatch_log_group" "functions" {
  for_each = local.all_functions

  name              = "/aws/lambda/${local.name_prefix}-${each.key}"
  retention_in_days = var.environment == "prod" ? 90 : 14

  tags = local.common_tags
}

################################################################################
# Lambda Functions - Ingestion Group
################################################################################

resource "aws_lambda_function" "ingestion" {
  for_each = local.ingestion_functions

  function_name    = "${local.name_prefix}-${each.key}"
  handler          = each.value.handler
  runtime          = "python3.12"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  role             = aws_iam_role.ingestion.arn
  filename         = data.archive_file.functions[each.key].output_path
  source_code_hash = data.archive_file.functions[each.key].output_base64sha256

  layers = [aws_lambda_layer_version.shared.arn]

  environment {
    variables = merge(each.value.environment, {
      ENVIRONMENT = var.environment
    })
  }

  depends_on = [
    aws_iam_role_policy.ingestion,
    aws_cloudwatch_log_group.functions,
  ]

  tags = merge(local.common_tags, {
    FunctionGroup = "ingestion"
  })
}

################################################################################
# Lambda Functions - Query Group
################################################################################

resource "aws_lambda_function" "query" {
  for_each = local.query_functions

  function_name    = "${local.name_prefix}-${each.key}"
  handler          = each.value.handler
  runtime          = "python3.12"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  role             = aws_iam_role.query.arn
  filename         = data.archive_file.functions[each.key].output_path
  source_code_hash = data.archive_file.functions[each.key].output_base64sha256

  layers = [aws_lambda_layer_version.shared.arn]

  environment {
    variables = merge(each.value.environment, {
      ENVIRONMENT = var.environment
    })
  }

  depends_on = [
    aws_iam_role_policy.query,
    aws_cloudwatch_log_group.functions,
  ]

  tags = merge(local.common_tags, {
    FunctionGroup = "query"
  })
}

################################################################################
# Lambda Functions - API Group
################################################################################

resource "aws_lambda_function" "api" {
  for_each = local.api_functions

  function_name    = "${local.name_prefix}-${each.key}"
  handler          = each.value.handler
  runtime          = "python3.12"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  role             = aws_iam_role.api.arn
  filename         = data.archive_file.functions[each.key].output_path
  source_code_hash = data.archive_file.functions[each.key].output_base64sha256

  layers = [aws_lambda_layer_version.shared.arn]

  environment {
    variables = merge(each.value.environment, {
      ENVIRONMENT = var.environment
    })
  }

  depends_on = [
    aws_iam_role_policy.api,
    aws_cloudwatch_log_group.functions,
  ]

  tags = merge(local.common_tags, {
    FunctionGroup = "api"
  })
}
