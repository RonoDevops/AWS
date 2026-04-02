################################################################################
# Monitoring - CloudWatch Log Groups, Alarms, and SNS
################################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "monitoring"
    Project     = var.project_name
    Environment = var.environment
  })

  # Identify ingestion functions (all functions except query_orchestrator)
  ingestion_function_names = {
    for k, v in var.lambda_function_names : k => v if k != "query_orchestrator"
  }
}

################################################################################
# SNS Topic for Alarm Notifications
################################################################################

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

################################################################################
# CloudWatch Log Groups for Lambda Functions
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = var.lambda_function_names

  name              = "/aws/lambda/${each.value}"
  retention_in_days = 30

  tags = local.common_tags
}

################################################################################
# Alarm 1: Query Orchestrator Error Rate > 5%
################################################################################

resource "aws_cloudwatch_metric_alarm" "query_orchestrator_error_rate" {
  alarm_name          = "${local.name_prefix}-query-orchestrator-error-rate"
  alarm_description   = "Query orchestrator Lambda error rate exceeds 5%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"

      dimensions = {
        FunctionName = var.lambda_function_names["query_orchestrator"]
      }
    }
  }

  metric_query {
    id = "invocations"

    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"

      dimensions = {
        FunctionName = var.lambda_function_names["query_orchestrator"]
      }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

################################################################################
# Alarm 2: Query Orchestrator Duration > 50s (timeout warning)
################################################################################

resource "aws_cloudwatch_metric_alarm" "query_orchestrator_duration" {
  alarm_name          = "${local.name_prefix}-query-orchestrator-duration"
  alarm_description   = "Query orchestrator Lambda duration exceeds 50 seconds - approaching timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 50000
  statistic           = "Maximum"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_names["query_orchestrator"]
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

################################################################################
# Alarm 3: Ingestion Function Error Rate > 10%
################################################################################

resource "aws_cloudwatch_metric_alarm" "ingestion_error_rate" {
  for_each = local.ingestion_function_names

  alarm_name          = "${local.name_prefix}-${each.key}-error-rate"
  alarm_description   = "Ingestion function ${each.key} error rate exceeds 10%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 10
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"

      dimensions = {
        FunctionName = each.value
      }
    }
  }

  metric_query {
    id = "invocations"

    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"

      dimensions = {
        FunctionName = each.value
      }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

################################################################################
# Alarm 4: DynamoDB Throttled Requests > 0
################################################################################

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${local.name_prefix}-dynamodb-throttled-requests"
  alarm_description   = "DynamoDB table ${var.dynamodb_table_name} has throttled requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 0
  statistic           = "Sum"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

################################################################################
# Alarm 5: API Gateway 5xx Error Rate > 5%
################################################################################

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${local.name_prefix}-api-gateway-5xx-rate"
  alarm_description   = "API Gateway 5xx error rate exceeds 5%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors_5xx / total_requests) * 100"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors_5xx"

    metric {
      metric_name = "5XXError"
      namespace   = "AWS/ApiGateway"
      period      = 300
      stat        = "Sum"

      dimensions = {
        ApiName = var.api_gateway_name
      }
    }
  }

  metric_query {
    id = "total_requests"

    metric {
      metric_name = "Count"
      namespace   = "AWS/ApiGateway"
      period      = 300
      stat        = "Sum"

      dimensions = {
        ApiName = var.api_gateway_name
      }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}
