# Design Document: S3 Image Storage Infrastructure

## Overview

This design document outlines the implementation of production-grade S3 image storage for the education portal application. The system will provision S3 infrastructure using Terraform, implement secure image upload/download workflows, integrate CloudFront CDN for global delivery, add image optimization, and create comprehensive load testing scenarios to validate performance under concurrent user load.

The current application generates images using AWS Bedrock Nova Canvas but lacks proper infrastructure for persistent storage. This design addresses that gap while adding production-grade features like encryption, lifecycle management, monitoring, and performance optimization.

## Architecture

### High-Level Architecture

```
┌─────────────┐
│   Teacher   │
│   Browser   │
└──────┬──────┘
       │ 1. Create Assignment
       ▼
┌─────────────────────────────────────────┐
│         Streamlit Application           │
│  (Running on EC2 Auto Scaling Group)    │
│                                         │
│  ┌──────────────┐    ┌──────────────┐  │
│  │ Create Page  │───▶│ Bedrock API  │  │
│  │ (Generate)   │    │ (Nova Canvas)│  │
│  └──────┬───────┘    └──────────────┘  │
│         │                               │
│         │ 2. Optimize Image             │
│         ▼                               │
│  ┌──────────────┐                      │
│  │   Image      │                      │
│  │ Optimization │                      │
│  └──────┬───────┘                      │
│         │                               │
│         │ 3. Upload to S3               │
└─────────┼───────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────┐
│           AWS S3 Bucket                 │
│  (Server-side encryption, versioning)   │
│                                         │
│  generated_images/                      │
│    ├── {assignment_id_1}.webp          │
│    ├── {assignment_id_2}.webp          │
│    └── ...                              │
└─────────┬───────────────────────────────┘
          │
          │ 4. Distribute via CDN
          ▼
┌─────────────────────────────────────────┐
│        CloudFront Distribution          │
│   (Global edge locations, caching)      │
└─────────┬───────────────────────────────┘
          │
          │ 5. Retrieve Image
          ▼
┌─────────────────┐
│    Student      │
│    Browser      │
└─────────────────┘
```

### Component Interaction Flow

1. **Image Generation**: Teacher enters prompt → Streamlit calls Bedrock Nova Canvas → Raw PNG image returned
2. **Image Optimization**: PIL/Pillow compresses and converts PNG to WebP format
3. **S3 Upload**: Boto3 uploads optimized image using IAM role credentials
4. **Metadata Storage**: MongoDB stores S3 object key alongside assignment data
5. **Image Retrieval**: Student views assignment → App downloads from S3 → Cached locally for session
6. **CDN Delivery**: CloudFront serves cached images from nearest edge location

### Infrastructure Components

- **S3 Bucket**: Primary storage for generated images
- **CloudFront Distribution**: CDN for low-latency global delivery
- **IAM Role**: Grants EC2 instances permission to access S3
- **Lifecycle Policies**: Automatic archival and deletion of old images
- **CloudWatch**: Monitoring and alerting for S3 operations
- **MongoDB**: Stores assignment metadata including S3 object keys

## Components and Interfaces

### 1. Terraform S3 Module (`infrastructure/s3.tf`)

**Purpose**: Provision S3 bucket with security and lifecycle policies

**Resources**:
- `aws_s3_bucket`: Main bucket for image storage
- `aws_s3_bucket_versioning`: Enable versioning for data protection
- `aws_s3_bucket_server_side_encryption_configuration`: AES-256 encryption
- `aws_s3_bucket_public_access_block`: Block all public access
- `aws_s3_bucket_lifecycle_configuration`: Automatic archival/deletion rules
- `aws_s3_bucket_cors_configuration`: CORS rules for web access

**Configuration**:
```hcl
bucket_name = "education-portal-images-${random_id}"
versioning = enabled
encryption = AES256
lifecycle_rules:
  - transition_to_ia: 90 days
  - transition_to_glacier: 270 days (90 + 180)
  - expiration: 635 days (90 + 180 + 365)
```

