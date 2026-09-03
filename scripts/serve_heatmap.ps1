#Requires -Version 5.1
<#
.SYNOPSIS
  Serve the live Web Serial heatmap on http://localhost:8765 and open the browser.

.EXAMPLE
  .\scripts\serve_heatmap.ps1
#>
param(
    [int]$Port = 8765
)

$root = Split-Path -Parent $PSScriptRoot
$web = Join-Path $root "web\heatmap"

if (-not (Test-Path (Join-Path $web "index.html"))) {
    Write-Error "Missing $web\index.html"
    exit 1
}

Write-Host "Serving heatmap from: $web"
Write-Host "Open: http://localhost:$Port/"
Write-Host "Use Chrome or Edge. Close idf.py monitor before clicking Connect ESP32."
Write-Host "Ctrl+C to stop.`n"

$url = "http://localhost:$Port/"
Start-Process $url

Set-Location $web
python -m http.server $Port
