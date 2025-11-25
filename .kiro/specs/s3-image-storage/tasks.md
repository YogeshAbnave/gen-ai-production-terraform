# Implementation Plan: S3 Image Storage Infrastructure

## Task Overview

This implementation plan breaks down the S3 image storage feature into discrete, manageable coding tasks. Each task builds incrementally on previous work, ensuring the system remains functional throughout development.

---

## Tasks

- [x] 1. Create Terraform S3 bucket infrastructure


  - Create `infrastructure/s3.tf` with S3 bucket resource
  - Configure bucket with versioning, encryption (AES-256), and public access block
  - Add lifecycle policies for transitioning to IA (90 days), Glacier (270 days), and deletion (635 days)
  - Configure CORS rules for web access
  - Add bucket name output to `infrastructure/outputs.tf`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 5.1, 5.2, 5.3_

- [x] 2. Create Terraform CloudFront distribution


  - Create `infrastructure/cloudfront.tf` with CloudFront distribution resource
  - Configure Origin Access Identity for secure S3 access
  - Set cache behavior with TTL of 86400 seconds (24 hours)
  - Configure price class and SSL certificate
  - Add CloudFront domain output to `infrastructure/outputs.tf`
  - Update S3 bucket policy to restrict access to CloudFront only
  - _Requirements: 4.1, 4.2, 4.4, 4.5_



- [ ] 3. Update IAM role with S3 permissions
  - Modify `infrastructure/iam.tf` to add S3 policy to existing EC2 role
  - Grant permissions: s3:PutObject, s3:GetObject, s3:DeleteObject, s3:ListBucket
  - Scope permissions to the specific S3 bucket ARN
  - Add Bedrock permissions for image generation (bedrock:InvokeModel)


  - _Requirements: 2.5_

- [ ] 4. Create CloudWatch monitoring infrastructure
  - Create `infrastructure/monitoring.tf` with CloudWatch dashboard
  - Add dashboard widgets for S3 metrics (bucket size, request count, error rates)
  - Add dashboard widgets for CloudFront metrics (cache hit ratio, request count)
  - Create CloudWatch alarm for S3 upload failure rate > 5%


  - Create CloudWatch alarm for CloudFront cache hit ratio < 70%
  - Create CloudWatch alarm for S3 bucket size > 80% quota
  - _Requirements: 8.2, 8.3, 8.4, 8.5_

- [ ] 5. Update Terraform variables and apply infrastructure
  - Add S3 and CloudFront variables to `infrastructure/variables.tf`
  - Update `infrastructure/scripts/user_data.sh` to export S3_BUCKET_NAME and CLOUDFRONT_DOMAIN
  - Run `terraform init` and `terraform plan` to validate configuration
  - Apply Terraform changes to provision S3, CloudFront, IAM, and monitoring
  - Verify outputs for bucket name and CloudFront domain
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 4.1, 4.5_

- [ ] 6. Checkpoint - Verify infrastructure deployment
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Create image optimization service
  - Create `src/services/image_optimizer.py` module
  - Implement `ImageOptimizer` class with `optimize()` method
  - Add PNG to WebP conversion using Pillow
  - Implement image resizing to max 1024x1024 while preserving aspect ratio
  - Add compression with quality=85 to achieve 30%+ size reduction
  - Implement `calculate_compression_ratio()` method
  - Add error handling with fallback to original image
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ]* 7.1 Write property test for image compression
  - **Property 16: Image compression effectiveness**
  - **Validates: Requirements 6.1**

- [ ]* 7.2 Write property test for image dimension constraints
  - **Property 17: Image dimension constraints**
  - **Validates: Requirements 6.2**

- [ ]* 7.3 Write property test for format conversion
  - **Property 18: Format conversion**
  - **Validates: Requirements 6.3**

- [ ]* 7.4 Write property test for optimization fallback
  - **Property 19: Optimization fallback**
  - **Validates: Requirements 6.4**

- [ ] 8. Create S3 service module
  - Create `src/services/s3_service.py` module
  - Implement `S3ImageService` class with boto3 S3 client
  - Implement `upload_image()` method with retry logic (3 attempts, exponential backoff)
  - Implement `download_image()` method with error handling
  - Implement `delete_image()` method
  - Implement `get_image_url()` method to return CloudFront URL
  - Add correlation ID generation for error tracking
  - Add comprehensive logging for all S3 operations
  - Set appropriate S3 object metadata (Content-Type, Cache-Control, custom metadata)
  - _Requirements: 1.1, 1.3, 3.1, 3.2, 6.5, 8.1, 9.1, 9.3, 9.4, 9.5_

- [ ]* 8.1 Write property test for S3 upload persistence
  - **Property 1: S3 upload persistence**
  - **Validates: Requirements 1.1, 1.2**

- [ ]* 8.2 Write property test for upload retry idempotence
  - **Property 2: Upload retry idempotence**
  - **Validates: Requirements 1.3**

- [ ]* 8.3 Write property test for naming convention consistency
  - **Property 3: Naming convention consistency**
  - **Validates: Requirements 1.4**

- [ ]* 8.4 Write unit tests for S3 service error handling
  - Test network timeout handling
  - Test IAM permission errors
  - Test missing bucket errors
  - Test correlation ID generation
  - _Requirements: 9.1, 9.3, 9.4, 9.5_

- [ ] 9. Update Parameter_store.py configuration
  - Modify `src/components/Parameter_store.py` to read S3_BUCKET_NAME from environment
  - Add CLOUDFRONT_DOMAIN environment variable
  - Add AWS_REGION environment variable with default
  - Remove hardcoded bucket name "mcq-project"
  - _Requirements: 1.1, 4.5_

