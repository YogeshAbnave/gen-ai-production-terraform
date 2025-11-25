variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "app-data-table"
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name (will be appended with random suffix)"
  type        = string
  default     = "education-portal-images"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class for distribution"
  type        = string
  default     = "PriceClass_100"
}

variable "image_lifecycle_ia_days" {
  description = "Days before transitioning images to Infrequent Access storage"
  type        = number
  default     = 90
}

variable "image_lifecycle_glacier_days" {
  description = "Days in IA before transitioning to Glacier storage"
  type        = number
  default     = 180
}

variable "image_lifecycle_expiration_days" {
  description = "Days in Glacier before permanent deletion"
  type        = number
  default     = 365
}
