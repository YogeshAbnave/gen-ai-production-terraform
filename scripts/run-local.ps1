param([switch]$Setup, [switch]$Backend, [switch]$Frontend, [switch]$Both)
Write-Host "CRUD App - Local Development" -ForegroundColor Cyan
if ($Setup) {
    Write-Host "Setting up Backend..." -ForegroundColor Green
    Push-Location src/backend
    python -m venv venv
    & .\venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    Pop-Location
    Write-Host "Setting up Frontend..." -ForegroundColor Green
    Push-Location src/frontend
    npm install
    Pop-Location
    Write-Host "Setup complete!" -ForegroundColor Green
} elseif ($Backend) {
    Push-Location src/backend
    & .\venv\Scripts\Activate.ps1
    $env:DYNAMODB_TABLE = "app-data-table"
    $env:AWS_REGION = "ap-south-1"
    uvicorn app.main:app --reload --port 8000
    Pop-Location
} elseif ($Frontend) {
    Push-Location src/frontend
    npm run dev
    Pop-Location
} elseif ($Both) {
    Write-Host "Run in separate terminals:" -ForegroundColor Yellow
    Write-Host "  Terminal 1: .\scripts\run-local.ps1 -Backend"
    Write-Host "  Terminal 2: .\scripts\run-local.ps1 -Frontend"
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\scripts\run-local.ps1 -Setup"
    Write-Host "  .\scripts\run-local.ps1 -Backend"
    Write-Host "  .\scripts\run-local.ps1 -Frontend"
    Write-Host "  .\scripts\run-local.ps1 -Both"
}
