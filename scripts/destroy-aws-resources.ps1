# Manual AWS Resource Cleanup Script
# Use this when Terraform state is lost or resources exist outside Terraform

param(
    [string]$Region = "ap-south-1",
    [switch]$DryRun
)

Write-Host "🗑️  AWS Resource Cleanup Script" -ForegroundColor Red
Write-Host "================================" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No resources will be deleted" -ForegroundColor Yellow
    Write-Host ""
}

$ErrorActionPreference = "Continue"

# Function to run AWS CLI commands safely
function Invoke-AwsCli {
    param([string]$Command)
    $output = Invoke-Expression $Command
    return $output
}

Write-Host "Step 1: Finding Internet Gateway..." -ForegroundColor Cyan
$igwId = "igw-00673a90431da2b9f"
Write-Host "  IGW ID: $igwId" -ForegroundColor White

# Get VPC ID from IGW
Write-Host ""
Write-Host "Step 2: Finding VPC..." -ForegroundColor Cyan
$vpcCmd = "aws ec2 describe-internet-gateways --internet-gateway-ids $igwId --region $Region --query 'InternetGateways[0].Attachments[0].VpcId' --output text"
$vpcId = Invoke-AwsCli -Command $vpcCmd
Write-Host "  VPC ID: $vpcId" -ForegroundColor White

if ([string]::IsNullOrEmpty($vpcId) -or $vpcId -eq "None") {
    Write-Host "❌ Could not find VPC. IGW might be detached." -ForegroundColor Red
    Write-Host ""
    Write-Host "Trying to delete IGW directly..." -ForegroundColor Yellow
    if (-not $DryRun) {
        aws ec2 delete-internet-gateway --internet-gateway-id $igwId --region $Region
        Write-Host "✅ IGW deleted" -ForegroundColor Green
    }
    exit 0
}

Write-Host ""
Write-Host "Step 3: Finding all resources in VPC $vpcId..." -ForegroundColor Cyan
Write-Host ""

# Get VPC name
$vpcName = Invoke-AwsCli -Command "aws ec2 describe-vpcs --vpc-ids $vpcId --region $Region --query 'Vpcs[0].Tags[?Key==``Name``].Value' --output text"
Write-Host "  VPC Name: $vpcName" -ForegroundColor White
Write-Host ""

# List all resources
Write-Host "📋 Resources found:" -ForegroundColor Yellow
Write-Host ""

# Check for Load Balancers
Write-Host "  Checking Load Balancers..." -ForegroundColor Gray
$albCmd = "aws elbv2 describe-load-balancers --region $Region --query 'LoadBalancers[?VpcId==``$vpcId``].[LoadBalancerArn,LoadBalancerName]' --output text"
$albs = Invoke-AwsCli -Command $albCmd
if ($albs) {
    Write-Host "    ✓ Found Load Balancers" -ForegroundColor Green
}

# Check for Target Groups
Write-Host "  Checking Target Groups..." -ForegroundColor Gray
$tgCmd = "aws elbv2 describe-target-groups --region $Region --query 'TargetGroups[?VpcId==``$vpcId``].[TargetGroupArn,TargetGroupName]' --output text"
$tgs = Invoke-AwsCli -Command $tgCmd
if ($tgs) {
    Write-Host "    ✓ Found Target Groups" -ForegroundColor Green
}

# Check for Auto Scaling Groups
Write-Host "  Checking Auto Scaling Groups..." -ForegroundColor Gray
$asgCmd = "aws autoscaling describe-auto-scaling-groups --region $Region --query 'AutoScalingGroups[?VPCZoneIdentifier!=``null``].AutoScalingGroupName' --output text"
$asgs = Invoke-AwsCli -Command $asgCmd
if ($asgs) {
    Write-Host "    ✓ Found Auto Scaling Groups" -ForegroundColor Green
}

# Check for EC2 Instances
Write-Host "  Checking EC2 Instances..." -ForegroundColor Gray
$instanceCmd = "aws ec2 describe-instances --region $Region --filters 'Name=vpc-id,Values=$vpcId' 'Name=instance-state-name,Values=running,stopped,stopping' --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text"
$instances = Invoke-AwsCli -Command $instanceCmd
if ($instances) {
    Write-Host "    ✓ Found EC2 Instances" -ForegroundColor Green
}

