resource "aws_s3_bucket" "media" {
  bucket = local.bucket_name
  tags   = { Name = local.bucket_name, Purpose = "User profile photos and media" }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS — React Native + web clients need this to upload directly from the browser
resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Lifecycle: delete incomplete multipart uploads after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
  rule {
    id     = "transition-to-ia"
    status = var.env_name == "prod" ? "Enabled" : "Disabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

# CloudFront OAC — serves media via CDN, S3 never public
resource "aws_cloudfront_origin_access_control" "media" {
  name                              = "da-${var.env_name}-media-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "media" {
  enabled             = true
  comment             = "da-${var.env_name} media CDN"
  default_root_object = ""
  price_class         = "PriceClass_200" # US, Europe, Asia

  origin {
    domain_name              = aws_s3_bucket.media.bucket_regional_domain_name
    origin_id                = "S3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.media.id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${local.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "da-${var.env_name}-media-cdn" }
}

# S3 bucket policy — only allows CloudFront OAC to read
resource "aws_s3_bucket_policy" "media" {
  bucket = aws_s3_bucket.media.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.media.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.media.arn
          }
        }
      },
      {
        Sid    = "AllowLambdaUpload"
        Effect = "Allow"
        Principal = {
          AWS = length(var.upload_role_arns) > 0 ? var.upload_role_arns : ["arn:aws:iam::${local.account_id}:root"]
        }
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.media.arn}/*"
      }
    ]
  })
}

# SSM
resource "aws_ssm_parameter" "media_bucket" {
  name  = "/${var.env_name}/infrastructure/s3/media-bucket-name"
  type  = "String"
  value = aws_s3_bucket.media.id
}

resource "aws_ssm_parameter" "cdn_domain" {
  name  = "/${var.env_name}/infrastructure/cloudfront/media-cdn-domain"
  type  = "String"
  value = aws_cloudfront_distribution.media.domain_name
}
