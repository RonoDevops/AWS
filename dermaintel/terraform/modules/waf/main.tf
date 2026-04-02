################################################################################
# WAF v2 Web ACL - API Gateway Protection
################################################################################

locals {
  name_prefix = "${var.project_name}-api-waf-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "waf"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_wafv2_web_acl" "api" {
  name        = local.name_prefix
  description = "WAF Web ACL for ${var.project_name} API Gateway - ${var.environment}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # --------------------------------------------------------------------------
  # Rule 1: AWS Managed Common Rule Set
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # Rule 2: AWS Managed Known Bad Inputs Rule Set
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # Rule 3: Rate Limiting - 1000 requests per 5 minutes per IP
  # --------------------------------------------------------------------------
  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------------------
  # Rule 4: AWS Managed Bot Control Rule Set (count/monitoring only)
  # --------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 4

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bot-control-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name_prefix
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

################################################################################
# WAF Association with API Gateway Stage
################################################################################

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
