################################################################################
# Origin Access Control
################################################################################

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project_name}-oac-${var.environment}"
  description                       = "OAC for ${var.project_name} frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

################################################################################
# CloudFront Distribution
################################################################################

locals {
  s3_origin_id  = "${var.project_name}-s3-origin"
  api_origin_id = "${var.project_name}-api-origin"

  # Parse the API Gateway domain from the endpoint URL (strip https://)
  api_domain = var.api_gateway_endpoint != "" ? replace(var.api_gateway_endpoint, "https://", "") : ""
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  comment             = "${var.project_name} frontend distribution (${var.environment})"

  # S3 Origin (frontend assets)
  origin {
    domain_name              = var.frontend_bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  # API Gateway Origin (optional, for /api/* proxying)
  dynamic "origin" {
    for_each = var.api_gateway_endpoint != "" ? [1] : []
    content {
      domain_name = local.api_domain
      origin_id   = local.api_origin_id

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default cache behavior - S3 static assets
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    default_ttl = 86400
    min_ttl     = 0
    max_ttl     = 31536000
  }

  # API cache behavior (optional) - no caching, forward all to API Gateway
  dynamic "ordered_cache_behavior" {
    for_each = var.api_gateway_endpoint != "" ? [1] : []
    content {
      path_pattern           = "/api/*"
      allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.api_origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true

      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    }
  }

  # SPA routing: serve index.html for 403 and 404 errors
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # SSL - use default CloudFront certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = var.tags
}

################################################################################
# Managed Cache Policies (AWS-provided)
################################################################################

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

################################################################################
# S3 Bucket Policy - Allow CloudFront OAC to read from the bucket
################################################################################

data "aws_iam_policy_document" "s3_cloudfront_oac" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${var.frontend_bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id
  policy = data.aws_iam_policy_document.s3_cloudfront_oac.json
}
