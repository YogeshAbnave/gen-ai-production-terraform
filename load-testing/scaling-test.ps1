# Optimized load test to trigger auto-scaling
# This script runs progressive load tests to demonstrate scaling

param(
    [string]$ALB_URL = ""
)

if (-not $ALB_URL) {
    Write-Host "Getting ALB URL from Terraform outputs..." -ForegroundColor Yellow
    $ALB_URL = terraform -chdir=../terraform output -raw alb_dns_name
    if (-not $ALB_URL) {
        Write-Host "Error: Could not get ALB URL. Please provide it as parameter." -ForegroundColor Red
        Write-Host "Usage: .\scaling-test.ps1 -ALB_URL 'http://your-alb-url.amazonaws.com'" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auto-Scaling Load Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: $ALB_URL" -ForegroundColor White
Write-Host ""

# Test 1: Light load (should NOT scale)
Write-Host "Test 1: Light Load (Baseline)" -ForegroundColor Green
Write-Host "  Users: 50 | Ramp-up: 5/sec | Duration: 2 min" -ForegroundColor Gray
Write-Host "  Expected: No scaling (stays at 2 instances)" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to start Test 1"

locust -f locustfile.py `
    --host=$ALB_URL `
    --users=50 `
    --spawn-rate=5 `
    --run-time=2m `
    --headless `
    --html=reports/test1-light-load.html

Write-Host ""
Write-Host "Test 1 complete. Check metrics with: .\check-scaling-metrics.ps1" -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Test 2: Medium load (should trigger scaling)
Write-Host ""
Write-Host "Test 2: Medium Load (Trigger Scaling)" -ForegroundColor Green
Write-Host "  Users: 200 | Ramp-up: 20/sec | Duration: 5 min" -ForegroundColor Gray
Write-Host "  Expected: Scale to 4 instances within 2-3 minutes" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to start Test 2"

locust -f locustfile.py `
    --host=$ALB_URL `
    --users=200 `
    --spawn-rate=20 `
    --run-time=5m `
    --headless `
    --html=reports/test2-medium-load.html

Write-Host ""
Write-Host "Test 2 complete. Scaling should be in progress." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Test 3: Heavy load (should scale to max)
Write-Host ""
Write-Host "Test 3: Heavy Load (Max Scaling)" -ForegroundColor Green
Write-Host "  Users: 500 | Ramp-up: 50/sec | Duration: 5 min" -ForegroundColor Gray
Write-Host "  Expected: Scale to 6-10 instances" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to start Test 3"

locust -f locustfile.py `
    --host=$ALB_URL `
    --users=500 `
    --spawn-rate=50 `
    --run-time=5m `
    --headless `
    --html=reports/test3-heavy-load.html

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All tests complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check results:" -ForegroundColor Yellow
Write-Host "  1. Run: .\check-scaling-metrics.ps1" -ForegroundColor White
Write-Host "  2. Run: .\monitor-scaling.ps1" -ForegroundColor White
Write-Host "  3. View HTML reports in: load-testing/reports/" -ForegroundColor White
Write-Host ""
