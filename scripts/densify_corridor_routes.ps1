# Menambahkan titik di antara vertex yang sudah ada pada berkas GeoJSON koridor
# manual (assets/routes/K{n}.geojson) supaya garis mengikuti jalan dan tidak
# memotong tikungan saat di-zoom. Titik tambahan diambil dari geometri OSRM
# (assets/corridor_routes.json, lihat scripts/generate_corridor_routes.ps1).
#
# Yang TIDAK dilakukan skrip ini:
#  - tidak menghapus atau memindahkan vertex yang sudah ada;
#  - tidak mengubah rute: titik hanya disisipkan di antara dua vertex.
#
# Suatu segmen hanya dihaluskan bila:
#  1. kedua ujungnya <= -MaxEndpointOffsetMeters dari jalur OSRM (artinya rute
#     gambar manual memang mengikuti jalan itu), dan
#  2. jalur OSRM penggantinya wajar: panjang <= -MaxDetourRatio x panjang garis
#     lurus, dan simpangannya terhadap garis lurus <= -MaxDeviationMeters.
# Segmen yang tidak memenuhi syarat dibiarkan utuh, jadi koridor yang sengaja
# digambar berbeda dari OSRM (mis. K3) hampir tidak berubah.
# Titik kembar berurutan dibuang karena tidak mengubah bentuk garis.
#
# Tanpa -Apply skrip hanya mencetak laporan (dry run).
#
# Contoh:
#   powershell -ExecutionPolicy Bypass -File scripts/densify_corridor_routes.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/densify_corridor_routes.ps1 -Apply
param(
    [string]$RoutesDir = (Join-Path $PSScriptRoot '..\assets\routes'),
    [string]$OsrmFile = (Join-Path $PSScriptRoot '..\assets\corridor_routes.json'),
    [double]$MaxEndpointOffsetMeters = 8,
    [double]$MaxDetourRatio = 1.4,
    [double]$MaxDeviationMeters = 50,
    [switch]$Apply
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

# Daftar koordinat [lng, lat] -> daftar XY meter (proyeksi equirectangular).
function ConvertTo-Xy($coords, [double]$kx, [double]$ky) {
    $out = New-Object System.Collections.Generic.List[double[]]
    foreach ($c in $coords) {
        $x = ([double]$c[0]) * $kx
        $y = ([double]$c[1]) * $ky
        $out.Add([double[]]@($x, $y))
    }
    return , $out
}

$osrm = Get-Content $OsrmFile -Raw | ConvertFrom-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$totalSegments = 0
$totalInserted = 0

foreach ($file in (Get-ChildItem -Path $RoutesDir -Filter '*.geojson' | Sort-Object Name)) {
    $code = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $raw = [System.IO.File]::ReadAllText($file.FullName)
    if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
    $doc = $raw | ConvertFrom-Json
    Write-Host "== $($file.Name)"

    foreach ($feature in $doc.features) {
        $direction = [string]$feature.properties.direction
        $manual = @($feature.geometry.coordinates)

        $osrmRaw = $null
        if ($null -ne $osrm.$code) { $osrmRaw = $osrm.$code.$direction }
        if ($null -eq $osrmRaw) {
            Write-Host "   $direction : dilewati (tidak ada geometri OSRM)"
            continue
        }

        # OSRM menyimpan [lat, lng]; samakan menjadi [lng, lat] seperti GeoJSON.
        $osrmCoords = New-Object System.Collections.Generic.List[object]
        foreach ($p in $osrmRaw) {
            $osrmCoords.Add(@([double]$p[1], [double]$p[0]))
        }

        # Proyeksi memakai lintang rata-rata kedua geometri.
        $latSum = 0.0
        $latCount = 0
        foreach ($c in $manual) { $latSum += [double]$c[1]; $latCount++ }
        foreach ($c in $osrmCoords) { $latSum += [double]$c[1]; $latCount++ }
        $meanLat = $latSum / $latCount
        $kx = 111320.0 * [math]::Cos($meanLat * [math]::PI / 180.0)
        $ky = 110540.0

        $M = ConvertTo-Xy $manual $kx $ky
        $O = ConvertTo-Xy $osrmCoords $kx $ky

        # Indeks vertex OSRM terdekat untuk tiap vertex manual: pindai kasar
        # tiap 5 titik, lalu perhalus di sekitarnya (lebih cepat dari O(n*m)).
        $coarse = 5
        $idx = New-Object 'int[]' $M.Count
        for ($i = 0; $i -lt $M.Count; $i++) {
            $best = [double]::MaxValue
            $bestJ = 0
            for ($j = 0; $j -lt $O.Count; $j += $coarse) {
                $dx = $O[$j][0] - $M[$i][0]
                $dy = $O[$j][1] - $M[$i][1]
                $d = $dx * $dx + $dy * $dy
                if ($d -lt $best) { $best = $d; $bestJ = $j }
            }
            $from = [math]::Max(0, $bestJ - $coarse - 1)
            $to = [math]::Min($O.Count - 1, $bestJ + $coarse + 1)
            for ($j = $from; $j -le $to; $j++) {
                $dx = $O[$j][0] - $M[$i][0]
                $dy = $O[$j][1] - $M[$i][1]
                $d = $dx * $dx + $dy * $dy
                if ($d -lt $best) { $best = $d; $bestJ = $j }
            }
            $idx[$i] = $bestJ
        }

        $out = New-Object System.Collections.Generic.List[object]
        $out.Add(@([double]$manual[0][0], [double]$manual[0][1]))
        $smoothedSegments = 0
        $smoothedMeters = 0.0
        $keptMeters = 0.0
        $inserted = 0

        for ($i = 0; $i -lt $M.Count - 1; $i++) {
            $a = $M[$i]
            $b = $M[$i + 1]
            $chord = [math]::Sqrt(($b[0] - $a[0]) * ($b[0] - $a[0]) + ($b[1] - $a[1]) * ($b[1] - $a[1]))
            $j1 = $idx[$i]
            $j2 = $idx[$i + 1]

            $usable = $false
            if ($j1 -ne $j2) {
                $d1 = [math]::Sqrt(($O[$j1][0] - $a[0]) * ($O[$j1][0] - $a[0]) + ($O[$j1][1] - $a[1]) * ($O[$j1][1] - $a[1]))
                $d2 = [math]::Sqrt(($O[$j2][0] - $b[0]) * ($O[$j2][0] - $b[0]) + ($O[$j2][1] - $b[1]) * ($O[$j2][1] - $b[1]))
                if ($d1 -le $MaxEndpointOffsetMeters -and $d2 -le $MaxEndpointOffsetMeters) {
                    $usable = $true
                }
            }
            if ($usable -and ($j2 -lt $j1)) {
                $tmp = $j1; $j1 = $j2; $j2 = $tmp
            }

            $smooth = $false
            if ($usable -and (($j2 - $j1) -ge 2)) {
                $subLen = 0.0
                for ($k = $j1; $k -lt $j2; $k++) {
                    $subLen += [math]::Sqrt(($O[$k + 1][0] - $O[$k][0]) * ($O[$k + 1][0] - $O[$k][0]) + ($O[$k + 1][1] - $O[$k][1]) * ($O[$k + 1][1] - $O[$k][1]))
                }
                if ($subLen -le ($MaxDetourRatio * $chord)) {
                    $maxDev = 0.0
                    for ($k = $j1 + 1; $k -lt $j2; $k++) {
                        $dev = Get-PointSegmentDistance $O[$k][0] $O[$k][1] $a[0] $a[1] $b[0] $b[1]
                        if ($dev -gt $maxDev) { $maxDev = $dev }
                    }
                    if ($maxDev -le $MaxDeviationMeters) { $smooth = $true }
                }
            }

            if ($smooth) {
                for ($k = $j1 + 1; $k -lt $j2; $k++) {
                    $out.Add(@([double]$osrmCoords[$k][0], [double]$osrmCoords[$k][1]))
                    $inserted++
                }
                $smoothedSegments++
                $smoothedMeters += $chord
            } else {
                $keptMeters += $chord
            }
            $out.Add(@([double]$manual[$i + 1][0], [double]$manual[$i + 1][1]))
        }

        # Buang titik kembar berurutan (bentuk garis tidak berubah).
        $final = New-Object System.Collections.Generic.List[object]
        foreach ($p in $out) {
            if ($final.Count -gt 0) {
                $last = $final[$final.Count - 1]
                if ($last[0] -eq $p[0] -and $last[1] -eq $p[1]) { continue }
            }
            $final.Add($p)
        }

        $coords = @()
        foreach ($p in $final) {
            $coords += , @([math]::Round([double]$p[0], 6), [math]::Round([double]$p[1], 6))
        }
        $feature.geometry.coordinates = $coords

        $totalSegments += $smoothedSegments
        $totalInserted += $inserted
        Write-Host ("   {0,7} : {1,4} -> {2,4} titik | dihaluskan {3,3}/{4,3} segmen ({5,5:N1} km) | dibiarkan {6,5:N1} km | +{7,4} titik" -f `
                $direction, $manual.Count, $coords.Count, $smoothedSegments, ($M.Count - 1), ($smoothedMeters / 1000.0), ($keptMeters / 1000.0), $inserted)
    }

    if ($Apply) {
        $json = $doc | ConvertTo-Json -Depth 12 -Compress
        [System.IO.File]::WriteAllText($file.FullName, $json, $utf8NoBom)
        Write-Host "   -> ditulis: $($file.Name)"
    }
}

Write-Host ""
Write-Host ("Total: {0} segmen dihaluskan, {1} titik disisipkan." -f $totalSegments, $totalInserted)
if (-not $Apply) {
    Write-Host "Dry run - tambahkan -Apply untuk menulis berkas."
}