### 2. Terraform CloudFront Module (`infrastructure/cloudfront.tf`)

**Purpose**: CDN distribution for fast image delivery

**Resources**:
- `aws_cloudfront_distribution`: CDN distribution
- `aws_cloudfront_origin_access_identity`: Secure S3 access

**Configuration**:
```hcl
origin: S3 bucket
default_cache_behavior:
  - viewer_protocol_policy: redirect-to-https
  - allowed_methods: GET, HEAD, OPTIONS
  - cached_methods: GET, HEAD
  - default_ttl: 86400 (24 hours)
  - max_ttl: 31536000 (1 year)
price_class: PriceClass_100 (US, Canada, Europe)
```

### 3. Terraform IAM Module (`infrastructure/iam.tf` - additions)

**Purpose**: Grant EC2 instances S3 access

**New Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${bucket_name}/*",
        "arn:aws:s3:::${bucket_name}"
      ]
    }
  ]
}
```

### 4. Image Upload Service (`src/services/s3_service.py`)

**Purpose**: Handle image upload operations with retry logic

**Interface**:
```python
class S3ImageService:
    def __init__(self, bucket_name: str, region: str)
    
    def upload_image(
        self, 
        image: Image.Image, 
        assignment_id: str,
        max_retries: int = 3
    ) -> str:
        """
        Upload optimized image to S3
        Returns: S3 object key
        Raises: S3UploadError on failure
        """
    
    def download_image(
        self, 
        object_key: str,
        local_path: str
    ) -> bool:
        """
        Download image from S3
        Returns: True on success, False on failure
        """
    
    def delete_image(self, object_key: str) -> bool:
        """Delete image from S3"""
    
    def get_image_url(self, object_key: str) -> str:
        """Get CloudFront URL for image"""
```

**Error Handling**:
- Retry logic with exponential backoff
- Specific exception types: `S3UploadError`, `S3DownloadError`, `S3PermissionError`
- Correlation IDs for debugging

### 5. Image Optimization Service (`src/services/image_optimizer.py`)

**Purpose**: Compress and optimize images before upload

**Interface**:
```python
class ImageOptimizer:
    def __init__(self, max_dimension: int = 1024, quality: int = 85)
    
    def optimize(self, image: Image.Image) -> Image.Image:
        """
        Optimize image:
        1. Resize if exceeds max_dimension
        2. Convert to WebP format
        3. Compress with specified quality
        Returns: Optimized PIL Image
        """
    
    def calculate_compression_ratio(
        self, 
        original: Image.Image, 
        optimized: Image.Image
    ) -> float:
        """Calculate compression percentage"""
```

**Optimization Strategy**:
- Target: 30%+ file size reduction
- Format: PNG → WebP (better compression)
- Max dimensions: 1024x1024 (maintain aspect ratio)
- Quality: 85 (balance between size and visual quality)

### 6. Load Testing Module (`load-testing/image_operations.py`)

**Purpose**: Test image generation, upload, and retrieval under load

**Test Scenarios**:

```python
class ImageLoadTest(HttpUser):
    """Test image-heavy assignment creation"""
    
    @task(3)
    def create_assignment_with_image(self):
        """
        Simulates teacher creating assignment:
        1. Generate image via Bedrock
        2. Optimize image
        3. Upload to S3
        4. Save metadata to MongoDB
        """
    
    @task(5)
    def view_assignment_with_image(self):
        """
        Simulates student viewing assignment:
        1. Fetch assignment from MongoDB
        2. Download image from S3/CloudFront
        3. Display in UI
        """
    
    @task(1)
    def list_assignments(self):
        """List assignments without loading images"""
```

**Load Test Configuration**:
```python
# Concurrent users
users = 50
spawn_rate = 5  # users per second

# Test duration
run_time = "10m"

# Metrics to capture
- S3 upload latency (p50, p95, p99)
- S3 download latency (p50, p95, p99)
- CloudFront cache hit ratio
- Error rates for S3 operations
- Auto-scaling trigger timing
```

### 7. Monitoring and Alerting (`infrastructure/monitoring.tf`)

**Purpose**: CloudWatch dashboards and alarms

**Metrics**:
- S3 bucket size
- Number of objects
- Request count (GET, PUT)
- 4xx/5xx error rates
- CloudFront cache hit ratio
- Average latency

**Alarms**:
- S3 upload failure rate > 5%
- CloudFront cache hit ratio < 70%
- Bucket size > 80% of quota
- 4xx error rate > 10%

## Data Models

### MongoDB Assignment Document (Updated)

```json
{
  "assignment_id": "1732612345678",
  "teacher_id": "CloudAge-User",
  "prompt": "A serene mountain landscape at sunset",
  "s3_image_key": "generated_images/1732612345678.webp",
  "cloudfront_url": "https://d1234567890.cloudfront.net/generated_images/1732612345678.webp",
  "image_metadata": {
    "original_size_bytes": 2048576,
    "optimized_size_bytes": 1024288,
    "compression_ratio": 0.50,
    "format": "webp",
    "dimensions": "1024x1024"
  },
  "question_answers": "[{...}]",
  "created_at": 1732612345.678,
  "s3_upload_status": "success",
  "s3_upload_attempts": 1
}
```

**New Fields**:
- `s3_image_key`: S3 object key (replaces `s3_image_name`)
- `cloudfront_url`: Full CloudFront URL for direct access
- `image_metadata`: Optimization statistics
- `s3_upload_status`: "success", "failed", "pending", "no_image"
- `s3_upload_attempts`: Number of retry attempts

### S3 Object Metadata

```json
{
  "Content-Type": "image/webp",
  "Cache-Control": "max-age=31536000",
  "x-amz-meta-assignment-id": "1732612345678",
  "x-amz-meta-teacher-id": "CloudAge-User",
  "x-amz-meta-created-at": "2024-11-26T10:30:45Z",
  "x-amz-meta-original-format": "png",
  "x-amz-meta-optimized": "true"
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: S3 upload persistence
*For any* generated image and assignment ID, when the image is successfully uploaded to S3, then retrieving the object using the stored S3 key should return an image with identical content
**Validates: Requirements 1.1, 1.2**

### Property 2: Upload retry idempotence
*For any* image upload operation that fails, retrying the upload up to 3 times should eventually succeed or consistently fail with the same error, and should not create duplicate objects in S3
**Validates: Requirements 1.3**

### Property 3: Naming convention consistency
*For any* assignment with an image, the S3 object key should follow the format `generated_images/{assignment_id}.webp` where assignment_id matches the MongoDB document
**Validates: Requirements 1.4**

### Property 4: Terraform idempotence
*For any* Terraform configuration, running `terraform apply` multiple times without changes should result in no modifications to the infrastructure
**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

### Property 5: Encryption enforcement
*For any* object uploaded to the S3 bucket, the object should be encrypted at rest using AES-256 server-side encryption
**Validates: Requirements 2.3**

### Property 6: Public access blocked
*For any* attempt to access S3 objects directly via public URL, the request should be denied with a 403 Forbidden error
**Validates: Requirements 2.4**

### Property 7: IAM role permissions
*For any* EC2 instance in the Auto Scaling Group, the attached IAM role should allow PutObject, GetObject, and ListBucket operations on the S3 bucket
**Validates: Requirements 2.5**

### Property 8: Image retrieval latency
*For any* image stored in S3, retrieving it should complete within 2 seconds under normal network conditions (excluding Bedrock generation time)
**Validates: Requirements 3.1**

### Property 9: Missing image graceful handling
*For any* assignment where the S3 image key does not exist in the bucket, the application should display a placeholder message without throwing an exception
**Validates: Requirements 3.3**

### Property 10: CloudFront cache behavior
*For any* image requested multiple times, subsequent requests should be served from CloudFront cache with lower latency than the first request
**Validates: Requirements 4.1, 4.3**

### Property 11: CloudFront TTL enforcement
*For any* image cached in CloudFront, the cached version should be served for at least 24 hours (86400 seconds) before revalidating with S3
**Validates: Requirements 4.2**

### Property 12: S3 direct access restriction
*For any* attempt to access the S3 bucket directly (not through CloudFront), the request should be denied unless it originates from the CloudFront Origin Access Identity
**Validates: Requirements 4.4**

### Property 13: Lifecycle transition to IA
*For any* image stored in S3 Standard, after 90 days the object should be automatically transitioned to S3 Infrequent Access storage class
**Validates: Requirements 5.1**

### Property 14: Lifecycle transition to Glacier
*For any* image in S3 Infrequent Access for 180 days, the object should be automatically transitioned to Glacier storage class
**Validates: Requirements 5.2**

### Property 15: Lifecycle deletion
*For any* image in Glacier for 365 days (and not tagged as "permanent"), the object should be automatically deleted
**Validates: Requirements 5.3**

### Property 16: Image compression effectiveness
*For any* image generated by Bedrock, the optimized version should be at least 30% smaller in file size than the original PNG
**Validates: Requirements 6.1**

### Property 17: Image dimension constraints
*For any* image exceeding 1024x1024 pixels, the optimized version should fit within those dimensions while maintaining the original aspect ratio
**Validates: Requirements 6.2**

### Property 18: Format conversion
*For any* PNG image generated by Bedrock, the optimized version uploaded to S3 should be in WebP format
**Validates: Requirements 6.3**

### Property 19: Optimization fallback
*For any* image where optimization fails, the original image should be uploaded to S3 and a warning should be logged
**Validates: Requirements 6.4**

### Property 20: Load test image operation coverage
*For any* load test execution, the test suite should include scenarios for image generation, S3 upload, and S3 download operations
**Validates: Requirements 7.1**

### Property 21: Concurrent user simulation
*For any* load test run, the system should simulate at least 50 concurrent users performing image-related operations
**Validates: Requirements 7.2**

### Property 22: Load test metrics collection
*For any* load test execution, the system should measure and report p50, p95, and p99 response times for S3 upload and download operations
**Validates: Requirements 7.3, 7.4**

### Property 23: S3 operation logging
*For any* S3 upload or download operation, the system should log the operation with timestamp, user context, assignment ID, and operation result
**Validates: Requirements 8.1**

### Property 24: Upload failure alarm
*For any* 5-minute window where S3 upload failures exceed 5% of total requests, a CloudWatch alarm should trigger
**Validates: Requirements 8.2**

### Property 25: Error message clarity
*For any* S3 operation failure, the user should receive a clear, non-technical error message while detailed errors are logged server-side
**Validates: Requirements 9.1, 9.2, 9.3**

### Property 26: Operation timeout
*For any* S3 operation, if it does not complete within 30 seconds, the operation should be cancelled and the user should be notified
**Validates: Requirements 9.4**

### Property 27: Auto-scaling trigger
*For any* load test that generates high CPU utilization (>70%) due to image processing, the Auto Scaling Group should add instances within 5 minutes
**Validates: Requirements 10.1, 10.2**

### Property 28: Auto-scaling S3 access
*For any* newly launched EC2 instance from auto-scaling, the instance should be able to successfully upload and download images from S3 using the IAM role
**Validates: Requirements 10.4**

### Property 29: High availability during scaling
*For any* auto-scaling event (scale up or down), the image upload and download success rate should remain above 95%
**Validates: Requirements 10.5**

## Error Handling

### S3 Upload Errors

| Error Type | Cause | Handling Strategy |
|------------|-------|-------------------|
| `NoCredentialsError` | IAM role not attached | Log error, display "Configuration error", alert admin |
| `ClientError (403)` | Insufficient permissions | Log specific permission, display "Upload failed", alert admin |
| `ClientError (404)` | Bucket doesn't exist | Log error, display "Storage unavailable", alert admin |
| `ConnectionError` | Network timeout | Retry with exponential backoff (3 attempts), then fail gracefully |
| `BotoCoreError` | SDK error | Log full traceback, display "Upload failed", include correlation ID |

### S3 Download Errors

| Error Type | Cause | Handling Strategy |
|------------|-------|-------------------|
| `NoSuchKey` | Image doesn't exist | Display placeholder image, log warning |
| `ClientError (403)` | Permission denied | Log error, display placeholder, alert admin |
| `ConnectionError` | Network timeout | Retry once, then display placeholder |
| `BotoCoreError` | SDK error | Log error, display placeholder |

### Image Optimization Errors

| Error Type | Cause | Handling Strategy |
|------------|-------|-------------------|
| `PIL.UnidentifiedImageError` | Corrupted image data | Upload original, log warning |
| `OSError` | Insufficient memory | Upload original, log warning, alert admin |
| `ValueError` | Invalid dimensions | Upload original, log warning |

### Retry Strategy

```python
def exponential_backoff_retry(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            return func()
        except RetryableError as e:
            if attempt == max_retries - 1:
                raise
            wait_time = 2 ** attempt  # 1s, 2s, 4s
            time.sleep(wait_time)
```

## Testing Strategy

### Unit Testing

**Framework**: pytest

**Test Coverage**:

1. **S3 Service Tests** (`tests/test_s3_service.py`):
   - Test successful upload with mocked boto3
   - Test upload retry logic
   - Test download with missing key
   - Test IAM permission errors
   - Test timeout handling

2. **Image Optimizer Tests** (`tests/test_image_optimizer.py`):
   - Test PNG to WebP conversion
   - Test image resizing with various aspect ratios
   - Test compression ratio calculation
   - Test optimization failure fallback

3. **Integration Tests** (`tests/test_integration.py`):
   - Test end-to-end assignment creation with image
   - Test image retrieval in Show Assignments page
   - Test MongoDB metadata consistency with S3

### Property-Based Testing

**Framework**: Hypothesis (Python)

**Configuration**: Minimum 100 iterations per property test

**Property Tests**:

1. **Property 1: S3 upload persistence** (`tests/property_tests/test_s3_persistence.py`)
   - Generate random images and assignment IDs
   - Upload to S3, then download
   - Assert downloaded content matches uploaded content

2. **Property 16: Image compression effectiveness** (`tests/property_tests/test_image_optimization.py`)
   - Generate random PNG images of various sizes
   - Optimize each image
   - Assert optimized size is ≤ 70% of original size

3. **Property 17: Image dimension constraints** (`tests/property_tests/test_image_dimensions.py`)
   - Generate random images with dimensions from 512x512 to 2048x2048
   - Optimize each image
   - Assert optimized dimensions ≤ 1024x1024
   - Assert aspect ratio preserved

4. **Property 27: Auto-scaling trigger** (`tests/property_tests/test_autoscaling.py`)
   - Simulate various CPU load patterns
   - Assert scaling occurs within 5 minutes when threshold exceeded
   - Assert instance count increases appropriately

**Property Test Tagging**:
Each property-based test must include a comment with this format:
```python
# Feature: s3-image-storage, Property 1: S3 upload persistence
```

### Load Testing

**Framework**: Locust

**Test Scenarios**:

1. **Baseline Test**: 10 users, 5-minute duration
   - Establish baseline performance metrics
   - Verify no errors under light load

2. **Stress Test**: 50 users, 10-minute duration
   - Test auto-scaling behavior
   - Measure S3 operation latency under load
   - Verify error rates stay below 5%

3. **Spike Test**: Ramp from 10 to 100 users in 2 minutes
   - Test rapid scaling response
   - Verify system stability during scaling

4. **Endurance Test**: 25 users, 60-minute duration
   - Test for memory leaks
   - Verify CloudFront cache effectiveness
   - Monitor S3 costs

**Success Criteria**:
- S3 upload p95 latency < 3 seconds
- S3 download p95 latency < 1 second (with CloudFront)
- Error rate < 5%
- Auto-scaling triggers within 5 minutes
- CloudFront cache hit ratio > 70%

### Manual Testing Checklist

- [ ] Create assignment with image, verify S3 upload
- [ ] View assignment, verify image displays
- [ ] Create assignment without image, verify graceful handling
- [ ] Simulate S3 permission error, verify error message
- [ ] Wait 24 hours, verify CloudFront cache
- [ ] Check CloudWatch dashboard for metrics
- [ ] Verify lifecycle policy transitions (requires waiting 90+ days or manual testing)
- [ ] Test with slow network connection
- [ ] Test with multiple concurrent users

## Implementation Notes

### Terraform Variable Updates

Add to `infrastructure/variables.tf`:
```hcl
variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "education-portal-images"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "image_lifecycle_ia_days" {
  description = "Days before transitioning to Infrequent Access"
  type        = number
  default     = 90
}

variable "image_lifecycle_glacier_days" {
  description = "Days in IA before transitioning to Glacier"
  type        = number
  default     = 180
}

variable "image_lifecycle_expiration_days" {
  description = "Days in Glacier before deletion"
  type        = number
  default     = 365
}
```

### Environment Variables

Add to EC2 user data script:
```bash
export S3_BUCKET_NAME="${s3_bucket_name}"
export CLOUDFRONT_DOMAIN="${cloudfront_domain}"
export AWS_REGION="${aws_region}"
```

### Python Dependencies

Add to `src/requirements.txt`:
```
boto3>=1.28.0
Pillow>=10.0.0
hypothesis>=6.90.0  # For property-based testing
```

### Monitoring Dashboard

Create CloudWatch dashboard with:
- S3 bucket size (GB)
- S3 request count (GET, PUT)
- S3 error rates (4xx, 5xx)
- CloudFront request count
- CloudFront cache hit ratio
- CloudFront error rates
- Average latency for S3 operations

### Cost Optimization

- Use S3 Intelligent-Tiering for automatic cost optimization
- Set CloudFront TTL to 24 hours to reduce S3 requests
- Compress images to WebP to reduce storage and transfer costs
- Use lifecycle policies to archive old images
- Monitor S3 request costs and optimize access patterns

### Security Considerations

- Never expose S3 bucket publicly
- Use IAM roles instead of access keys
- Enable S3 bucket versioning for data protection
- Enable CloudTrail logging for S3 access audit
- Use VPC endpoints for S3 access from EC2 (optional optimization)
- Implement rate limiting on image generation to prevent abuse

### Scalability Considerations

- S3 automatically scales to handle any request volume
- CloudFront provides global scalability
- Consider implementing image generation queue for high load
- Monitor Bedrock API rate limits
- Consider caching generated images by prompt hash to avoid regeneration

## Deployment Plan

1. **Phase 1: Infrastructure** (Terraform)
   - Create S3 bucket with encryption and versioning
   - Create CloudFront distribution
   - Update IAM role with S3 permissions
   - Create CloudWatch alarms and dashboard

2. **Phase 2: Application Code**
   - Implement S3 service module
   - Implement image optimizer module
   - Update Create Assignments page
   - Update Show Assignments page
   - Update Complete Assignments page

3. **Phase 3: Testing**
   - Run unit tests
   - Run property-based tests
   - Run integration tests
   - Execute load tests

4. **Phase 4: Deployment**
   - Apply Terraform changes
   - Deploy application code via GitHub Actions
   - Verify health checks pass
   - Monitor CloudWatch metrics

5. **Phase 5: Validation**
   - Create test assignments with images
   - Verify CloudFront delivery
   - Run load tests against production
   - Monitor for 24 hours

## Rollback Plan

If issues occur:
1. Revert application code via GitHub Actions
2. Keep S3 bucket and CloudFront (no data loss)
3. Update IAM role to remove S3 permissions if needed
4. Investigate issues in staging environment
5. Re-deploy with fixes

## Success Metrics

- 100% of image uploads succeed (or retry successfully)
- Image retrieval latency < 2 seconds (p95)
- CloudFront cache hit ratio > 70%
- Zero public access violations
- Auto-scaling triggers within 5 minutes under load
- Load test error rate < 5%
- Storage costs reduced by 30%+ due to optimization
