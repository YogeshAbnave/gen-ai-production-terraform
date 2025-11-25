# Manual AWS Resource Cleanup Script
# Destroys AWS resources when Terraform state is lost

param(
    [string]$Region = "ap-south-1",
    [string]$IGW = "igw-00673a90431da2b9f"
)

Write-Host "🗑️  AWS Resource Manual Cleanup" -ForegroundColor Red
Write-Host "===============================" -ForegroundColor Red
Write-Host ""

# Get VPC ID from IGW
Write-Host "Finding VPC from Internet Gateway..." -ForegroundColor Cyan
$vpcId = aws ec2 describe-internet-gateways --internet-gateway-ids $IGW --region $Region --query "InternetGateways[0].Attachments[0].VpcId" --output text

if ([string]::IsNullOrEmpty($vpcId) -or $vpcId -eq "None") {
    Write-Host "❌ Could not find VPC" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found VPC: $vpcId" -ForegroundColor Green
Write-Host ""

# Get VPC name
$vpcName = aws ec2 describe-vpcs --vpc-ids $vpcId --region $Region --query "Vpcs[0].Tags[?Key=='Name'].Value | [0]" --output text
Write-Host "VPC Name: $vpcName" -ForegroundColor White
Write-Host ""

Write-Host "⚠️  This will DELETE all resources in this VPC!" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'DELETE' to confirm"

if ($confirm -ne "DELETE") {
    Write-Host "❌ Cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting deletion process..." -ForegroundColor Yellow
Write-Host ""

# 1. Delete Load Balancers
Write-Host "[1/11] Checking Load Balancers..." -ForegroundColor Cyan
$albs = aws elbv2 describe-load-balancers --region $Region --output json | ConvertFrom-Json
$vpcAlbs = $albs.LoadBalancers | Where-Object { $_.VpcId -eq $vpcId }
if ($vpcAlbs) {
    foreach ($alb in $vpcAlbs) {
        Write-Host "  Deleting ALB: $($alb.LoadBalancerName)" -ForegroundColor Gray
        aws elbv2 delete-load-balancer --load-balancer-arn $alb.LoadBalancerArn --region $Region
    }
    Write-Host "  Waiting 30s for ALBs to delete..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 2. Delete Target Groups
Write-Host "[2/11] Checking Target Groups..." -ForegroundColor Cyan
$tgs = aws elbv2 describe-target-groups --region $Region --output json | ConvertFrom-Json
$vpcTgs = $tgs.TargetGroups | Where-Object { $_.VpcId -eq $vpcId }
if ($vpcTgs) {
    foreach ($tg in $vpcTgs) {
        Write-Host "  Deleting TG: $($tg.TargetGroupName)" -ForegroundColor Gray
        aws elbv2 delete-target-group --target-group-arn $tg.TargetGroupArn --region $Region
    }
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 3. Delete Auto Scaling Groups
Write-Host "[3/11] Checking Auto Scaling Groups..." -ForegroundColor Cyan
$asgs = aws autoscaling describe-auto-scaling-groups --region $Region --output json | ConvertFrom-Json
foreach ($asg in $asgs.AutoScalingGroups) {
    # Check if ASG is in our VPC by checking subnets
    if ($asg.VPCZoneIdentifier) {
        $subnetIds = $asg.VPCZoneIdentifier -split ","
        $subnetVpc = aws ec2 describe-subnets --subnet-ids $subnetIds[0] --region $Region --query "Subnets[0].VpcId" --output text
        if ($subnetVpc -eq $vpcId) {
            Write-Host "  Deleting ASG: $($asg.AutoScalingGroupName)" -ForegroundColor Gray
            aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asg.AutoScalingGroupName --force-delete --region $Region
        }
    }
}
Write-Host "  Waiting 30s for ASGs to delete..." -ForegroundColor Gray
Start-Sleep -Seconds 30
Write-Host "  ✅ Done" -ForegroundColor Green

# 4. Terminate EC2 Instances
Write-Host "[4/11] Checking EC2 Instances..." -ForegroundColor Cyan
$instances = aws ec2 describe-instances --region $Region --filters "Name=vpc-id,Values=$vpcId" "Name=instance-state-name,Values=running,stopped,stopping" --query "Reservations[].Instances[].InstanceId" --output text
if ($instances) {
    $instanceList = $instances -split "\s+"
    foreach ($inst in $instanceList) {
        if ($inst) {
            Write-Host "  Terminating: $inst" -ForegroundColor Gray
            aws ec2 terminate-instances --instance-ids $inst --region $Region
        }
    }
    Write-Host "  Waiting 60s for instances to terminate..." -ForegroundColor Gray
    Start-Sleep -Seconds 60
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 5. Delete NAT Gateways
Write-Host "[5/11] Checking NAT Gateways..." -ForegroundColor Cyan
$nats = aws ec2 describe-nat-gateways --region $Region --filter "Name=vpc-id,Values=$vpcId" "Name=state,Values=available" --query "NatGateways[].NatGatewayId" --output text
if ($nats) {
    $natList = $nats -split "\s+"
    foreach ($nat in $natList) {
        if ($nat) {
            Write-Host "  Deleting: $nat" -ForegroundColor Gray
            aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $Region
        }
    }
    Write-Host "  Waiting 60s for NAT Gateways to delete..." -ForegroundColor Gray
    Start-Sleep -Seconds 60
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 6. Release Elastic IPs
Write-Host "[6/11] Checking Elastic IPs..." -ForegroundColor Cyan
$eips = aws ec2 describe-addresses --region $Region --filters "Name=domain,Values=vpc" --query "Addresses[].AllocationId" --output text
if ($eips) {
    $eipList = $eips -split "\s+"
    foreach ($eip in $eipList) {
        if ($eip) {
            Write-Host "  Releasing: $eip" -ForegroundColor Gray
            aws ec2 release-address --allocation-id $eip --region $Region 2>$null
        }
    }
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 7. Detach and Delete Internet Gateway
Write-Host "[7/11] Deleting Internet Gateway..." -ForegroundColor Cyan
Write-Host "  Detaching from VPC..." -ForegroundColor Gray
aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $vpcId --region $Region 2>$null
Write-Host "  Deleting..." -ForegroundColor Gray
aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $Region
Write-Host "  ✅ Done" -ForegroundColor Green

# 8. Delete Subnets
Write-Host "[8/11] Deleting Subnets..." -ForegroundColor Cyan
$subnets = aws ec2 describe-subnets --region $Region --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[].SubnetId" --output text
if ($subnets) {
    $subnetList = $subnets -split "\s+"
    foreach ($subnet in $subnetList) {
        if ($subnet) {
            Write-Host "  Deleting: $subnet" -ForegroundColor Gray
            aws ec2 delete-subnet --subnet-id $subnet --region $Region
        }
    }
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 9. Delete Route Tables
Write-Host "[9/11] Deleting Route Tables..." -ForegroundColor Cyan
$rts = aws ec2 describe-route-tables --region $Region --filters "Name=vpc-id,Values=$vpcId" --query "RouteTables[].RouteTableId" --output text
if ($rts) {
    $rtList = $rts -split "\s+"
    foreach ($rt in $rtList) {
        if ($rt) {
            # Check if it's the main route table
            $isMain = aws ec2 describe-route-tables --route-table-ids $rt --region $Region --query "RouteTables[0].Associations[?Main==\`true\`]" --output text
            if (-not $isMain) {
                Write-Host "  Deleting: $rt" -ForegroundColor Gray
                aws ec2 delete-route-table --route-table-id $rt --region $Region 2>$null
            }
        }
    }
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 10. Delete Security Groups
Write-Host "[10/11] Deleting Security Groups..." -ForegroundColor Cyan
$sgs = aws ec2 describe-security-groups --region $Region --filters "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text
if ($sgs) {
    $sgList = $sgs -split "\s+"
    foreach ($sg in $sgList) {
        if ($sg) {
            Write-Host "  Deleting: $sg" -ForegroundColor Gray
            aws ec2 delete-security-group --group-id $sg --region $Region 2>$null
        }
    }
}
Write-Host "  ✅ Done" -ForegroundColor Green

# 11. Delete VPC
Write-Host "[11/11] Deleting VPC..." -ForegroundColor Cyan
aws ec2 delete-vpc --vpc-id $vpcId --region $Region
Write-Host "  ✅ Done" -ForegroundColor Green

# Bonus: Delete DynamoDB Table
Write-Host ""
Write-Host "[Bonus] Checking DynamoDB Table..." -ForegroundColor Cyan
$tableCheck = aws dynamodb describe-table --table-name app-data-table --region $Region 2>$null
if ($tableCheck) {
    Write-Host "  Deleting app-data-table..." -ForegroundColor Gray
    aws dynamodb delete-table --table-name app-data-table --region $Region
    Write-Host "  ✅ Done" -ForegroundColor Green
} else {
    Write-Host "  No table found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "===============================" -ForegroundColor Green
Write-Host "✅ All AWS resources deleted!" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host ""
