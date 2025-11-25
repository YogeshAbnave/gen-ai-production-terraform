# Quick validation test before full load testing
# Verifies ALB and instances are responding correctly

$ALB_URL = "http://crud-app-alb-263940571.ap-south-1.elb.amazonaws.com"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick ALB Validation Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic connectivity
Write-Host "Test 1: Checking ALB connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$ALB_URL/api/items" -Method GET -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] ALB is responding (Status: $($response.StatusCode))" -ForegroundColor Green
    }
} catch {
    Write-Host "[FAIL] ALB is not responding: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Multiple requests to check distribution
Write-Host "Test 2: Testing load distribution (10 requests)..." -ForegroundColor Yellow
$responses = @()
for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$ALB_URL/api/items" -Method GET -TimeoutSec 10
        $responses += $response.StatusCode
        Write-Host "  Request $i : Status $($response.StatusCode)" -ForegroundColor Gray
    } catch {
        Write-Host "  Request $i : Failed" -ForegroundColor Red
    }
}
$successRate = ($responses | Where-Object { $_ -eq 200 }).Count / $responses.Count * 100
Write-Host "[OK] Success Rate: $successRate%" -ForegroundColor Green
Write-Host ""

# Test 3: Create operation
Write-Host "Test 3: Testing CREATE operation..." -ForegroundColor Yellow
$testItem = @{
    id = [guid]::NewGuid().ToString()
    name = "test-item"
    description = "Quick validation test"
} | ConvertTo-Json

try {
    $response = Invoke-WebRequest -Uri "$ALB_URL/api/items" -Method POST -Body $testItem -ContentType "application/json" -TimeoutSec 10
    Write-Host "[OK] CREATE successful (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] CREATE failed: $_" -ForegroundColor Red
}
Write-Host ""

# Test 4: Check target health
Write-Host "Test 4: Checking target group health..." -ForegroundColor Yellow
try {
    $tgArn = aws elbv2 describe-target-groups --names "crud-app-tg" --query 'TargetGroups[0].TargetGroupArn' --output text
    $targets = aws elbv2 describe-target-health --target-group-arn $tgArn | ConvertFrom-Json
    
    $healthy = ($targets.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
    $total = $targets.TargetHealthDescriptions.Count
    
    Write-Host "  Healthy targets: $healthy / $total" -ForegroundColor Green
    
    if ($healthy -eq 0) {
        Write-Host "[FAIL] No healthy targets! Check your instances." -ForegroundColor Red
    } else {
        Write-Host "[OK] Target group has healthy instances" -ForegroundColor Green
    }
} catch {
    Write-Host "[FAIL] Could not check target health: $_" -ForegroundColor Red
}
Write-Host ""

# Test 5: Check ASG status
Write-Host "Test 5: Checking Auto Scaling Group..." -ForegroundColor Yellow
try {
    $asg = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "crud-app-asg" --query 'AutoScalingGroups[0]' | ConvertFrom-Json
    
    Write-Host "  Min: $($asg.MinSize) | Desired: $($asg.DesiredCapacity) | Current: $($asg.Instances.Count) | Max: $($asg.MaxSize)" -ForegroundColor White
    
    if ($asg.Instances.Count -ge $asg.MinSize) {
        Write-Host "[OK] ASG has sufficient instances" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] ASG instance count below minimum" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Could not check ASG: $_" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Validation Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If all tests passed, you are ready to run load tests:" -ForegroundColor Green
Write-Host "  .\run-load-test.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "To monitor during load testing:" -ForegroundColor Green
Write-Host "  .\monitor-scaling.ps1" -ForegroundColor Yellow
Write-Host ""
