# Generates road-following corridor geometry for the map by routing the
# ordered halte waypoints of each corridor direction through OSRM, then writes
# the result to assets/corridor_routes.json (loaded at runtime by the app).
#
# Run once from the repo root:  powershell -ExecutionPolicy Bypass -File scripts/generate_corridor_routes.ps1
# Output format: { "K1": { "pergi": [[lat, lng], ...], "pulang": [[lat, lng], ...] }, ... }

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$haltePath = Join-Path $root 'assets/halte.json'
$outPath = Join-Path $root 'assets/corridor_routes.json'
$osrmHost = 'https://router.project-osrm.org'
$decimals = 6
$delaySeconds = 1.2

if (-not (Test-Path -LiteralPath $haltePath)) {
    throw "halte.json not found at $haltePath"
}

$halte = Get-Content -LiteralPath $haltePath -Raw | ConvertFrom-Json
$result = [ordered]@{}

foreach ($corridor in $halte.PSObject.Properties.Name) {
    $directions = $halte.$corridor.arah
    $corridorOut = [ordered]@{}
    foreach ($dirKey in $directions.PSObject.Properties.Name) {
        $stops = $directions.$dirKey.halte
        if ($stops.Count -lt 2) {
            Write-Warning "${corridor}/${dirKey}: fewer than 2 halte, skipped"
            continue
        }

        # OSRM expects lon,lat pairs joined by ';'.
        $coords = ($stops | ForEach-Object { "{0},{1}" -f $_.lng, $_.lat }) -join ';'
        $uri = "$osrmHost/route/v1/driving/${coords}?overview=full&geometries=geojson&continue_straight=false"

        $ok = $false
        for ($attempt = 1; $attempt -le 3 -and -not $ok; $attempt++) {
            try {
                $resp = Invoke-RestMethod -Uri $uri -TimeoutSec 60 -Headers @{ 'User-Agent' = 'TransPadangLive/1.0 (+https://github.com/dwiky/transpadang-live)' }
                if ($resp.code -eq 'Ok' -and $resp.routes.Count -ge 1) {
                    $coordsOut = foreach ($pair in $resp.routes[0].geometry.coordinates) {
                        ,@([math]::Round($pair[1], $decimals), [math]::Round($pair[0], $decimals))
                    }
                    $corridorOut[$dirKey] = @($coordsOut)
                    Write-Host ("{0}/{1}: {2} halte -> {3} points" -f $corridor, $dirKey, $stops.Count, $corridorOut[$dirKey].Count)
                    $ok = $true
                } else {
                    Write-Warning "${corridor}/${dirKey}: OSRM responded '$($resp.code)' (attempt $attempt)"
                }
            } catch {
                Write-Warning "${corridor}/${dirKey}: request failed (attempt $attempt): $($_.Exception.Message)"
            }
            if (-not $ok) { Start-Sleep -Seconds 2 }
        }

        if (-not $ok) {
            Write-Warning "${corridor}/${dirKey}: no geometry; app will fall back to straight lines"
        }
        Start-Sleep -Seconds $delaySeconds
    }
    if ($corridorOut.Count -gt 0) { $result[$corridor] = $corridorOut }
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8
$sizeKb = [math]::Round((Get-Item -LiteralPath $outPath).Length / 1KB, 1)
Write-Host "Wrote $outPath ($sizeKb KB)"

