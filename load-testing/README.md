# Load Testing Guide for ALB, Auto Scaling, and Image Operations

This directory contains scripts to test your Application Load Balancer, Auto Scaling Group, S3 image storage, and CloudFront CDN performance.

## Quick Start

### 1. Install Locust (if not already installed)

```powershell
pip install locust
```

Verify installation:
```powershell
locust --version
```

### 2. Run Load Test

**Option A: Using the PowerShell script (Recommended)**

```powershell
cd load-testing
.\run-load-test.ps1
```

**Option B: Manual Locust command**

```powershell
cd load-testing
locust -f locustfile.py --host=http://crud-app-alb-1488561427.us-east-1.elb.amazonaws.com
```

Then open browser: http://localhost:8089

### 3. Monitor Scaling (in separate terminal)

```powershell
cd load-testing
.\monitor-scaling.ps1
```

## Test Scenarios

### Scenario 1: Balanced Load (Default)
Tests all CRUD operations with realistic distribution.

```powershell
.\run-load-test.ps1 -Users 200 -SpawnRate 10 -TestType "balanced"
```

### Scenario 2: Read-Heavy Load
Tests ALB distribution with mostly GET requests.

```powershell
.\run-load-test.ps1 -Users 500 -SpawnRate 20 -TestType "read-heavy"
```

### Scenario 3: Write-Heavy Load
Tests Auto Scaling with CPU-intensive write operations.

```powershell
.\run-load-test.ps1 -Users 300 -SpawnRate 15 -TestType "write-heavy"
```

### Scenario 4: Spike Test
Simulates sudden traffic spike.

```powershell
.\run-load-test.ps1 -Users 1000 -SpawnRate 100 -TestType "balanced"
```

## What to Monitor

### In Locust Web UI (http://localhost:8089)
- ✅ Total Requests Per Second (RPS)
- ✅ Response Times (median, 95th percentile)
- ✅ Failure Rate
- ✅ Number of Users

### In Monitor Script
- ✅ ASG Desired Capacity changes
- ✅ Number of healthy instances
- ✅ Scaling activities (launch/terminate)
- ✅ CloudWatch alarm states
- ✅ Target group health

### In AWS Console

**Auto Scaling Group:**
- EC2 → Auto Scaling Groups → crud-app-asg
- Check "Activity" tab for scaling events
- Check "Monitoring" tab for metrics

**Load Balancer:**
- EC2 → Load Balancers → crud-app-alb
- Check "Target groups" → crud-app-tg → "Targets" tab
- Check "Monitoring" tab for request metrics

**CloudWatch:**
- CloudWatch → Alarms
  - crud-app-high-cpu (should trigger at 70% CPU)
  - crud-app-low-cpu (should trigger at 30% CPU)
- CloudWatch → Metrics → EC2 → By Auto Scaling Group
  - CPUUtilization
  - NetworkIn/NetworkOut

## Expected Behavior

### Load Balancer
1. ✅ Distributes traffic evenly across healthy instances
2. ✅ Removes unhealthy instances from rotation
3. ✅ Health checks pass (200 OK on /)
4. ✅ No 5xx errors under normal load

### Auto Scaling
1. ✅ Maintains minimum 2 instances
2. ✅ Scales up when CPU > 70% for 2 evaluation periods (4 minutes)
3. ✅ Scales down when CPU < 30% for 2 evaluation periods (4 minutes)
4. ✅ New instances register with target group automatically
5. ✅ Respects cooldown period (300 seconds)

## Troubleshooting

### No scaling happening?
- Check CloudWatch alarms are in "ALARM" state
- Verify CPU threshold is being exceeded
- Wait for evaluation periods (4 minutes)
- Check ASG activity history for errors

### High failure rate in Locust?
- Check target group health in AWS Console
- Verify instances are healthy
- Check application logs in CloudWatch
- Verify DynamoDB table is accessible

### Instances not registering with ALB?
- Check security group rules
- Verify health check path returns 200
- Check instance is in correct subnets
- Wait for health check grace period (300 seconds)

## Advanced Testing

### Test Instance Failure
1. Start load test with 200 users
2. Manually terminate one EC2 instance
3. Watch ASG launch replacement
4. Verify no service disruption

### Test Manual Scaling
```powershell
# Scale up manually
aws autoscaling set-desired-capacity --auto-scaling-group-name crud-app-asg --desired-capacity 3

# Watch new instance launch and register
.\monitor-scaling.ps1
```

### Test Health Check Failure
1. SSH into an instance
2. Stop the application service
3. Watch ALB mark it unhealthy
4. Verify traffic routes to healthy instances

## Cleanup

Stop load test:
- Press Ctrl+C in Locust terminal
- Or click "Stop" in web UI

