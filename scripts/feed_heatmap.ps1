#Requires -Version 5.1
<#
.SYNOPSIS
  Read Golf Mat serial swings from COM4 and copy heatmap JSON to the clipboard.

.DESCRIPTION
  Parses lines like:
    Swing: quality=92 zone=Center zone_id=2 dir=Straight dir_id=0 heel=28% ... peaks=120,85,160,155,90,75

  Each parsed swing is:
    1) Printed as JSON
    2) Copied to the clipboard

  Then paste into the Golf Strike Heatmap canvas "Load from serial" box.

.EXAMPLE
  .\scripts\feed_heatmap.ps1
  .\scripts\feed_heatmap.ps1 -Port COM4 -Baud 115200
#>
param(
    [string]$Port = "COM4",
    [int]$Baud = 115200
)

function Convert-SwingLineToJson {
    param([string]$Line)

    if ($Line -notmatch 'Swing:') { return $null }

    $quality = if ($Line -match 'quality=(\d+)') { [int]$Matches[1] } else { 0 }
    $zoneId = if ($Line -match 'zone_id=(\d+)') { [int]$Matches[1] } else { 2 }
    $dirId = if ($Line -match 'dir_id=(\d+)') { [int]$Matches[1] } else { 0 }
    $heel = if ($Line -match 'heel=(\d+)%') { [int]$Matches[1] } else { 0 }
    $center = if ($Line -match 'center=(\d+)%') { [int]$Matches[1] } else { 0 }
    $toe = if ($Line -match 'toe=(\d+)%') { [int]$Matches[1] } else { 0 }
    $distance = if ($Line -match 'estimated_distance=(\d+)m') { [int]$Matches[1] } else { 0 }
    $penalty = if ($Line -match 'penalty=(\d+)') { [int]$Matches[1] } else { 0 }
    $dirLabel = if ($Line -match 'dir=([^\s]+)') { $Matches[1] } else { "Straight" }

    $peaks = @(0, 0, 0, 0, 0, 0)
    if ($Line -match 'peaks=([\d,]+)') {
        $parts = $Matches[1].Split(',') | ForEach-Object { [int]$_ }
        for ($i = 0; $i -lt [Math]::Min(6, $parts.Count); $i++) {
            $peaks[$i] = $parts[$i]
        }
    }

    $obj = [ordered]@{
        fsr_peaks            = $peaks
        strike_zone          = $zoneId
        strike_direction     = $dirId
        heel_pressure_pct    = $heel
        center_pressure_pct  = $center
        toe_pressure_pct     = $toe
        impact_quality       = $quality
        estimated_distance_m = $distance
        direction_penalty    = $penalty
        direction_label      = $dirLabel
    }
    return ($obj | ConvertTo-Json -Compress)
}

Write-Host "Opening $Port @ $Baud ..."
Write-Host "Close idf.py monitor first if it is using this port."
Write-Host "On each swing, JSON is copied to clipboard — paste into the heatmap canvas."
Write-Host "Ctrl+C to stop.`n"

$portObj = New-Object System.IO.Ports.SerialPort $Port, $Baud, None, 8, One
$portObj.NewLine = "`n"
$portObj.ReadTimeout = 1000
try {
    $portObj.Open()
} catch {
    Write-Error "Could not open $Port. Stop the IDF monitor, then retry. $_"
    exit 1
}

try {
    while ($true) {
        try {
            $line = $portObj.ReadLine()
        } catch {
            continue
        }
        if (-not $line) { continue }

        if ($line -match 'Swing:') {
            Write-Host $line
            $json = Convert-SwingLineToJson -Line $line
            if ($json) {
                Set-Clipboard -Value $json
                Write-Host "→ clipboard JSON ready to paste into heatmap" -ForegroundColor Green
                Write-Host $json
                Write-Host ""
            }
        }
    }
} finally {
    if ($portObj.IsOpen) { $portObj.Close() }
}