# Check for NAT Gateways
Write-Host "  Checking NAT Gateways..." -ForegroundColor Gray
$natCmd = "aws ec2 describe-nat-gateways --region $Region --filter 'Name=vpc-id,Values=$vpcId' 'Name=state,Values=available' --query 'NatGateways[].[NatGatewayId]' --output text"
$nats = Invoke-AwsCli -Command $natCmd
if ($nats) {
    Write-Host "    ✓ Found NAT Gateways" -ForegroundColor Green
}

# Check for Subnets
Write-Host "  Checking Subnets..." -ForegroundColor Gray
$subnetCmd = "aws ec2 describe-subnets --region $Region --filters 'Name=vpc-id,Values=$vpcId' --query 'Subnets[].[SubnetId]' --output text"
$subnets = Invoke-AwsCli -Command $subnetCmd
if ($subnets) {
    Write-Host "    ✓ Found Subnets" -ForegroundColor Green
}

# Check for Security Groups
Write-Host "  Checking Security Groups..." -ForegroundColor Gray
$sgCmd = "aws ec2 describe-security-groups --region $Region --filters 'Name=vpc-id,Values=$vpcId' --query 'SecurityGroups[?GroupName!=``default``].[GroupId,GroupName]' --output text"
$sgs = Invoke-AwsCli -Command $sgCmd
if ($sgs) {
    Write-Host "    ✓ Found Security Groups" -ForegroundColor Green
}

# Check for Route Tables
Write-Host "  Checking Route Tables..." -ForegroundColor Gray
$rtCmd = "aws ec2 describe-route-tables --region $Region --filters 'Name=vpc-id,Values=$vpcId' --query 'RouteTables[].[RouteTableId]' --output text"
$rts = Invoke-AwsCli -Command $rtCmd
if ($rts) {
    Write-Host "    ✓ Found Route Tables" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "✅ Dry run complete. Resources found but not deleted." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To delete all resources, run:" -ForegroundColor Cyan
    Write-Host "  .\scripts\destroy-aws-resources.ps1" -ForegroundColor White
    exit 0
}

Write-Host "⚠️  WARNING: This will DELETE all resources in VPC $vpcId" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'DELETE' to confirm destruction"

