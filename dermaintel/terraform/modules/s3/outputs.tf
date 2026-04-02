# -----------------------------------------------------------------------------
# Papers Bucket Outputs
# -----------------------------------------------------------------------------

output "papers_bucket_name" {
  description = "Name of the papers S3 bucket"
  value       = aws_s3_bucket.papers.bucket
}

output "papers_bucket_arn" {
  description = "ARN of the papers S3 bucket"
  value       = aws_s3_bucket.papers.arn
}

output "papers_bucket_regional_domain_name" {
  description = "Regional domain name of the papers S3 bucket"
  value       = aws_s3_bucket.papers.bucket_regional_domain_name
}

output "papers_bucket_id" {
  description = "ID of the papers S3 bucket"
  value       = aws_s3_bucket.papers.id
}

# -----------------------------------------------------------------------------
# Frontend Bucket Outputs
# -----------------------------------------------------------------------------

output "frontend_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_regional_domain_name" {
  description = "Regional domain name of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "frontend_bucket_id" {
  description = "ID of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_website_endpoint" {
  description = "Website endpoint of the frontend S3 bucket"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}
