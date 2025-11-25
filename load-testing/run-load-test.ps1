# Load Testing Script for ALB and Auto Scaling
# Run this script to start load testing

param(
    [string]$ALB_URL = "http://crud-app-alb-263940571.ap-south-1.elb.amazonaws.com",
    [int]$Users = 200,
    [int]$SpawnRate = 10,
    [string]$TestType = "balanced"  # balanced, read-heavy, write-heavy
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CRUD App Load Testing Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Locust is installed
Write-Host "Checking if Locust is installed..." -ForegroundColor Yellow
try {
    $locustVersion = locust --version 2>&1
    Write-Host "[OK] Locust is installed: $locustVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Locust is not installed!" -ForegroundColor Red
    Write-Host "Installing Locust..." -ForegroundColor Yellow
    pip install locust
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install Locust. Please install Python and pip first." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  Target URL: $ALB_URL" -ForegroundColor White
Write-Host "  Users: $Users" -ForegroundColor White
Write-Host "  Spawn Rate: $SpawnRate users/sec" -ForegroundColor White
Write-Host "  Test Type: $TestType" -ForegroundColor White
Write-Host ""

Write-Host "Starting Locust..." -ForegroundColor Yellow
Write-Host "Web UI will be available at: http://localhost:8089" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Test type '$TestType' - You can select user class in the web UI" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the test" -ForegroundColor Yellow
Write-Host ""

# Start Locust (without --user-classes as it's not supported in all versions)
locust -f locustfile.py --host=$ALB_URL --web-host=0.0.0.0
