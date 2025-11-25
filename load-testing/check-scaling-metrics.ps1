# Quick diagnostic to check why auto-scaling isn't triggering
# Run this to see current CPU and alarm status

Write-Host "Checking Auto Scaling Metrics..." -ForegroundColor Cyan
Write-Host ""

# 1. Check current CPU utilization
Write-Host "=== Current CPU Utilization ===" -ForegroundColor Yellow
$endTime = Get-Date
$startTime = $endTime.AddMinutes(-10)

$cpuMetrics = aws cloudwatch get-metric-statistics `
    --namespace AWS/EC2 `
    --metric-name CPUUtilization `
    --dimensions Name=AutoScalingGroupName,Value=crud-app-asg `
    --start-time $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
    --end-time $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
    --period 60 `
    --statistics Average,Maximum `
    --query 'Datapoints | sort_by(@, &Timestamp)[-5:]' | ConvertFrom-Json

if ($cpuMetrics) {
    foreach ($metric in $cpuMetrics) {
        $time = ([DateTime]$metric.Timestamp).ToLocalTime().ToString("HH:mm:ss")
        Write-Host "  $time - Avg: $([math]::Round($metric.Average, 2))% | Max: $([math]::Round($metric.Maximum, 2))%" -ForegroundColor White
    }
} else {
    Write-Host "  No CPU data available" -ForegroundColor Red
}
Write-Host ""

# 2. Check alarm states
Write-Host "=== CloudWatch Alarm Status ===" -ForegroundColor Yellow
$alarms = aws cloudwatch describe-alarms `
    --alarm-names "crud-app-high-cpu" "crud-app-low-cpu" | ConvertFrom-Json

foreach ($alarm in $alarms.MetricAlarms) {
    $color = switch ($alarm.StateValue) {
        "ALARM" { "Red" }
        "OK" { "Green" }
        default { "Yellow" }
    }
    Write-Host "  $($alarm.AlarmName): $($alarm.StateValue)" -ForegroundColor $color
    Write-Host "    Threshold: $($alarm.Threshold)%" -ForegroundColor Gray
    Write-Host "    Reason: $($alarm.StateReason)" -ForegroundColor Gray
}
Write-Host ""

# 3. Check ASG capacity
Write-Host "=== Auto Scaling Group Status ===" -ForegroundColor Yellow
$asg = aws autoscaling describe-auto-scaling-groups `
    --auto-scaling-group-names crud-app-asg `
    --query 'AutoScalingGroups[0]' | ConvertFrom-Json

Write-Host "  Current: $($asg.Instances.Count) instances" -ForegroundColor White
Write-Host "  Desired: $($asg.DesiredCapacity)" -ForegroundColor Yellow
Write-Host "  Min: $($asg.MinSize) | Max: $($asg.MaxSize)" -ForegroundColor Gray
Write-Host ""

# 4. Check recent scaling activities
Write-Host "=== Recent Scaling Activities ===" -ForegroundColor Yellow
$activities = aws autoscaling describe-scaling-activities `
    --auto-scaling-group-name crud-app-asg `
    --max-records 5 | ConvertFrom-Json

if ($activities.Activities) {
    foreach ($activity in $activities.Activities) {
        $time = ([DateTime]$activity.StartTime).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "  [$time] $($activity.StatusCode)" -ForegroundColor Cyan
        Write-Host "    $($activity.Description)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No recent activities" -ForegroundColor Gray
}
Write-Host ""

# 5. Recommendations
Write-Host "=== Recommendations ===" -ForegroundColor Green
$maxCpu = ($cpuMetrics | Measure-Object -Property Average -Maximum).Maximum
if ($maxCpu -lt 50) {
    Write-Host "  ⚠ CPU is low ($([math]::Round($maxCpu, 2))%). Your load test may not be CPU-intensive enough." -ForegroundColor Yellow
    Write-Host "    - Try using WriteHeavyUser class in Locust" -ForegroundColor Gray
    Write-Host "    - Lower the CPU threshold to 40-50%" -ForegroundColor Gray
    Write-Host "    - Add ALB-based scaling (RequestCountPerTarget)" -ForegroundColor Gray
}

if ($asg.MaxSize -le 4) {
    Write-Host "  ⚠ Max capacity is only $($asg.MaxSize) instances. Consider increasing it." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
