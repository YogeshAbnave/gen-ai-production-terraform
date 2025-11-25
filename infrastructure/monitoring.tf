# CloudWatch Dashboard for S3 and CloudFront Metrics
resource "aws_cloudwatch_dashboard" "images" {
  dashboard_name = "education-portal-images"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", { stat = "Average", label = "Bucket Size (Bytes)" }],
            [".", "NumberOfObjects", { stat = "Average", label = "Number of Objects" }]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Bucket Storage"
          yAxis = {
            left = {
              label = "Bytes / Count"
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "AllRequests", { stat = "Sum", label = "Total Requests" }],
            [".", "GetRequests", { stat = "Sum", label = "GET Requests" }],
            [".", "PutRequests", { stat = "Sum", label = "PUT Requests" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "S3 Request Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "4xxErrors", { stat = "Sum", label = "4xx Errors" }],
            [".", "5xxErrors", { stat = "Sum", label = "5xx Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "S3 Error Rates"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", { stat = "Sum", label = "Total Requests" }],
            [".", "BytesDownloaded", { stat = "Sum", label = "Bytes Downloaded" }]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "CloudFront Request Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", { stat = "Average", label = "Cache Hit Rate (%)" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront Cache Performance"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", { stat = "Average", label = "4xx Error Rate" }],
            [".", "5xxErrorRate", { stat = "Average", label = "5xx Error Rate" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront Error Rates"
        }
      }
    ]
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "image_alerts" {
  name = "education-portal-image-alerts"

  tags = {
    Name        = "Image Storage Alerts"
    Environment = "Production"
  }
}

# CloudWatch Alarm: S3 Upload Failure Rate
resource "aws_cloudwatch_metric_alarm" "s3_upload_failures" {
  alarm_name          = "education-portal-s3-upload-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when S3 upload failures exceed 5% of requests"
  alarm_actions       = [aws_sns_topic.image_alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.images.id
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: CloudFront Cache Hit Ratio
resource "aws_cloudwatch_metric_alarm" "cloudfront_cache_hit_ratio" {
  alarm_name          = "education-portal-cloudfront-cache-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Alert when CloudFront cache hit ratio falls below 70%"
  alarm_actions       = [aws_sns_topic.image_alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.images.id
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: S3 Bucket Size (80% of 100GB quota)
resource "aws_cloudwatch_metric_alarm" "s3_bucket_size" {
  alarm_name          = "education-portal-s3-bucket-size-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = "85899345920"  # 80GB in bytes
  alarm_description   = "Alert when S3 bucket size exceeds 80GB"
  alarm_actions       = [aws_sns_topic.image_alerts.arn]

  dimensions = {
    BucketName  = aws_s3_bucket.images.id
    StorageType = "StandardStorage"
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: S3 4xx Error Rate
resource "aws_cloudwatch_metric_alarm" "s3_4xx_errors" {
  alarm_name          = "education-portal-s3-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when S3 4xx errors exceed 10 per 5 minutes"
  alarm_actions       = [aws_sns_topic.image_alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.images.id
  }

  treat_missing_data = "notBreaching"
}
