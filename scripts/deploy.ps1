param([switch]$Deploy, [switch]$Secrets, [switch]$Push, [switch]$Destroy, [switch]$All)

Write-Host "CRUD App - AWS Deployment" -ForegroundColor Cyan
Write-Host ""

if ($Deploy) {
    Write-Host "Deploying Infrastructure..." -ForegroundColor Green
    Push-Location infrastructure
    terraform init
    terraform apply -auto-approve
    Pop-Location
    Write-Host ""
    Write-Host "Next: .\scripts\deploy.ps1 -Secrets" -ForegroundColor Yellow
}
elseif ($Secrets) {
    Write-Host "GitHub Secrets" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Push-Location infrastructure
    $EC2_IP = terraform output -raw ec2_public_ip
    $KEY_PATH = terraform output -raw private_key_path
    Pop-Location
    Write-Host ""
    Write-Host "1. EC2_HOST" -ForegroundColor Yellow
    Write-Host $EC2_IP
    Write-Host ""
    Write-Host "2. EC2_PRIVATE_KEY" -ForegroundColor Yellow
    Get-Content $KEY_PATH
    Write-Host ""
    Write-Host "Add these to: https://github.com/YOUR_USERNAME/terraform-crud/settings/secrets/actions" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next: .\scripts\deploy.ps1 -Push" -ForegroundColor Yellow
    $EC2_IP | Set-Clipboard
    Write-Host "EC2_HOST copied to clipboard!" -ForegroundColor Green
}
elseif ($Push) {
    Write-Host "Pushing to GitHub..." -ForegroundColor Green
    git add .
    git commit -m "Deploy CRUD application"
    git push origin main
    Write-Host ""
    Write-Host "Deployment triggered! Watch: https://github.com/YOUR_USERNAME/terraform-crud/actions" -ForegroundColor Cyan
}
elseif ($Destroy) {
    Write-Host "Destroying Infrastructure..." -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to confirm"
    if ($confirm -eq "yes") {
        Push-Location infrastructure
        terraform destroy -auto-approve
        Pop-Location
    }
}
elseif ($All) {
    Write-Host "Running complete deployment..." -ForegroundColor Green
    & $PSCommandPath -Deploy
    & $PSCommandPath -Secrets
    Read-Host "Press Enter after adding secrets to GitHub"
    & $PSCommandPath -Push
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\scripts\deploy.ps1 -Deploy    # Deploy infrastructure"
    Write-Host "  .\scripts\deploy.ps1 -Secrets   # Show GitHub secrets"
    Write-Host "  .\scripts\deploy.ps1 -Push      # Push code to GitHub"
    Write-Host "  .\scripts\deploy.ps1 -All       # Run all steps"
    Write-Host "  .\scripts\deploy.ps1 -Destroy   # Destroy infrastructure"
}
