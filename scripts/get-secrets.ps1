# PowerShell - Extract GitHub Secrets from Terraform

Write-Host "🔐 Extracting GitHub Secrets from Terraform" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "infrastructure")) {
    Write-Host "❌ Error: infrastructure directory not found" -ForegroundColor Red
    exit 1
}

Push-Location infrastructure

if (-not (Test-Path "terraform.tfstate")) {
    Write-Host "❌ Error: Terraform state not found" -ForegroundColor Red
    Write-Host "Please run 'terraform apply' first"
    Pop-Location
    exit 1
}

Write-Host "📋 Extracting values from Terraform..." -ForegroundColor Green
Write-Host ""

$EC2_HOST = terraform output -raw ec2_public_ip 2>$null
$PRIVATE_KEY_PATH = terraform output -raw private_key_path 2>$null

Pop-Location

if ([string]::IsNullOrEmpty($EC2_HOST)) {
    Write-Host "❌ Error: Could not get EC2 IP" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrEmpty($PRIVATE_KEY_PATH) -or -not (Test-Path $PRIVATE_KEY_PATH)) {
    Write-Host "❌ Error: Private key not found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Successfully extracted all secrets!" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📝 GitHub Secrets Configuration" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add these secrets to:" -ForegroundColor White
Write-Host "https://github.com/YogeshAbnave/terraform-crud/settings/secrets/actions" -ForegroundColor Blue
Write-Host ""
Write-Host "1️⃣  EC2_HOST" -ForegroundColor Green
Write-Host $EC2_HOST -ForegroundColor White
Write-Host ""
Write-Host "2️⃣  EC2_PRIVATE_KEY" -ForegroundColor Green
Get-Content $PRIVATE_KEY_PATH | Write-Host -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔗 Application URL: http://$EC2_HOST" -ForegroundColor Cyan
Write-Host "🔗 GitHub Actions: https://github.com/YogeshAbnave/terraform-crud/actions" -ForegroundColor Cyan
Write-Host ""

$EC2_HOST | Set-Clipboard
Write-Host "📋 EC2_HOST copied to clipboard!" -ForegroundColor Green
Write-Host ""
