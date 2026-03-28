output "bucket_name" {
  value = aws_s3_bucket.media.id
}

output "bucket_arn" {
  value = aws_s3_bucket.media.arn
}

output "cdn_domain" {
  description = "CloudFront domain — use this as base URL for all media in the app"
  value       = aws_cloudfront_distribution.media.domain_name
}

output "cdn_distribution_id" {
  value = aws_cloudfront_distribution.media.id
}
