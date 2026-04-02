################################################################################
# EventBridge Module - DermaIntel Daily Ingestion Scheduler
# Triggers the ingestion pipeline daily at 2:00 AM IST (20:30 UTC)
################################################################################

data "aws_caller_identity" "current" {}

locals {
  resource_prefix = "${var.project_name}-daily-ingestion-${var.environment}"
}

################################################################################
# IAM Role for EventBridge
################################################################################

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "eventbridge" {
  name               = "${local.resource_prefix}-eventbridge-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json

  tags = merge(var.tags, {
    Name        = "${local.resource_prefix}-eventbridge-role"
    Environment = var.environment
    Project     = var.project_name
  })
}

data "aws_iam_policy_document" "eventbridge_policy" {
  statement {
    sid    = "AllowStartExecution"
    effect = "Allow"
    actions = [
      "states:StartExecution",
    ]
    resources = [
      var.state_machine_arn,
    ]
  }
}

resource "aws_iam_role_policy" "eventbridge" {
  name   = "${local.resource_prefix}-eventbridge-policy"
  role   = aws_iam_role.eventbridge.id
  policy = data.aws_iam_policy_document.eventbridge_policy.json
}

################################################################################
# EventBridge Rule - Daily Schedule
################################################################################

resource "aws_cloudwatch_event_rule" "daily_ingestion" {
  name                = "dermaintel-daily-ingestion-${var.environment}"
  description         = "Triggers the DermaIntel ingestion pipeline daily at 2:00 AM IST (20:30 UTC)"
  schedule_expression = "cron(30 20 * * ? *)"

  tags = merge(var.tags, {
    Name        = "dermaintel-daily-ingestion-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  })
}

################################################################################
# EventBridge Target - Step Functions
################################################################################

resource "aws_cloudwatch_event_target" "step_functions" {
  rule     = aws_cloudwatch_event_rule.daily_ingestion.name
  arn      = var.state_machine_arn
  role_arn = aws_iam_role.eventbridge.arn

  input = jsonencode({
    source      = "dermaintel.scheduled"
    trigger     = "eventbridge-daily"
    date_range = {
      period   = "last_24_hours"
      timezone = "Asia/Kolkata"
    }
  })
}
