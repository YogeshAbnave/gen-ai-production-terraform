# Infrastructure Check Script
# Run this before pushing to GitHub to verify AWS infrastructure exists

param(
    [string]$Region = "ap-south-1"
)

Write-Host "🔍 Checking AWS Infrastructure..." -ForegroundColor Cyan
Write-Host ""

$allGood = $true

# Check AWS credentials
Write-Host "Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if ($identity) {
        Write-Host "✅ AWS credentials configured" -ForegroundColor Green
        Write-Host "   Account: $($identity.Account)" -ForegroundColor Gray
        Write-Host "   User: $($identity.Arn)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ AWS credentials not configured" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Check VPC
Write-Host "Checking VPC..." -ForegroundColor Yellow
try {
    $vpc = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=crud-app-vpc" --region $Region --output json 2>$null | ConvertFrom-Json
    if ($vpc.Vpcs.Count -gt 0) {
        Write-Host "✅ VPC 'crud-app-vpc' exists" -ForegroundColor Green
        Write-Host "   VPC ID: $($vpc.Vpcs[0].VpcId)" -ForegroundColor Gray
    } else {
        Write-Host "❌ VPC 'crud-app-vpc' not found" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host "❌ Error checking VPC" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Check ALB
Write-Host "Checking Application Load Balancer..." -ForegroundColor Yellow
try {
    $alb = aws elbv2 describe-load-balancers --names crud-app-alb --region $Region --output json 2>$null | ConvertFrom-Json
    if ($alb.LoadBalancers.Count -gt 0) {
        Write-Host "✅ ALB 'crud-app-alb' exists" -ForegroundColor Green
        Write-Host "   DNS: $($alb.LoadBalancers[0].DNSName)" -ForegroundColor Gray
        Write-Host "   State: $($alb.LoadBalancers[0].State.Code)" -ForegroundColor Gray
    } else {
        Write-Host "❌ ALB 'crud-app-alb' not found" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host "❌ ALB 'crud-app-alb' not found" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Check Auto Scaling Group
Write-Host "Checking Auto Scaling Group..." -ForegroundColor Yellow
try {
    $asg = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names crud-app-asg --region $Region --output json 2>$null | ConvertFrom-Json
    if ($asg.AutoScalingGroups.Count -gt 0) {
        Write-Host "✅ ASG 'crud-app-asg' exists" -ForegroundColor Green
        Write-Host "   Desired: $($asg.AutoScalingGroups[0].DesiredCapacity)" -ForegroundColor Gray
        Write-Host "   Min: $($asg.AutoScalingGroups[0].MinSize)" -ForegroundColor Gray
        Write-Host "   Max: $($asg.AutoScalingGroups[0].MaxSize)" -ForegroundColor Gray
        
        $instanceCount = $asg.AutoScalingGroups[0].Instances.Count
        Write-Host "   Instances: $instanceCount" -ForegroundColor Gray
        
        if ($instanceCount -eq 0) {
            Write-Host "   ⚠️ No instances in ASG yet (may be launching)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ ASG 'crud-app-asg' not found" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host "❌ ASG 'crud-app-asg' not found" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Check running EC2 instances
Write-Host "Checking EC2 instances..." -ForegroundColor Yellow
try {
    $instances = aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=crud-app-asg" "Name=instance-state-name,Values=running" --region $Region --output json 2>$null | ConvertFrom-Json
    $runningInstances = $instances.Reservations.Instances
    
    if ($runningInstances.Count -gt 0) {
        Write-Host "✅ Found $($runningInstances.Count) running instance(s)" -ForegroundColor Green
        foreach ($instance in $runningInstances) {
            Write-Host "   Instance: $($instance.InstanceId)" -ForegroundColor Gray
            Write-Host "   Public IP: $($instance.PublicIpAddress)" -ForegroundColor Gray
            Write-Host "   State: $($instance.State.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ No running instances found" -ForegroundColor Red
        Write-Host "   Instances may still be launching. Wait a few minutes and check again." -ForegroundColor Yellow
        $allGood = $false
    }
} catch {
    Write-Host "❌ Error checking EC2 instances" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Check DynamoDB table
Write-Host "Checking DynamoDB table..." -ForegroundColor Yellow
try {
    $table = aws dynamodb describe-table --table-name app-data-table --region $Region --output json 2>$null | ConvertFrom-Json
    if ($table.Table) {
        Write-Host "✅ DynamoDB table 'app-data-table' exists" -ForegroundColor Green
        Write-Host "   Status: $($table.Table.TableStatus)" -ForegroundColor Gray
    } else {
        Write-Host "❌ DynamoDB table 'app-data-table' not found" -ForegroundColor Red
        $allGood = $false
    }
} catch {
    Write-Host "❌ DynamoDB table 'app-data-table' not found" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Final summary
Write-Host "============================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host "✅ All infrastructure checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now push to GitHub to trigger deployment:" -ForegroundColor Cyan
    Write-Host "  git add ." -ForegroundColor Gray
    Write-Host "  git commit -m 'Deploy application'" -ForegroundColor Gray
    Write-Host "  git push origin main" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or use the deployment script:" -ForegroundColor Cyan
    Write-Host "  .\scripts\deploy.ps1 -Push" -ForegroundColor Gray
} else {
    Write-Host "❌ Infrastructure checks failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Deploy Terraform infrastructure first:" -ForegroundColor Yellow
    Write-Host "  cd infrastructure" -ForegroundColor Gray
    Write-Host "  terraform init" -ForegroundColor Gray
    Write-Host "  terraform apply" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or use the deployment script:" -ForegroundColor Yellow
    Write-Host "  .\scripts\deploy.ps1 -Deploy" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Then run this check again:" -ForegroundColor Yellow
    Write-Host "  .\scripts\check-infrastructure.ps1" -ForegroundColor Gray
    exit 1
}
