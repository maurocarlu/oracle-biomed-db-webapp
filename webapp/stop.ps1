# Script per fermare la webapp Oracle Database

Write-Host "=== Arresto Oracle Database Web Application ===" -ForegroundColor Cyan
Write-Host ""

# Naviga nella directory della webapp
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "Fermo i container..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "Webapp arrestata con successo ✓" -ForegroundColor Green
Write-Host ""
pause
