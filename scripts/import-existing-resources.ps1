# Import Existing AWS Resources into Terraform State
# Use this when resources exist but aren't in Terraform state

param([string]$Region = "ap-south-1")

Write-Host "🔄 Importing Existing AWS Resources" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$infraPath = "infrastructure"
if (-not (Test-Path $infraPath)) {
    Write-Host "❌ Run this from terraform-crud root directory" -ForegroundColor Red
    exit 1
}

Set-Location $infraPath

Write-Host "Checking for existing resources..." -ForegroundColor Yellow
Write-Host ""

# 1. Import Key Pair
Write-Host "[1/5] Key Pair (crud-app-key)..." -ForegroundColor Cyan
$keyExists = aws ec2 describe-key-pairs --key-names crud-app-key --region $Region 2>$null
if ($keyExists) {
    Write-Host "  Found - Importing..." -ForegroundColor Yellow
    terraform import aws_key_pair.deployer crud-app-key 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Imported" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Already in state or failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found - will be created" -ForegroundColor Gray
}

# 2. Import IAM Role
Write-Host "[2/5] IAM Role (crud-app-ec2-role)..." -ForegroundColor Cyan
$roleExists = aws iam get-role --role-name crud-app-ec2-role 2>$null
if ($roleExists) {
    Write-Host "  Found - Importing..." -ForegroundColor Yellow
    terraform import aws_iam_role.ec2_role crud-app-ec2-role 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Imported" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Already in state or failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found - will be created" -ForegroundColor Gray
}

# 3. Import IAM Role Policy Attachment
Write-Host "[3/5] IAM Role Policy Attachment..." -ForegroundColor Cyan
if ($roleExists) {
    Write-Host "  Found - Importing..." -ForegroundColor Yellow
    terraform import aws_iam_role_policy_attachment.dynamodb_policy "crud-app-ec2-role/arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Imported" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Already in state or failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found - will be created" -ForegroundColor Gray
}

# 4. Import IAM Instance Profile
Write-Host "[4/5] IAM Instance Profile..." -ForegroundColor Cyan
$profileExists = aws iam get-instance-profile --instance-profile-name crud-app-ec2-profile 2>$null
if ($profileExists) {
    Write-Host "  Found - Importing..." -ForegroundColor Yellow
    terraform import aws_iam_instance_profile.ec2_profile crud-app-ec2-profile 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Imported" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Already in state or failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found - will be created" -ForegroundColor Gray
}

# 5. Import Target Group (find ARN first)
Write-Host "[5/5] Target Group (crud-app-tg)..." -ForegroundColor Cyan
$tgArn = ""
try {
    # Get all target groups and filter
    $allTgs = & aws elbv2 describe-target-groups --region $Region --output json 2>$null
    if ($allTgs) {
        $tgJson = $allTgs | ConvertFrom-Json
        $tg = $tgJson.TargetGroups | Where-Object { $_.TargetGroupName -eq "crud-app-tg" }
        if ($tg) {
            $tgArn = $tg.TargetGroupArn
        }
    }
} catch {
    # Ignore errors
}

if ($tgArn) {
    Write-Host "  Found - Importing..." -ForegroundColor Yellow
    Write-Host "  ARN: $tgArn" -ForegroundColor Gray
    terraform import aws_lb_target_group.app $tgArn 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Imported" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Already in state or failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found - will be created" -ForegroundColor Gray
}

Set-Location ..

Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host "✅ Import process complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  cd infrastructure" -ForegroundColor White
Write-Host "  terraform plan" -ForegroundColor White
Write-Host "  terraform apply" -ForegroundColor White
Write-Host ""
