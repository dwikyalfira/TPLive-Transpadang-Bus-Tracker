# Mengubah geometri koridor yang digambar manual (assets/routes/K{n}.geojson)
# menjadi berkas GPX yang bisa langsung di-drag & drop ke editor iD
# (https://www.openstreetmap.org/edit).
#
# Kenapa GPX: iD hanya menerima GPX sebagai panduan visual, tidak menerima
# GeoJSON. GPX ini TIDAK ikut terunggah ke OSM; jalan yang sudah ada di OSM
# tetap harus dipilih/digambar manual di atasnya.
#
# Keluaran: satu berkas per koridor di routes_gpx/K{n}.gpx, berisi
#  - satu <trk> per arah (pergi/pulang), namanya "K1 pergi: <halte awal> -> <halte akhir>";
#  - <wpt> untuk tiap halte arah tersebut (dari halte.json) sebagai penanda posisi.
#
# Contoh:
#   powershell -ExecutionPolicy Bypass -File scripts/export_corridor_gpx.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/export_corridor_gpx.ps1 -NoWaypoints
param(
    [string]$RoutesDir = (Join-Path $PSScriptRoot '..\assets\routes'),
    [string]$HalteFile = (Join-Path $PSScriptRoot '..\assets\halte.json'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\routes_gpx'),
    [switch]$NoWaypoints
)

$ErrorActionPreference = 'Stop'

$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-XmlText($value) {
    if ($null -eq $value) { return '' }
    return [System.Security.SecurityElement]::Escape(([string]$value).Trim())
}

function Get-CoordText($value) {
    # 7 desimal (~1 cm) cukup untuk GPX dan tidak membengkakkan berkas.
    return ([double]$value).ToString('0.#######', $invariant)
}

$halte = $null
if (Test-Path -LiteralPath $HalteFile) {
    $halte = Get-Content -LiteralPath $HalteFile -Raw | ConvertFrom-Json
}

$files = Get-ChildItem -Path $RoutesDir -Filter '*.geojson' -ErrorAction SilentlyContinue | Sort-Object Name
if (-not $files -or $files.Count -eq 0) {
    Write-Host "Tidak ada berkas .geojson di $RoutesDir"
    exit 0
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$totalFiles = 0

foreach ($file in $files) {
    $geo = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    if ($geo.type -ne 'FeatureCollection' -or -not $geo.features) {
        Write-Warning "$($file.Name): bukan FeatureCollection, dilewati"
        continue
    }

    $tracks = New-Object System.Collections.Generic.List[string]
    $waypoints = New-Object System.Collections.Generic.List[string]
    $corridorLabel = $file.BaseName
    $totalPoints = 0
    $trackCount = 0
    $waypointCount = 0

    foreach ($feature in $geo.features) {
        $corridor = [string]$feature.properties.corridor
        $direction = [string]$feature.properties.direction
        if ([string]::IsNullOrWhiteSpace($corridor)) { $corridor = $file.BaseName }
        $corridor = $corridor.Trim().ToUpper()
        $direction = $direction.Trim().ToLower()
        $corridorLabel = $corridor

        if ($feature.geometry.type -ne 'LineString') {
            Write-Warning "$($file.Name) [$corridor/$direction]: geometri bukan LineString, dilewati"
            continue
        }
        $coords = $feature.geometry.coordinates
        if (-not $coords -or $coords.Count -lt 2) {
            Write-Warning "$($file.Name) [$corridor/$direction]: butuh minimal dua titik, dilewati"
            continue
        }

        # Nama track diambil dari halte ujung arah ini, bila tersedia.
        $startName = $null
        $endName = $null
        $stops = $null
        if ($halte -and $halte.PSObject.Properties.Name.Contains($corridor)) {
            $directionData = $halte.$corridor.arah.PSObject.Properties[$direction]
            if ($directionData) {
                $stops = $directionData.Value.halte
                if ($stops -and $stops.Count -ge 1) {
                    $startName = $stops[0].nama
                    $endName = $stops[$stops.Count - 1].nama
                }
            }
        }

        $trackName = "$corridor $direction"
        if ($startName -and $endName) {
            $trackName = "$corridor $direction`: $startName -> $endName"
        }

        $tracks.Add("  <trk>")
        $tracks.Add("    <name>$(Get-XmlText $trackName)</name>")
        $tracks.Add("    <desc>Panduan tracing jalur TransPadang, jangan diunggah sebagai data OSM.</desc>")
        $tracks.Add("    <trkseg>")
        foreach ($pair in $coords) {
            $lng = Get-CoordText $pair[0]
            $lat = Get-CoordText $pair[1]
            $tracks.Add("      <trkpt lat=`"$lat`" lon=`"$lng`"/>")
        }
        $tracks.Add("    </trkseg>")
        $tracks.Add("  </trk>")
        $totalPoints += $coords.Count
        $trackCount++

        if (-not $NoWaypoints -and $stops) {
            foreach ($stop in $stops) {
                $lng = Get-CoordText $stop.lng
                $lat = Get-CoordText $stop.lat
                $name = Get-XmlText $stop.nama
                $waypoints.Add("  <wpt lat=`"$lat`" lon=`"$lng`">")
                $waypoints.Add("    <name>$name</name>")
                $waypoints.Add("    <desc>$corridor $direction (halte)</desc>")
                $waypoints.Add("  </wpt>")
                $waypointCount++
            }
        }
    }

    if ($tracks.Count -eq 0) {
        Write-Warning "$($file.Name): tidak ada track yang bisa ditulis"
        continue
    }

    $outFile = Join-Path $OutDir "$($file.BaseName).gpx"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('<?xml version="1.0" encoding="UTF-8"?>')
    $lines.Add('<gpx version="1.1" creator="TransPadangLive (scripts/export_corridor_gpx.ps1)"')
    $lines.Add('     xmlns="http://www.topografix.com/GPX/1/1"')
    $lines.Add('     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
    $lines.Add('     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">')
    $lines.Add('  <metadata>')
    $lines.Add("    <name>TransPadang $corridorLabel</name>")
    $lines.Add("    <desc>Jalur koridor $corridorLabel untuk panduan tracing di editor iD OSM.</desc>")
    $lines.Add('  </metadata>')
    $lines.AddRange($waypoints)
    $lines.AddRange($tracks)
    $lines.Add('</gpx>')

    [System.IO.File]::WriteAllText($outFile, ($lines -join "`n") + "`n", $utf8NoBom)

    $wpInfo = if ($waypointCount -gt 0) { ", $waypointCount halte" } else { '' }
    Write-Host ("{0} -> {1} ({2} track, {3} titik{4})" -f `
        $file.Name, (Split-Path -Leaf $outFile), $trackCount, $totalPoints, $wpInfo)
    $totalFiles++
}

Write-Host ""
Write-Host "Selesai: $totalFiles berkas di $OutDir"
Write-Host "Buka https://www.openstreetmap.org/edit lalu drag & drop berkas .gpx ke peta."
