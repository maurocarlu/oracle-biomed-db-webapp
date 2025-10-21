# Script per avviare la webapp Oracle Database
# Assicurati che Docker Desktop sia in esecuzione prima di lanciare questo script

Write-Host "=== Oracle Database Web Application ===" -ForegroundColor Cyan
Write-Host ""

# Controlla se Docker è in esecuzione
Write-Host "Verifico che Docker sia in esecuzione..." -ForegroundColor Yellow
$dockerRunning = docker info 2>$null
if (-not $dockerRunning) {
    Write-Host "ERRORE: Docker non e' in esecuzione!" -ForegroundColor Red
    Write-Host "Avvia Docker Desktop e riprova." -ForegroundColor Red
    pause
    exit 1
}
Write-Host "Docker e' in esecuzione" -ForegroundColor Green
Write-Host ""

# Controlla se il container Oracle esiste
Write-Host "Verifico la presenza del container Oracle..." -ForegroundColor Yellow
$oracleContainer = docker ps -a --filter "publish=1521" --format "{{.Names}}" 2>$null
if (-not $oracleContainer) {
    Write-Host "ATTENZIONE: Nessun container Oracle trovato sulla porta 1521" -ForegroundColor Yellow
    Write-Host "Assicurati che il container Oracle sia in esecuzione prima di continuare." -ForegroundColor Yellow
    Write-Host ""
} else {
    # Controlla se il container Oracle e' in esecuzione
    $oracleRunning = docker ps --filter "publish=1521" --format "{{.Names}}" 2>$null
    if ($oracleRunning) {
        Write-Host "Container Oracle trovato e in esecuzione: $oracleRunning" -ForegroundColor Green
    } else {
        Write-Host "Container Oracle trovato ma non in esecuzione: $oracleContainer" -ForegroundColor Yellow
        Write-Host "Vuoi avviarlo? (s/n): " -NoNewline
        $risposta = Read-Host
        if ($risposta -eq 's' -or $risposta -eq 'S') {
            docker start $oracleContainer
            Write-Host "Container Oracle avviato, attendo 10 secondi..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    }
}
Write-Host ""

# Naviga nella directory della webapp
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "Costruisco e avvio la webapp..." -ForegroundColor Yellow
Write-Host ""

# Costruisci e avvia il container
docker-compose up --build

Write-Host ""
Write-Host "La webapp e' stata arrestata." -ForegroundColor Yellow
Write-Host "Premi un tasto per uscire..."
pause
