# Mengubah geometri koridor hasil bangkitan otomatis (assets/corridor_routes.json)
# menjadi berkas GeoJSON yang enak diedit manual (mis. di geojson.io atau JOSM).
#
# Keluaran: satu berkas per koridor di routes_edit/K{n}.geojson, berisi dua
# fitur LineString (pergi & pulang) dengan properti corridor + direction.
# Koordinat dikonversi dari [lat, lng] ke [lng, lat] sesuai standar GeoJSON.
#
# Jumlah titik diringankan dengan Douglas-Peucker (-ToleranceMeters, default 5 m)
# supaya nyaman diedit. Koridor yang sudah punya berkas manual di assets/routes/
# dilewati, kecuali diberi -Force.
#
# Setelah diedit, simpan hasilnya ke assets/routes/K{n}.geojson lalu jalankan
# scripts/validate_corridor_routes.ps1.
#
# Contoh:
#   powershell -ExecutionPolicy Bypass -File scripts/export_corridor_routes_geojson.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/export_corridor_routes_geojson.ps1 -ToleranceMeters 0
#   powershell -ExecutionPolicy Bypass -File scripts/export_corridor_routes_geojson.ps1 -Force
param(
    [double]$ToleranceMeters = 5,
    [switch]$Force,
    [string]$InputJson = (Join-Path $PSScriptRoot '..\assets\corridor_routes.json'),
    [string]$ManualDir = (Join-Path $PSScriptRoot '..\assets\routes'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\routes_edit')
)

$ErrorActionPreference = 'Stop'

# Jarak titik (px,py) ke ruas garis (ax,ay)-(bx,by), semua dalam meter.
function Get-PointSegmentDistance($px, $py, $ax, $ay, $bx, $by) {
    $dx = $bx - $ax
    $dy = $by - $ay
    if ($dx -eq 0 -and $dy -eq 0) {
        return [math]::Sqrt(($px - $ax) * ($px - $ax) + ($py - $ay) * ($py - $ay))
    }
    $t = (($px - $ax) * $dx + ($py - $ay) * $dy) / ($dx * $dx + $dy * $dy)
    if ($t -lt 0) { $t = 0 } elseif ($t -gt 1) { $t = 1 }
    $projX = $ax + $t * $dx
    $projY = $ay + $t * $dy
    return [math]::Sqrt(($px - $projX) * ($px - $projX) + ($py - $projY) * ($py - $projY))
}

# Indeks titik yang dipertahankan oleh Douglas-Peucker (iteratif, tanpa rekursi).
function Get-SimplifiedIndices($xs, $ys, $tolerance) {
    $n = $xs.Count
    $result = New-Object System.Collections.Generic.List[int]
    if ($n -lt 3) {
        for ($i = 0; $i -lt $n; $i++) { $result.Add($i) }
        return , $result
    }

    $keep = New-Object 'bool[]' $n
    $keep[0] = $true
    $keep[$n - 1] = $true

    $stack = New-Object System.Collections.Generic.Stack[int[]]
    $stack.Push([int[]]@(0, ($n - 1)))
    while ($stack.Count -gt 0) {
        $seg = $stack.Pop()
        $first = $seg[0]
        $last = $seg[1]
        $maxDistance = -1.0
        $maxIndex = -1
        for ($i = $first + 1; $i -lt $last; $i++) {
            $distance = Get-PointSegmentDistance $xs[$i] $ys[$i] $xs[$first] $ys[$first] $xs[$last] $ys[$last]
            if ($distance -gt $maxDistance) { $maxDistance = $distance; $maxIndex = $i }
        }
        if ($maxIndex -ne -1 -and $maxDistance -gt $tolerance) {
            $keep[$maxIndex] = $true
            $stack.Push([int[]]@($first, $maxIndex))
            $stack.Push([int[]]@($maxIndex, $last))
        }
    }

    for ($i = 0; $i -lt $n; $i++) {
        if ($keep[$i]) { $result.Add($i) }
    }
    return , $result
}

$data = Get-Content $InputJson -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$written = 0

foreach ($kode in $data.PSObject.Properties.Name) {
    $manualFile = Join-Path $ManualDir "$kode.geojson"
    if ((Test-Path $manualFile) -and -not $Force) {
        Write-Host "$kode : dilewati (sudah ada berkas manual; pakai -Force untuk menimpa)"
        continue
    }

    $features = New-Object System.Collections.Generic.List[object]
    $report = New-Object System.Collections.Generic.List[string]

    foreach ($arah in $data.$kode.PSObject.Properties.Name) {
        $raw = @($data.$kode.$arah)
        $count = $raw.Count
        if ($count -lt 2) {
            $report.Add("  $arah : dilewati (< 2 titik)")
            continue
        }

        # Proyeksi equirectangular (meter) hanya untuk mengukur penyimpangan.
        $latSum = 0.0
        foreach ($p in $raw) { $latSum += [double]$p[0] }
        $meanLat = $latSum / $count
        $cosLat = [math]::Cos($meanLat * [math]::PI / 180.0)

        $xs = New-Object System.Collections.Generic.List[double]
        $ys = New-Object System.Collections.Generic.List[double]
        foreach ($p in $raw) {
            $xs.Add(([double]$p[1]) * 111320.0 * $cosLat)
            $ys.Add(([double]$p[0]) * 111320.0)
        }

        if ($ToleranceMeters -gt 0) {
            $indices = Get-SimplifiedIndices $xs $ys $ToleranceMeters
        } else {
            $indices = New-Object System.Collections.Generic.List[int]
            for ($i = 0; $i -lt $count; $i++) { $indices.Add($i) }
        }

        $coords = @()
        foreach ($i in $indices) {
            $lng = [math]::Round([double]$raw[$i][1], 6)
            $lat = [math]::Round([double]$raw[$i][0], 6)
            $coords += , @($lng, $lat)
        }

        $features.Add([ordered]@{
                type       = 'Feature'
                properties = [ordered]@{ corridor = $kode; direction = $arah }
                geometry   = [ordered]@{ type = 'LineString'; coordinates = $coords }
            })
        $report.Add(("  {0} : {1} -> {2} titik" -f $arah, $count, $indices.Count))
    }

    if ($features.Count -eq 0) {
        Write-Host "$kode : tidak ada arah yang bisa diekspor"
        continue
    }

    $collection = [ordered]@{
        type     = 'FeatureCollection'
        features = $features.ToArray()
    }
    $json = $collection | ConvertTo-Json -Depth 12 -Compress
    $outFile = Join-Path $OutDir "$kode.geojson"
    [System.IO.File]::WriteAllText($outFile, $json, $utf8NoBom)

    Write-Host "$kode : $outFile"
    foreach ($line in $report) { Write-Host $line }
    $written++
}

if ($written -eq 0) {
    Write-Host "Tidak ada berkas baru ditulis (semua koridor sudah manual, atau -Force belum dipakai)."
}
