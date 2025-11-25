# Auto-Scaling Load Test Guide

## Quick Answer: Recommended Settings

### To Trigger Scaling (After applying new config):

| Test Type | Users | Ramp-up Rate | Duration | Expected Result |
|-----------|-------|--------------|----------|-----------------|
| **Baseline** | 50 | 5/sec | 2 min | No scaling (2 instances) |
| **Light Scaling** | 150-200 | 15-20/sec | 3-5 min | Scale to 4 instances |
| **Medium Scaling** | 300-400 | 30-40/sec | 5 min | Scale to 6-8 instances |
| **Max Scaling** | 500+ | 50/sec | 5-10 min | Scale to 10 instances (max) |

## Current Scaling Configuration

### CPU-Based Scaling
- **Threshold:** 40% CPU average
- **Evaluation:** 1 period × 60 seconds = 1 minute
- **Action:** Add 2 instances
- **Cooldown:** 180 seconds (3 minutes)

### ALB-Based Scaling (New!)
- **Threshold:** 1000 requests per target per minute
- **Type:** Target tracking (automatic)
- **Target Value:** Maintains ~1000 req/min per instance

## Why Your Previous Test Didn't Scale

With **1500 users** and **10/sec ramp-up**:
- Ramp-up took: 1500 ÷ 10 = **150 seconds** (2.5 minutes)
- Your CRUD app is **I/O bound** (DynamoDB), not CPU-intensive
- CPU probably stayed around 20-30%, below the old 70% threshold
- Wait time of 1-3 seconds between requests = low sustained load

## How to Trigger Scaling Reliably

### Option 1: Use the Progressive Test Script (Recommended)
```powershell
cd terraform-crud/load-testing
.\scaling-test.ps1
```

This runs 3 progressive tests to demonstrate scaling.

### Option 2: Quick Single Test
```powershell
# Get your ALB URL
cd terraform-crud/terraform
$ALB_URL = terraform output -raw alb_dns_name

# Run aggressive test
cd ../load-testing
locust -f locustfile.py `
    --host=http://$ALB_URL `
    --users=300 `
    --spawn-rate=30 `
    --run-time=5m `
    --headless
```

### Option 3: Use Write-Heavy Load (More CPU intensive)
```powershell
# This uses WriteHeavyUser class which generates more CPU load
locust -f locustfile.py `
    --host=http://$ALB_URL `
    --users=200 `
    --spawn-rate=25 `
    --run-time=5m `
    --headless `
    WriteHeavyUser
```

## Monitoring Scaling in Real-Time

### Terminal 1: Run Load Test
```powershell
cd terraform-crud/load-testing
locust -f locustfile.py --host=http://YOUR-ALB-URL --users=300 --spawn-rate=30 --run-time=5m --headless
```

### Terminal 2: Monitor Scaling
```powershell
cd terraform-crud/load-testing
.\monitor-scaling.ps1
```

### Terminal 3: Check Metrics
```powershell
cd terraform-crud/load-testing
.\check-scaling-metrics.ps1
```

## Understanding the Math

### Request-Based Scaling
- **2 instances** handling **2000 req/min** = 1000 req/min per instance ✅ **Triggers scaling**
- **300 users** × **~4 requests/min** (with 1-3 sec wait) = **~1200 req/min total**
- **1200 req/min ÷ 2 instances** = **600 req/min per instance** (below threshold)

To hit 1000 req/min per instance with 2 instances:
- Need: **2000+ requests/min total**
- With 1-3 sec wait time: Need **~500+ concurrent users**

### CPU-Based Scaling
- Your FastAPI app with DynamoDB is lightweight
- Each request uses ~5-10% CPU for ~50ms
- To sustain 40% CPU: Need **continuous high request rate**
- **200+ users** with **low wait time** (0.5-1 sec) should trigger it

## Recommended Test Strategy

### Step 1: Apply Terraform Changes
```powershell
cd terraform-crud/terraform
terraform apply
```

### Step 2: Wait for Instances to be Healthy
```powershell
cd ../load-testing
.\check-scaling-metrics.ps1
```

### Step 3: Run Progressive Load Test
```powershell
.\scaling-test.ps1
```

### Step 4: Watch Scaling Happen
- Scaling should trigger within **1-2 minutes** of sustained load
- New instances take **3-5 minutes** to launch and become healthy
- Total time to scale: **4-7 minutes**

## Troubleshooting

### If Still Not Scaling After Changes:

1. **Check if Terraform applied:**
   ```powershell
   cd terraform-crud/terraform
   terraform show | Select-String -Pattern "threshold|max_size"
   ```

2. **Verify alarm configuration:**
   ```powershell
   aws cloudwatch describe-alarms --alarm-names "crud-app-high-cpu"
   ```

3. **Check actual CPU usage:**
   ```powershell
   cd ../load-testing
   .\check-scaling-metrics.ps1
   ```

4. **Try CPU-intensive load:**
   ```powershell
   # Use WriteHeavyUser with larger payloads
   locust -f locustfile.py --host=http://YOUR-ALB-URL --users=200 --spawn-rate=25 --run-time=5m --headless WriteHeavyUser
   ```

## Expected Timeline

```
0:00 - Start load test (300 users, 30/sec ramp)
0:10 - All users ramped up
0:30 - CPU/Request metrics accumulate
1:00 - CloudWatch alarm triggers (1 min evaluation)
1:05 - ASG receives scale-up signal
1:10 - New instances launching
4:00 - New instances healthy and receiving traffic
4:30 - Load distributed across 4 instances
```

## Cost Note

Running at max capacity (10 instances) costs approximately:
- **t2.micro:** ~$0.10/hour = $0.80 for 8 hours
- **t3.small:** ~$0.20/hour = $1.60 for 8 hours

Remember to scale down or destroy resources after testing!
