# PowerShell script to monitor auto-scaling and image metrics during load tests
# Displays real-time CloudWatch metrics for S3, CloudFront, and EC2

param(
    [Parameter(Mandatory=$false)]
    [int]$RefreshInterval = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Image Operations Monitoring" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get infrastructure details from Terraform
Write-Host "Getting infrastructure details..." -ForegroundColor Yellow
Push-Location ../infrastructure

$asgName = terraform output -raw asg_name 2>$null
$s3Bucket = terraform output -raw s3_bucket_name 2>$null
$cloudfrontId = terraform output -raw cloudfront_distribution_id 2>$null

Pop-Location

if ([string]::IsNullOrEmpty($asgName) -or [string]::IsNullOrEmpty($s3Bucket)) {
    Write-Host "Error: Could not get infrastructure details from Terraform" -ForegroundColor Red
    exit 1
}

Write-Host "Auto Scaling Group: $asgName" -ForegroundColor Green
Write-Host "S3 Bucket: $s3Bucket" -ForegroundColor Green
Write-Host "CloudFront Distribution: $cloudfrontId" -ForegroundColor Green
Write-Host "Refresh Interval: $RefreshInterval seconds" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

function Get-Metric {
    param(
        [string]$Namespace,
        [string]$MetricName,
        [hashtable]$Dimensions,
        [string]$Statistic = "Average",
        [int]$Period = 300
    )
    
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-5)
    
    $dimensionParams = @()
    foreach ($key in $Dimensions.Keys) {
        $dimensionParams += "Name=$key,Value=$($Dimensions[$key])"
    }
    
    $cmd = "aws cloudwatch get-metric-statistics " +
           "--namespace `"$Namespace`" " +
           "--metric-name `"$MetricName`" " +
           "--dimensions $($dimensionParams -join ' ') " +
           "--start-time `"$($startTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss'))`" " +
           "--end-time `"$($endTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss'))`" " +
           "--period $Period " +
           "--statistics $Statistic " +
           "--region $Region " +
           "--output json"
    
    try {
        $result = Invoke-Expression $cmd | ConvertFrom-Json
        if ($result.Datapoints.Count -gt 0) {
            $latest = $result.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 1
            return $latest.$Statistic
        }
    } catch {
        return $null
    }
    
    return $null
}

# Monitoring loop
while ($true) {
    Clear-Host
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Monitoring - $timestamp" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Auto Scaling Group Status
    Write-Host "AUTO SCALING GROUP" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    
    $asgInfo = aws autoscaling describe-auto-scaling-groups `
        --auto-scaling-group-names $asgName `
        --region $Region `
        --output json | ConvertFrom-Json
    
    if ($asgInfo.AutoScalingGroups.Count -gt 0) {
        $asg = $asgInfo.AutoScalingGroups[0]
        $desired = $asg.DesiredCapacity
        $current = $asg.Instances.Count
        $healthy = ($asg.Instances | Where-Object { $_.HealthStatus -eq "Healthy" }).Count
        
        Write-Host "  Desired Capacity:  $desired" -ForegroundColor White
        Write-Host "  Current Instances: $current" -ForegroundColor White
        Write-Host "  Healthy Instances: $healthy" -ForegroundColor Green
        Write-Host ""
    }
    
    # EC2 CPU Utilization
    Write-Host "EC2 METRICS" -ForegroundColor Yellow
    Write-Host "===========" -ForegroundColor Yellow
    
    $cpuUtil = Get-Metric -Namespace "AWS/EC2" `
        -MetricName "CPUUtilization" `
        -Dimensions @{ AutoScalingGroupName = $asgName } `
        -Statistic "Average"
    
    if ($cpuUtil) {
        $cpuColor = if ($cpuUtil -gt 70) { "Red" } elseif ($cpuUtil -gt 40) { "Yellow" } else { "Green" }
        Write-Host "  CPU Utilization: " -NoNewline
        Write-Host "$([math]::Round($cpuUtil, 2))%" -ForegroundColor $cpuColor
    } else {
        Write-Host "  CPU Utilization: No data" -ForegroundColor Gray
    }
    Write-Host ""
    
    # S3 Metrics
    Write-Host "S3 METRICS" -ForegroundColor Yellow
    Write-Host "==========" -ForegroundColor Yellow
    
    $s3Requests = Get-Metric -Namespace "AWS/S3" `
        -MetricName "AllRequests" `
        -Dimensions @{ BucketName = $s3Bucket; FilterId = "EntireBucket" } `
        -Statistic "Sum"
    
    $s3Errors = Get-Metric -Namespace "AWS/S3" `
        -MetricName "5xxErrors" `
        -Dimensions @{ BucketName = $s3Bucket; FilterId = "EntireBucket" } `
        -Statistic "Sum"
    
    if ($s3Requests) {
        Write-Host "  Total Requests (5min): $([math]::Round($s3Requests, 0))" -ForegroundColor White
    } else {
        Write-Host "  Total Requests: No data" -ForegroundColor Gray
    }
    
    if ($s3Errors) {
        $errorColor = if ($s3Errors -gt 0) { "Red" } else { "Green" }
        Write-Host "  5xx Errors (5min): " -NoNewline
        Write-Host "$([math]::Round($s3Errors, 0))" -ForegroundColor $errorColor
    } else {
        Write-Host "  5xx Errors: No data" -ForegroundColor Gray
    }
    Write-Host ""
    
    # CloudFront Metrics
    Write-Host "CLOUDFRONT METRICS" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    
    $cfRequests = Get-Metric -Namespace "AWS/CloudFront" `
        -MetricName "Requests" `
        -Dimensions @{ DistributionId = $cloudfrontId } `
        -Statistic "Sum"
    
    $cfCacheHit = Get-Metric -Namespace "AWS/CloudFront" `
        -MetricName "CacheHitRate" `
        -Dimensions @{ DistributionId = $cloudfrontId } `
        -Statistic "Average"
    
    if ($cfRequests) {
        Write-Host "  Total Requests (5min): $([math]::Round($cfRequests, 0))" -ForegroundColor White
    } else {
        Write-Host "  Total Requests: No data" -ForegroundColor Gray
    }
    
    if ($cfCacheHit) {
        $cacheColor = if ($cfCacheHit -lt 70) { "Red" } elseif ($cfCacheHit -lt 85) { "Yellow" } else { "Green" }
        Write-Host "  Cache Hit Rate: " -NoNewline
        Write-Host "$([math]::Round($cfCacheHit, 2))%" -ForegroundColor $cacheColor
    } else {
        Write-Host "  Cache Hit Rate: No data" -ForegroundColor Gray
    }
    Write-Host ""
    
    # CloudWatch Alarms
    Write-Host "CLOUDWATCH ALARMS" -ForegroundColor Yellow
    Write-Host "=================" -ForegroundColor Yellow
    
    $alarms = aws cloudwatch describe-alarms `
        --alarm-name-prefix "education-portal" `
        --region $Region `
        --output json | ConvertFrom-Json
    
    if ($alarms.MetricAlarms.Count -gt 0) {
        foreach ($alarm in $alarms.MetricAlarms) {
            $stateColor = switch ($alarm.StateValue) {
                "OK" { "Green" }
                "ALARM" { "Red" }
                "INSUFFICIENT_DATA" { "Gray" }
                default { "White" }
            }
            
            Write-Host "  $($alarm.AlarmName): " -NoNewline
            Write-Host $alarm.StateValue -ForegroundColor $stateColor
        }
    } else {
        Write-Host "  No alarms found" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Next refresh in $RefreshInterval seconds..." -ForegroundColor Gray
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
    
    Start-Sleep -Seconds $RefreshInterval
}
