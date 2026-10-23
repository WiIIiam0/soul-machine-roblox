param(
    [string]$ApiKey = "",
    [string]$UniverseId = "",
    [string]$PlaceId = ""
)

$ErrorActionPreference = "Stop"

# Load from config file if exists
$configFile = Join-Path $PSScriptRoot "roblox_config.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
    if (-not $ApiKey -and $config.apiKey) { $ApiKey = $config.apiKey }
    if (-not $UniverseId -and $config.universeId) { $UniverseId = $config.universeId }
    if (-not $PlaceId -and $config.placeId) { $PlaceId = $config.placeId }
}

# Fallback to environment variables
if (-not $ApiKey) { $ApiKey = $env:ROBLOX_API_KEY }
if (-not $UniverseId) { $UniverseId = $env:ROBLOX_UNIVERSE_ID }
if (-not $PlaceId) { $PlaceId = $env:ROBLOX_PLACE_ID }

if (-not $ApiKey -or -not $UniverseId -or -not $PlaceId) {
    Write-Host "[ERROR] Configuration manquante !" -ForegroundColor Red
    Write-Host "Veuillez renseigner votre roblox_config.json avec :" -ForegroundColor Yellow
    Write-Host "  - apiKey (cle Open Cloud avec permission Place Write/Publish)"
    Write-Host "  - universeId (ID du jeu sur create.roblox.com)"
    Write-Host "  - placeId (ID de la Place)"
    exit 1
}

Write-Host ">>> [1/3] Compilation du projet Roblox avec Rojo..." -ForegroundColor Cyan
$buildFile = Join-Path $PSScriptRoot "temp_publish.rbxl"
if (Test-Path $buildFile) { Remove-Item $buildFile -Force }

rojo build default.project.json --output $buildFile
if (-not (Test-Path $buildFile)) {
    Write-Host "[ERROR] Echec de la compilation du fichier .rbxl" -ForegroundColor Red
    exit 1
}

Write-Host ">>> [2/3] Publication vers l'API Open Cloud Roblox..." -ForegroundColor Cyan
$url = "https://apis.roblox.com/universes/v1/$UniverseId/places/$PlaceId/versions?versionType=Published"

try {
    $fileBytes = [System.IO.File]::ReadAllBytes($buildFile)
    $headers = @{
        "x-api-key" = $ApiKey
        "Content-Type" = "application/octet-stream"
    }

    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $fileBytes
    Write-Host ">>> [3/3] SUCCES ! Nouvelle version publiee avec succes sur Roblox !" -ForegroundColor Green
    Write-Host "Version du jeu en ligne : $($response.versionNumber)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Echec lors de la publication Roblox Open Cloud :" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
    exit 1
} finally {
    if (Test-Path $buildFile) {
        Remove-Item $buildFile -Force -ErrorAction SilentlyContinue
    }
}
