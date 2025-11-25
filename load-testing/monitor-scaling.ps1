# Monitor Auto Scaling and ALB during load testing
# Run this in a separate terminal while load testing

param(
    [string]$ASGName = "crud-app-asg",
    [string]$ALBName = "crud-app-alb",
    [int]$RefreshInterval = 30  # seconds
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auto Scaling & ALB Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitoring every $RefreshInterval seconds..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

function Get-Timestamp {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Show-ASGStatus {
    Write-Host "$(Get-Timestamp) - Checking Auto Scaling Group..." -ForegroundColor Cyan
    
    $asg = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASGName --query 'AutoScalingGroups[0]' | ConvertFrom-Json
    
    if ($asg) {
        Write-Host "  Min Size: $($asg.MinSize)" -ForegroundColor White
        Write-Host "  Desired: $($asg.DesiredCapacity)" -ForegroundColor Yellow
        Write-Host "  Current: $($asg.Instances.Count)" -ForegroundColor Green
        Write-Host "  Max Size: $($asg.MaxSize)" -ForegroundColor White
        
        Write-Host "  Instances:" -ForegroundColor White
        foreach ($instance in $asg.Instances) {
            $status = $instance.LifecycleState
            $health = $instance.HealthStatus
            $color = if ($health -eq "Healthy") { "Green" } else { "Red" }
            Write-Host "    - $($instance.InstanceId): $status ($health)" -ForegroundColor $color
        }
    }
    Write-Host ""
}

function Show-ScalingActivity {
    Write-Host "$(Get-Timestamp) - Recent Scaling Activities:" -ForegroundColor Cyan
    
    $activities = aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASGName --max-records 3 --query 'Activities[*].[StartTime,Description,StatusCode]' --output table
    
    Write-Host $activities
    Write-Host ""
}

function Show-CloudWatchAlarms {
    Write-Host "$(Get-Timestamp) - CloudWatch Alarms:" -ForegroundColor Cyan
    
    $alarms = aws cloudwatch describe-alarms --alarm-names "crud-app-high-cpu" "crud-app-low-cpu" --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' --output table
    
    Write-Host $alarms
    Write-Host ""
}

function Show-TargetHealth {
    Write-Host "$(Get-Timestamp) - Target Group Health:" -ForegroundColor Cyan
    
    # Get target group ARN
    $tgArn = aws elbv2 describe-target-groups --names "crud-app-tg" --query 'TargetGroups[0].TargetGroupArn' --output text
    
    if ($tgArn) {
        $targets = aws elbv2 describe-target-health --target-group-arn $tgArn | ConvertFrom-Json
        
        $healthy = ($targets.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
        $total = $targets.TargetHealthDescriptions.Count
        
        Write-Host "  Healthy Targets: $healthy / $total" -ForegroundColor Green
        
        foreach ($target in $targets.TargetHealthDescriptions) {
            $state = $target.TargetHealth.State
            $color = switch ($state) {
                "healthy" { "Green" }
                "unhealthy" { "Red" }
                default { "Yellow" }
            }
            Write-Host "    - $($target.Target.Id): $state" -ForegroundColor $color
        }
    }
    Write-Host ""
}

function Show-ALBMetrics {
    Write-Host "$(Get-Timestamp) - ALB Request Count (last 5 min):" -ForegroundColor Cyan
    
    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-5)
    
    $metrics = aws cloudwatch get-metric-statistics `
        --namespace AWS/ApplicationELB `
        --metric-name RequestCount `
        --dimensions Name=LoadBalancer,Value="app/crud-app-alb/*" `
        --start-time $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
        --end-time $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
        --period 300 `
        --statistics Sum `
        --query 'Datapoints[0].Sum' `
        --output text
    
    if ($metrics -and $metrics -ne "None") {
        Write-Host "  Total Requests: $metrics" -ForegroundColor Green
    } else {
        Write-Host "  No data available yet" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Main monitoring loop
while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Auto Scaling & ALB Monitor - $(Get-Timestamp)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Show-ASGStatus
    Show-TargetHealth
    Show-CloudWatchAlarms
    Show-ScalingActivity
    Show-ALBMetrics
    
    Write-Host "Next refresh in $RefreshInterval seconds..." -ForegroundColor Gray
    Start-Sleep -Seconds $RefreshInterval
}