- [ ] 10. Update Create Assignments page with S3 integration
  - Modify `src/pages/1_Create_Assignments.py` to import S3ImageService and ImageOptimizer
  - Replace local file save with S3 upload workflow
  - Add image optimization before upload
  - Update MongoDB record to store s3_image_key, cloudfront_url, and image_metadata
  - Add retry logic for S3 upload failures
  - Update UI to show upload progress and status
  - Add error handling with user-friendly messages
  - Store "no_image" sentinel when image generation is skipped
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.1, 6.2, 6.3, 9.1_

- [ ]* 10.1 Write integration test for assignment creation with image
  - Test end-to-end flow: generate image → optimize → upload to S3 → save to MongoDB
  - Verify MongoDB contains correct S3 key and metadata
  - _Requirements: 1.1, 1.2, 1.4_

- [ ] 11. Update Show Assignments page with S3 retrieval
  - Modify `src/pages/2_Show_Assignments.py` to use S3ImageService
  - Replace S3 download with CloudFront URL retrieval
  - Implement local caching to avoid repeated downloads
  - Add placeholder image display when S3 key is missing or download fails
  - Add error handling for missing images
  - Update UI to show loading state during image retrieval
  - _Requirements: 3.1, 3.3, 3.4, 9.2_

- [ ]* 11.1 Write property test for missing image graceful handling
  - **Property 9: Missing image graceful handling**
  - **Validates: Requirements 3.3**

- [ ] 12. Update Complete Assignments page with S3 retrieval
  - Modify `src/pages/3_Complete_Assignments.py` to use S3ImageService
  - Replace S3 download with CloudFront URL retrieval
  - Implement local caching for images
  - Add placeholder image display for missing images


  - Add error handling with user-friendly messages
  - _Requirements: 3.1, 3.3, 3.4, 9.2_

- [ ] 13. Checkpoint - Verify application functionality
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. Create load testing scenarios for image operations
  - Create `load-testing/image_operations.py` with Locust test classes
  - Implement `ImageLoadTest` class with image creation and retrieval tasks


  - Add task for creating assignments with images (weight: 3)
  - Add task for viewing assignments with images (weight: 5)
  - Add task for listing assignments without images (weight: 1)
  - Configure test for 50 concurrent users with 5 users/second spawn rate
  - Add metrics collection for S3 upload/download latency (p50, p95, p99)
  - Add metrics collection for error rates




  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 15. Create load testing execution scripts
  - Create `load-testing/run-image-load-test.ps1` PowerShell script
  - Add commands to start Locust with image_operations.py
  - Add parameters for user count, spawn rate, and duration
  - Create `load-testing/monitor-image-scaling.ps1` to monitor auto-scaling during tests
  - Add CloudWatch metrics queries for S3 and CloudFront
  - _Requirements: 7.1, 7.2, 10.1_

- [ ] 16. Update load testing documentation
  - Update `load-testing/README.md` with image operation test scenarios
  - Add instructions for running image-specific load tests
  - Document expected performance metrics (S3 upload p95 < 3s, download p95 < 1s)
  - Add troubleshooting section for common issues
  - Document auto-scaling validation steps
  - _Requirements: 7.5, 10.1, 10.2_

- [ ]* 16.1 Write property test for auto-scaling trigger
  - **Property 27: Auto-scaling trigger**
  - **Validates: Requirements 10.1, 10.2**

- [ ]* 16.2 Write property test for auto-scaling S3 access
  - **Property 28: Auto-scaling S3 access**
  - **Validates: Requirements 10.4**

- [ ] 17. Update application requirements.txt
  - Add Pillow>=10.0.0 for image optimization
  - Add hypothesis>=6.90.0 for property-based testing
  - Verify boto3>=1.28.0 is present
  - Update any other dependencies as needed
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 18. Update deployment scripts
  - Modify `scripts/deploy.ps1` to apply Terraform changes for S3 and CloudFront
  - Update GitHub Actions workflow to include S3 bucket name in environment variables
  - Add validation step to verify S3 bucket and CloudFront distribution exist
  - Update `scripts/check-infrastructure.ps1` to check S3 and CloudFront resources
  - _Requirements: 2.1, 4.1_

- [ ] 19. Update project documentation
  - Update main `README.md` with S3 and CloudFront architecture
  - Add section on image storage and optimization
  - Document environment variables (S3_BUCKET_NAME, CLOUDFRONT_DOMAIN)
  - Add troubleshooting section for S3 and CloudFront issues
  - Update architecture diagram to include S3 and CloudFront
  - _Requirements: 2.1, 4.1_

- [ ] 20. Final checkpoint - Run comprehensive tests
  - Run all unit tests
  - Run all property-based tests
  - Run integration tests
  - Execute baseline load test (10 users, 5 minutes)
  - Execute stress load test (50 users, 10 minutes)
  - Verify auto-scaling behavior
  - Verify CloudWatch alarms are configured
  - Verify CloudWatch dashboard displays metrics
  - Check S3 bucket for uploaded images
  - Verify CloudFront cache hit ratio > 70%
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional testing tasks that can be skipped for faster MVP delivery
- Each task should be completed and verified before moving to the next
- Terraform changes should be applied and tested in a development environment first
- Load testing should be performed against a staging environment before production
- Monitor CloudWatch metrics during and after deployment to ensure system health
- Keep the existing DynamoDB and MongoDB functionality intact while adding S3 integration
