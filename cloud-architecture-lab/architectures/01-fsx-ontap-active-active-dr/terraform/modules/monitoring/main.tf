# SnapMirror lag monitoring for the relationships this Region is the DESTINATION of:
# EventBridge (1 min) -> Lambda (ONTAP REST) -> CloudWatch metrics -> alarms -> SNS.

variable "name" { type = string }
variable "management_ip" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "fsx_admin_password" {
  type      = string
  sensitive = true
}
variable "destination_paths" {
  description = "SnapMirror destination paths on this cluster, e.g. [\"svm_b:vol_orders_dr\"]"
  type        = list(string)
}
variable "lag_warn_seconds" {
  type    = number
  default = 300
}
variable "lag_crit_seconds" {
  type    = number
  default = 600
}
variable "alarm_email" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  namespace = "Custom/FSxONTAP"
}

# ------------------------------------------------------------------ credentials
resource "aws_secretsmanager_secret" "fsxadmin" {
  name_prefix = "${var.name}-fsxadmin-"
  description = "fsxadmin credentials for the SnapMirror lag monitor and DR automation"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "fsxadmin" {
  secret_id     = aws_secretsmanager_secret.fsxadmin.id
  secret_string = jsonencode({ username = "fsxadmin", password = var.fsx_admin_password })
}

# ------------------------------------------------------------------ Lambda
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/snapmirror_lag_monitor.py"
  output_path = "${path.module}/.build/snapmirror_lag_monitor.zip"
}

resource "aws_iam_role" "lambda" {
  name_prefix = "${var.name}-lagmon-"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = aws_secretsmanager_secret.fsxadmin.arn },
      {
        Effect    = "Allow", Action = "cloudwatch:PutMetricData", Resource = "*",
        Condition = { StringEquals = { "cloudwatch:namespace" = local.namespace } }
      },
    ]
  })
}

resource "aws_security_group" "lambda" {
  name        = "${var.name}-lagmon"
  description = "SnapMirror lag monitor Lambda"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_egress_rule" "lambda_https" {
  security_group_id = aws_security_group.lambda.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "ONTAP REST API + AWS API VPC endpoints"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}-snapmirror-lag-monitor"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_lambda_function" "lag_monitor" {
  function_name    = "${var.name}-snapmirror-lag-monitor"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "snapmirror_lag_monitor.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ONTAP_HOST = var.management_ip
      SECRET_ARN = aws_secretsmanager_secret.fsxadmin.arn
      NAMESPACE  = local.namespace
      CLUSTER    = var.name
      # FSx ONTAP ships a self-signed certificate. Install a CA-signed cert on the
      # cluster and set this to "true" for production.
      VERIFY_TLS = "false"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy_attachment.vpc_access]
  tags       = var.tags
}

resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "${var.name}-snapmirror-lag-poll"
  schedule_expression = "rate(1 minute)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.every_minute.name
  arn  = aws_lambda_function.lag_monitor.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lag_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}

# ------------------------------------------------------------------ alarms
resource "aws_sns_topic" "dr" {
  name = "${var.name}-fsx-dr-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == null ? 0 : 1
  topic_arn = aws_sns_topic.dr.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "lag_warn" {
  for_each            = toset(var.destination_paths)
  alarm_name          = "${var.name} SnapMirror lag WARN ${each.key}"
  alarm_description   = "Lag above ${var.lag_warn_seconds}s: RPO target at risk. See docs/runbook.md."
  namespace           = local.namespace
  metric_name         = "SnapMirrorLagSeconds"
  dimensions          = { Cluster = var.name, Destination = each.key }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = var.lag_warn_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.dr.arn]
  ok_actions          = [aws_sns_topic.dr.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lag_crit" {
  for_each            = toset(var.destination_paths)
  alarm_name          = "${var.name} SnapMirror lag CRIT ${each.key}"
  alarm_description   = "Lag above ${var.lag_crit_seconds}s for 3 minutes: RPO breached. See docs/runbook.md."
  namespace           = local.namespace
  metric_name         = "SnapMirrorLagSeconds"
  dimensions          = { Cluster = var.name, Destination = each.key }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.lag_crit_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.dr.arn]
  ok_actions          = [aws_sns_topic.dr.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  for_each            = toset(var.destination_paths)
  alarm_name          = "${var.name} SnapMirror unhealthy ${each.key}"
  alarm_description   = "ONTAP reports the relationship unhealthy (broken, failed transfer, or peer unreachable)."
  namespace           = local.namespace
  metric_name         = "SnapMirrorHealthy"
  dimensions          = { Cluster = var.name, Destination = each.key }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.dr.arn]
  ok_actions          = [aws_sns_topic.dr.arn]
  tags                = var.tags
}

output "sns_topic_arn" {
  value = aws_sns_topic.dr.arn
}

output "secret_arn" {
  value = aws_secretsmanager_secret.fsxadmin.arn
}
