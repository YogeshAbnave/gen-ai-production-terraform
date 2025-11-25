# S3 Bucket for Image Storage
resource "aws_s3_bucket" "images" {
  bucket = "${var.s3_bucket_prefix}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Education Portal Images"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = var.image_lifecycle_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.image_lifecycle_ia_days + var.image_lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.image_lifecycle_ia_days + var.image_lifecycle_glacier_days + var.image_lifecycle_expiration_days
    }
  }

  rule {
    id     = "permanent-images"
    status = "Enabled"

    filter {
      tag {
        key   = "Retention"
        value = "Permanent"
      }
    }

    # Permanent images: only transition to IA, never delete
    transition {
      days          = var.image_lifecycle_ia_days
      storage_class = "STANDARD_IA"
    }
  }
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# Bucket Policy for CloudFront Access
resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.images.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })

  depends_on = [aws_cloudfront_origin_access_identity.images]
}