if ($confirm -ne "DELETE") {
    Write-Host "❌ Cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "🗑️  Starting resource deletion..." -ForegroundColor Red
Write-Host ""

# Delete in correct order to handle dependencies

# 1. Delete Load Balancers
if ($albs) {
    Write-Host "1. Deleting Load Balancers..." -ForegroundColor Yellow
    $albArns = $albs -split "`n" | ForEach-Object { ($_ -split "`t")[0] }
    foreach ($arn in $albArns) {
        if ($arn) {
            Write-Host "   Deleting $arn..." -ForegroundColor Gray
            aws elbv2 delete-load-balancer --load-balancer-arn $arn --region $Region
        }
    }
    Write-Host "   Waiting for ALBs to delete..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 2. Delete Target Groups
if ($tgs) {
    Write-Host "2. Deleting Target Groups..." -ForegroundColor Yellow
    $tgArns = $tgs -split "`n" | ForEach-Object { ($_ -split "`t")[0] }
    foreach ($arn in $tgArns) {
        if ($arn) {
            Write-Host "   Deleting $arn..." -ForegroundColor Gray
            aws elbv2 delete-target-group --target-group-arn $arn --region $Region
        }
    }
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 3. Delete Auto Scaling Groups
if ($asgs) {
    Write-Host "3. Deleting Auto Scaling Groups..." -ForegroundColor Yellow
    $asgNames = $asgs -split "`n"
    foreach ($name in $asgNames) {
        if ($name -and $name.Trim()) {
            Write-Host "   Deleting $name..." -ForegroundColor Gray
            aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $name.Trim() --force-delete --region $Region
        }
    }
    Write-Host "   Waiting for ASGs to delete..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 4. Terminate EC2 Instances
if ($instances) {
    Write-Host "4. Terminating EC2 Instances..." -ForegroundColor Yellow
    $instanceIds = $instances -split "`n" | ForEach-Object { ($_ -split "`t")[0] }
    foreach ($id in $instanceIds) {
        if ($id) {
            Write-Host "   Terminating $id..." -ForegroundColor Gray
            aws ec2 terminate-instances --instance-ids $id --region $Region
        }
    }
    Write-Host "   Waiting for instances to terminate..." -ForegroundColor Gray
    Start-Sleep -Seconds 60
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 5. Delete NAT Gateways
if ($nats) {
    Write-Host "5. Deleting NAT Gateways..." -ForegroundColor Yellow
    $natIds = $nats -split "`n"
    foreach ($id in $natIds) {
        if ($id) {
            Write-Host "   Deleting $id..." -ForegroundColor Gray
            aws ec2 delete-nat-gateway --nat-gateway-id $id --region $Region
        }
    }
    Write-Host "   Waiting for NAT Gateways to delete..." -ForegroundColor Gray
    Start-Sleep -Seconds 60
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 6. Detach and Delete Internet Gateway
Write-Host "6. Deleting Internet Gateway..." -ForegroundColor Yellow
Write-Host "   Detaching from VPC..." -ForegroundColor Gray
aws ec2 detach-internet-gateway --internet-gateway-id $igwId --vpc-id $vpcId --region $Region
Write-Host "   Deleting..." -ForegroundColor Gray
aws ec2 delete-internet-gateway --internet-gateway-id $igwId --region $Region
Write-Host "   ✅ Done" -ForegroundColor Green

# 7. Delete Subnets
if ($subnets) {
    Write-Host "7. Deleting Subnets..." -ForegroundColor Yellow
    $subnetIds = $subnets -split "`n"
    foreach ($id in $subnetIds) {
        if ($id) {
            Write-Host "   Deleting $id..." -ForegroundColor Gray
            aws ec2 delete-subnet --subnet-id $id --region $Region
        }
    }
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 8. Delete Route Tables (except main)
if ($rts) {
    Write-Host "8. Deleting Route Tables..." -ForegroundColor Yellow
    $rtIds = $rts -split "`n"
    foreach ($id in $rtIds) {
        if ($id) {
            # Check if it's the main route table
            $isMain = aws ec2 describe-route-tables --route-table-ids $id --region $Region --query 'RouteTables[0].Associations[?Main==``true``]' --output text
            if (-not $isMain) {
                Write-Host "   Deleting $id..." -ForegroundColor Gray
                aws ec2 delete-route-table --route-table-id $id --region $Region 2>$null
            }
        }
    }
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 9. Delete Security Groups (except default)
if ($sgs) {
    Write-Host "9. Deleting Security Groups..." -ForegroundColor Yellow
    $sgIds = $sgs -split "`n" | ForEach-Object { ($_ -split "`t")[0] }
    foreach ($id in $sgIds) {
        if ($id) {
            Write-Host "   Deleting $id..." -ForegroundColor Gray
            aws ec2 delete-security-group --group-id $id --region $Region 2>$null
        }
    }
    Write-Host "   ✅ Done" -ForegroundColor Green
}

# 10. Delete VPC
Write-Host "10. Deleting VPC..." -ForegroundColor Yellow
aws ec2 delete-vpc --vpc-id $vpcId --region $Region
Write-Host "   ✅ Done" -ForegroundColor Green

# 11. Delete DynamoDB Table
Write-Host "11. Checking DynamoDB Table..." -ForegroundColor Yellow
$tableExists = aws dynamodb describe-table --table-name app-data-table --region $Region 2>$null
if ($tableExists) {
    Write-Host "   Deleting app-data-table..." -ForegroundColor Gray
    aws dynamodb delete-table --table-name app-data-table --region $Region
    Write-Host "   ✅ Done" -ForegroundColor Green
} else {
    Write-Host "   No DynamoDB table found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ All AWS resources deleted!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
