################################################################################
# Step Functions Module - DermaIntel Ingestion Pipeline
# Orchestrates PubMed fetching, tree building, and metadata extraction
################################################################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  resource_prefix = "${var.project_name}-ingestion-${var.environment}"
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/states/${local.resource_prefix}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name        = "${local.resource_prefix}-logs"
    Environment = var.environment
    Project     = var.project_name
  })
}

################################################################################
# IAM Role for Step Functions
################################################################################

data "aws_iam_policy_document" "step_functions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "step_functions" {
  name               = "${local.resource_prefix}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume_role.json

  tags = merge(var.tags, {
    Name        = "${local.resource_prefix}-sfn-role"
    Environment = var.environment
    Project     = var.project_name
  })
}

data "aws_iam_policy_document" "step_functions_policy" {
  statement {
    sid    = "InvokeLambdaFunctions"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      var.pubmed_fetcher_arn,
      var.tree_builder_arn,
      var.metadata_extractor_arn,
    ]
  }

  statement {
    sid    = "CloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:CreateLogStream",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutLogEvents",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "step_functions" {
  name   = "${local.resource_prefix}-sfn-policy"
  role   = aws_iam_role.step_functions.id
  policy = data.aws_iam_policy_document.step_functions_policy.json
}

################################################################################
# Step Functions State Machine
################################################################################

resource "aws_sfn_state_machine" "ingestion_pipeline" {
  name     = "dermaintel-ingestion-${var.environment}"
  role_arn = aws_iam_role.step_functions.arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/definition.asl.json", {
    pubmed_fetcher_arn     = var.pubmed_fetcher_arn
    tree_builder_arn       = var.tree_builder_arn
    metadata_extractor_arn = var.metadata_extractor_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "dermaintel-ingestion-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  })

  depends_on = [aws_iam_role_policy.step_functions]
}
