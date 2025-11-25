# PowerShell script to run image-specific load tests
# Tests S3 upload, CloudFront caching, and auto-scaling behavior

param(
    [Parameter(Mandatory=$false)]
    [string]$Host = "",
    
    [Parameter(Mandatory=$false)]
    [int]$Users = 50,
    
    [Parameter(Mandatory=$false)]
    [int]$SpawnRate = 5,
    
    [Parameter(Mandatory=$false)]
    [string]$Duration = "10m",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("baseline", "stress", "cache", "heavy", "all")]
    [string]$TestType = "baseline"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Image Operations Load Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get ALB DNS if not provided
if ([string]::IsNullOrEmpty($Host)) {
    Write-Host "Getting ALB DNS from Terraform..." -ForegroundColor Yellow
    Push-Location ../infrastructure
    $Host = terraform output -raw alb_dns_name 2>$null
    Pop-Location
    
    if ([string]::IsNullOrEmpty($Host)) {
        Write-Host "Error: Could not get ALB DNS. Please provide -Host parameter" -ForegroundColor Red
        exit 1
    }
}

$HostUrl = "http://$Host"
Write-Host "Target Host: $HostUrl" -ForegroundColor Green
Write-Host ""

# Check if locust is installed
$locustInstalled = Get-Command locust -ErrorAction SilentlyContinue
if (-not $locustInstalled) {
    Write-Host "Error: Locust is not installed" -ForegroundColor Red
    Write-Host "Install with: pip install locust" -ForegroundColor Yellow
    exit 1
}

# Test scenarios
switch ($TestType) {
    "baseline" {
        Write-Host "Running BASELINE test..." -ForegroundColor Cyan
        Write-Host "  Users: 10" -ForegroundColor Gray
        Write-Host "  Spawn Rate: 2/sec" -ForegroundColor Gray
        Write-Host "  Duration: 5 minutes" -ForegroundColor Gray
        Write-Host "  Purpose: Establish baseline performance metrics" -ForegroundColor Gray
        Write-Host ""
        
        locust -f image_operations.py `
            --host=$HostUrl `
            --users=10 `
            --spawn-rate=2 `
            --run-time=5m `
            --headless `
            --html=reports/baseline-image-test.html `
            --csv=reports/baseline-image-test
    }
    
    "stress" {
        Write-Host "Running STRESS test..." -ForegroundColor Cyan
        Write-Host "  Users: $Users" -ForegroundColor Gray
        Write-Host "  Spawn Rate: $SpawnRate/sec" -ForegroundColor Gray
        Write-Host "  Duration: $Duration" -ForegroundColor Gray
        Write-Host "  Purpose: Test auto-scaling and S3 performance under load" -ForegroundColor Gray
        Write-Host ""
        
        locust -f image_operations.py `
            --host=$HostUrl `
            --users=$Users `
            --spawn-rate=$SpawnRate `
            --run-time=$Duration `
            --headless `
            --html=reports/stress-image-test.html `
            --csv=reports/stress-image-test
    }
    
    "cache" {
        Write-Host "Running CACHE test..." -ForegroundColor Cyan
        Write-Host "  Users: 30" -ForegroundColor Gray
        Write-Host "  Spawn Rate: 5/sec" -ForegroundColor Gray
        Write-Host "  Duration: 10 minutes" -ForegroundColor Gray
        Write-Host "  Purpose: Test CloudFront cache hit ratio" -ForegroundColor Gray
        Write-Host "  User Class: CacheTestUser" -ForegroundColor Gray
        Write-Host ""
        
        locust -f image_operations.py `
            --host=$HostUrl `
            --users=30 `
            --spawn-rate=5 `
            --run-time=10m `
            --headless `
            --user-classes=CacheTestUser `
            --html=reports/cache-test.html `
            --csv=reports/cache-test
    }
    
    "heavy" {
        Write-Host "Running HEAVY test..." -ForegroundColor Cyan
        Write-Host "  Users: 20" -ForegroundColor Gray
        Write-Host "  Spawn Rate: 3/sec" -ForegroundColor Gray
        Write-Host "  Duration: 15 minutes" -ForegroundColor Gray
        Write-Host "  Purpose: Trigger auto-scaling with CPU-intensive image generation" -ForegroundColor Gray
        Write-Host "  User Class: ImageHeavyUser" -ForegroundColor Gray
        Write-Host ""
        
        locust -f image_operations.py `
            --host=$HostUrl `
            --users=20 `
            --spawn-rate=3 `
            --run-time=15m `
            --headless `
            --user-classes=ImageHeavyUser `
            --html=reports/heavy-image-test.html `
            --csv=reports/heavy-image-test
    }
    
    "all" {
        Write-Host "Running ALL test scenarios sequentially..." -ForegroundColor Cyan
        Write-Host ""
        
        # Baseline
        Write-Host "[1/4] Baseline Test" -ForegroundColor Yellow
        & $PSCommandPath -Host $Host -TestType baseline
        Start-Sleep -Seconds 30
        
        # Cache
        Write-Host "[2/4] Cache Test" -ForegroundColor Yellow
        & $PSCommandPath -Host $Host -TestType cache
        Start-Sleep -Seconds 30
        
        # Stress
        Write-Host "[3/4] Stress Test" -ForegroundColor Yellow
        & $PSCommandPath -Host $Host -TestType stress
        Start-Sleep -Seconds 60
        
        # Heavy
        Write-Host "[4/4] Heavy Test" -ForegroundColor Yellow
        & $PSCommandPath -Host $Host -TestType heavy
        
        Write-Host ""
        Write-Host "All tests completed!" -ForegroundColor Green
        Write-Host "Reports saved in: load-testing/reports/" -ForegroundColor Cyan
        return
    }
}

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Green
Write-Host "Report saved: reports/$TestType-image-test.html" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open the HTML report to view detailed metrics" -ForegroundColor Gray
Write-Host "  2. Check CloudWatch dashboard for S3 and CloudFront metrics" -ForegroundColor Gray
Write-Host "  3. Verify auto-scaling behavior in AWS Console" -ForegroundColor Gray
Write-Host "  4. Review S3 upload/download latency (p50, p95, p99)" -ForegroundColor Gray
