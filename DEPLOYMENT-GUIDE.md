# Quick Deployment Guide - S3 Image Storage

## Prerequisites

- AWS CLI configured with credentials
- Terraform installed
- Python 3.11+ with pip
- Locust installed (`pip install locust`)

## Step 1: Deploy Infrastructure (5-10 minutes)

```powershell
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform (first time only)
terraform init

# Review changes
terraform plan

# Apply infrastructure changes
terraform apply
```

**Type `yes` when prompted.**

**What gets created:**
- S3 bucket for images (with encryption, versioning, lifecycle policies)
- CloudFront distribution (takes 15-20 minutes to fully deploy)
- IAM policies for S3 and Bedrock access
- CloudWatch dashboard and alarms
- SNS topic for alerts

## Step 2: Verify Infrastructure

```powershell
# Check outputs
terraform output

# Verify S3 bucket exists
terraform output s3_bucket_name
aws s3 ls s3://$(terraform output -raw s3_bucket_name)

# Verify CloudFront distribution
terraform output cloudfront_domain_name

# Check CloudWatch dashboard
terraform output cloudwatch_dashboard_name
```

## Step 3: Run Load Tests

```powershell
# Navigate to load testing directory
cd ../load-testing

# Install dependencies (if not already installed)
pip install locust requests

# Run baseline test (5 minutes)
.\run-image-load-test.ps1 -TestType baseline
```

**In a separate terminal, monitor metrics:**
```powershell
cd load-testing
.\monitor-image-scaling.ps1
```

## Step 4: Review Results

### Check Load Test Report

```powershell
# Open HTML report
start reports/baseline-image-test.html
```

**Look for:**
- S3 Upload latency (should be < 3s at p95)
- CloudFront Download latency (should be < 1s at p95)
- Error rates (should be < 5%)

### Check CloudWatch Dashboard

```powershell
# Get dashboard URL
$region = "us-east-1"
$dashboard = terraform output -raw cloudwatch_dashboard_name
echo "https://console.aws.amazon.com/cloudwatch/home?region=$region#dashboards:name=$dashboard"
```

**Verify:**
- S3 request metrics are showing
- CloudFront cache hit ratio (may be low initially)
- No alarm states in ALARM status

## Step 5: Run Additional Tests (Optional)

### Stress Test (10 minutes)
Tests auto-scaling with 50 concurrent users:
```powershell
.\run-image-load-test.ps1 -TestType stress
```

### Cache Test (10 minutes)
Tests CloudFront caching performance:
```powershell
.\run-image-load-test.ps1 -TestType cache
```

### Heavy Test (15 minutes)
Triggers auto-scaling with CPU-intensive image generation:
```powershell
.\run-image-load-test.ps1 -TestType heavy
```

### Run All Tests
Executes all test scenarios sequentially:
```powershell
.\run-image-load-test.ps1 -TestType all
```

## Troubleshooting

### Terraform Apply Fails

**Error: "bucket already exists"**
```powershell
# The random suffix should prevent this, but if it happens:
terraform destroy
terraform apply
```

**Error: "insufficient permissions"**
```powershell
# Verify AWS credentials
aws sts get-caller-identity

# Ensure your IAM user has permissions for:
# - S3 (create buckets, policies)
# - CloudFront (create distributions)
# - IAM (create roles, policies)
# - CloudWatch (create dashboards, alarms)
# - SNS (create topics)
```

### Load Test Fails

**Error: "Could not get ALB DNS"**
```powershell
# Manually specify the host
.\run-image-load-test.ps1 -Host "your-alb-dns-name.elb.amazonaws.com" -TestType baseline
```

**Error: "Connection refused"**
```powershell
# Verify ALB is running
cd ../infrastructure
terraform output alb_dns_name

# Test ALB directly
curl http://$(terraform output -raw alb_dns_name)/api/health
```

### CloudFront Not Working

**Distribution still deploying:**
```powershell
# Check distribution status
aws cloudfront get-distribution --id $(terraform output -raw cloudfront_distribution_id) --query 'Distribution.Status'

# Wait for "Deployed" status (15-20 minutes)
```

**Images not loading:**
```powershell
# Verify bucket policy allows CloudFront
aws s3api get-bucket-policy --bucket $(terraform output -raw s3_bucket_name)

# Check CloudFront origin configuration
aws cloudfront get-distribution-config --id $(terraform output -raw cloudfront_distribution_id)
```

### Monitoring Script Errors

**Error: "No data" for all metrics:**
```powershell
# Metrics may take 5-10 minutes to appear
# Run a load test first to generate data
.\run-image-load-test.ps1 -TestType baseline

# Then run monitoring
.\monitor-image-scaling.ps1
```

## Cleanup

To remove all infrastructure:

```powershell
cd infrastructure

# Destroy all resources
terraform destroy
```

**Warning:** This will permanently delete:
- S3 bucket and all images
- CloudFront distribution
- CloudWatch dashboard and alarms
- SNS topic

## Next Steps

After infrastructure is deployed and tested:

1. **Implement Application Code:**
   - Image optimization service
   - S3 upload/download service
   - Update Streamlit pages

2. **Configure SNS Alerts:**
   - Subscribe email to SNS topic for CloudWatch alarms
   - Test alarm notifications

3. **Production Deployment:**
   - Update GitHub Actions with S3 environment variables
   - Deploy application code to EC2 instances
   - Run full integration tests

4. **Monitoring:**
   - Set up CloudWatch log insights
   - Configure custom metrics
   - Create operational runbooks

## Important Notes

- **CloudFront Deployment:** Takes 15-20 minutes to fully deploy globally
- **Lifecycle Policies:** Take effect after specified days (90, 270, 635)
- **Cost:** S3 and CloudFront are pay-per-use; monitor costs in AWS Cost Explorer
- **Security:** S3 bucket has no public access; all access via CloudFront
- **Scaling:** Auto-scaling configured for CPU > 70% (scale up) and < 30% (scale down)

## Support

For issues or questions:
1. Check [IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md) for detailed information
2. Review [load-testing/README.md](load-testing/README.md) for testing guidance
3. Check CloudWatch Logs for application errors
4. Review Terraform state: `terraform show`

## Success Checklist

- [ ] Terraform apply completed successfully
- [ ] S3 bucket created and accessible
- [ ] CloudFront distribution deployed (status: "Deployed")
- [ ] IAM policies attached to EC2 role
- [ ] CloudWatch dashboard visible in AWS Console
- [ ] Baseline load test completed successfully
- [ ] Monitoring script shows metrics
- [ ] No CloudWatch alarms in ALARM state
- [ ] Load test reports generated in `reports/` directory

Once all items are checked, your infrastructure is ready for application integration!
