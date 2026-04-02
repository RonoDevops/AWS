locals {
  papers_bucket_name   = "${var.project_name}-papers-${var.environment}"
  frontend_bucket_name = "${var.project_name}-frontend-${var.environment}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "s3"
  })
}

# -----------------------------------------------------------------------------
# Papers Bucket - Stores PDFs, tree JSONs, markdown
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "papers" {
  bucket = local.papers_bucket_name
  tags   = merge(local.common_tags, { Name = local.papers_bucket_name })
}

resource "aws_s3_bucket_versioning" "papers" {
  bucket = aws_s3_bucket.papers.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "papers" {
  bucket = aws_s3_bucket.papers.id

  rule {
    id     = "raw-pdfs-to-ia"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "markdown-cleanup"
    status = "Enabled"

    filter {
      prefix = "markdown/"
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "papers" {
  bucket = aws_s3_bucket.papers.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "papers" {
  bucket = aws_s3_bucket.papers.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_cors_configuration" "papers" {
  bucket = aws_s3_bucket.papers.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }
}

# -----------------------------------------------------------------------------
# Frontend Bucket - Static website hosting for React app
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name
  tags   = merge(local.common_tags, { Name = local.frontend_bucket_name })
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