Stop monitoring:
- Press Ctrl+C in monitor terminal

## Image Operations Load Testing

### NEW: Test S3 Upload, CloudFront Caching, and Image Processing

The education portal now includes AI-generated images stored in S3 and delivered via CloudFront. Use these tests to validate image operations under load.

#### Quick Start - Image Tests

```powershell
cd load-testing
.\run-image-load-test.ps1 -TestType baseline
```

#### Image Test Scenarios

**Baseline Test** (Recommended first)
```powershell
.\run-image-load-test.ps1 -TestType baseline
```
- 10 users, 5 minutes
- Establishes baseline S3 upload/download latency
- Measures CloudFront cache performance

**Stress Test** (Test auto-scaling)
```powershell
.\run-image-load-test.ps1 -TestType stress -Users 50 -Duration 10m
```
- 50 concurrent users creating assignments with images
- Tests S3 upload performance under load
- Validates auto-scaling triggers from image processing CPU load

**Cache Test** (Test CloudFront)
```powershell
.\run-image-load-test.ps1 -TestType cache
```
- 30 users repeatedly requesting same images
- Validates CloudFront cache hit ratio > 70%
- Measures cache vs origin latency difference

**Heavy Test** (Trigger auto-scaling)
```powershell
.\run-image-load-test.ps1 -TestType heavy
```
- 20 users generating multiple images rapidly
- CPU-intensive image generation and optimization
- Forces auto-scaling to add instances

**Run All Tests**
```powershell
.\run-image-load-test.ps1 -TestType all
```
- Runs all test scenarios sequentially
- Generates comprehensive performance report

#### Monitor Image Operations

Run in separate terminal while load testing:
```powershell
.\monitor-image-scaling.ps1
```

Displays real-time metrics:
- S3 request count and error rates
- CloudFront cache hit ratio
- EC2 CPU utilization
- Auto Scaling Group status
- CloudWatch alarm states

#### Expected Performance Metrics

**S3 Upload:**
- p50 latency: < 1.5 seconds
- p95 latency: < 3 seconds
- p99 latency: < 5 seconds
- Error rate: < 5%

**CloudFront Download:**
- p50 latency: < 500ms (cached)
- p95 latency: < 1 second
- Cache hit ratio: > 70%
- Error rate: < 1%

**Auto-Scaling:**
- Scale-up trigger: CPU > 70% for 1 minute
- Scale-up time: < 5 minutes
- Scale-down trigger: CPU < 30% for 2 minutes
- Availability during scaling: > 95%

#### Image Test Files

- `image_operations.py` - Image-specific load test scenarios
- `run-image-load-test.ps1` - Image test launcher with multiple scenarios
- `monitor-image-scaling.ps1` - Real-time monitoring for S3/CloudFront metrics

#### Troubleshooting Image Tests

**High S3 upload latency?**
- Check IAM role permissions on EC2 instances
- Verify S3 bucket is in same region as EC2
- Check network connectivity to S3 endpoints
- Review CloudWatch S3 metrics for throttling

**Low CloudFront cache hit ratio?**
- Verify TTL is set to 24 hours (86400 seconds)
- Check if images have unique URLs (assignment IDs)
- Wait 5-10 minutes for cache to warm up
- Review CloudFront distribution settings

**Image upload failures?**
- Check S3 bucket policy allows EC2 IAM role
- Verify Bedrock permissions for image generation
- Check application logs for specific errors
- Review CloudWatch alarms for S3 errors

**Auto-scaling not triggered?**
- Image generation is CPU-intensive, should trigger scaling
- Use "heavy" test type for faster scaling
- Check CloudWatch CPU metrics
- Verify alarm thresholds are appropriate

## Files

- `locustfile.py` - CRUD operations load testing
- `image_operations.py` - Image operations load testing (NEW)
- `run-load-test.ps1` - CRUD test launcher
- `run-image-load-test.ps1` - Image test launcher (NEW)
- `monitor-scaling.ps1` - Real-time ASG monitoring
- `monitor-image-scaling.ps1` - Real-time S3/CloudFront monitoring (NEW)
- `README.md` - This file

## Tips

1. Start with low user count (100-200) and increase gradually
2. Run monitoring script in separate terminal for real-time feedback
3. Wait 5-10 minutes for Auto Scaling to react
4. Check CloudWatch alarms to confirm thresholds are being hit
5. Use write-heavy test to trigger CPU-based scaling faster

## Your ALB URL

```
http://crud-app-alb-263940571.us-east-1.elb.amazonaws.com
```

Test it's working:
```powershell
curl http://crud-app-alb-263940571.us-east-1.elb.amazonaws.com/items
```
