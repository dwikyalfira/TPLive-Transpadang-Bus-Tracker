# Memeriksa berkas GeoJSON koridor yang digambar manual di assets/routes/.
#
# Untuk tiap berkas:
#  - harus FeatureCollection dengan minimal satu fitur LineString (>= 2 titik);
#  - setiap fitur wajib punya properti corridor (K1..K6) dan direction (pergi/pulang);
#  - semua titik harus di dalam bbox Padang;
#  - titik awal/akhir dibandingkan dengan halte ujung arah tersebut ATAU ujung
#    geometri OSRM (assets/corridor_routes.json). Perbandingan ke OSRM perlu
#    karena banyak koordinat halte di halte.json masih placeholder/duplikat,
#    sehingga jarak ke halte saja bisa menyesatkan.
#  - segmen maju-mundur (spur) hanya dilaporkan sebagai info: putaran balik
#    sungguhan (masuk terminal, U-turn, beda sisi jalan) juga berbentuk spur.
#
# Keluar dengan kode 1 bila ada galat (warn/info tidak menggagalkan).
#
# Contoh: powershell -ExecutionPolicy Bypass -File scripts/validate_corridor_routes.ps1
param(
    [string]$RoutesDir = (Join-Path $PSScriptRoot '..\assets\routes'),
    [string]$HalteFile = (Join-Path $PSScriptRoot '..\assets\halte.json'),
    [string]$OsrmFile = (Join-Path $PSScriptRoot '..\assets\corridor_routes.json'),
    [double]$WarnMeters = 500,
    [double]$ErrorMeters = 2000,
    [double]$SpurDirectMeters = 30,
    [double]$SpurLengthMeters = 250
)

$ErrorActionPreference = 'Stop'

# bbox kasar Kota Padang (lat, lng).
$BboxLatMin = -1.20; $BboxLatMax = -0.50
$BboxLngMin = 99.80; $BboxLngMax = 100.80

function Get-DistanceMeters($lat1, $lng1, $lat2, $lng2) {
    $R = 6371000.0
    $dLat = ($lat2 - $lat1) * [math]::PI / 180
    $dLng = ($lng2 - $lng1) * [math]::PI / 180
    $a = [math]::Sin($dLat / 2) * [math]::Sin($dLat / 2) +
        [math]::Cos($lat1 * [math]::PI / 180) * [math]::Cos($lat2 * [math]::PI / 180) *
        [math]::Sin($dLng / 2) * [math]::Sin($dLng / 2)
    return 2 * $R * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
}

$halte = Get-Content $HalteFile -Raw | ConvertFrom-Json
$osrm = $null
if (Test-Path $OsrmFile) {
    $osrm = Get-Content $OsrmFile -Raw | ConvertFrom-Json
}
$files = Get-ChildItem -Path $RoutesDir -Filter '*.geojson' -ErrorAction SilentlyContinue

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$infos = New-Object System.Collections.Generic.List[string]

if (-not $files -or $files.Count -eq 0) {
    Write-Host "Tidak ada berkas .geojson di $RoutesDir"
    exit 0
}

foreach ($file in $files) {
    $name = $file.Name
    Write-Host "== $name"

    try {
        $geo = Get-Content $file.FullName -Raw | ConvertFrom-Json
    } catch {
        $errors.Add("${name}: JSON tidak bisa dibaca ($($_.Exception.Message))")
        continue
    }

    if ($geo.type -ne 'FeatureCollection') {
        $errors.Add("${name}: type harus 'FeatureCollection' (ditemukan '$($geo.type)')")
        continue
    }
    if (-not $geo.features -or $geo.features.Count -eq 0) {
        $errors.Add("${name}: tidak punya fitur")
        continue
    }

    foreach ($f in $geo.features) {
        $corridor = $f.properties.corridor
        $direction = $f.properties.direction

        if ([string]::IsNullOrWhiteSpace($corridor) -or [string]::IsNullOrWhiteSpace($direction)) {
            $errors.Add("${name}: fitur tanpa properti corridor/direction")
            continue
        }
        $corridor = $corridor.Trim().ToUpper()
        $direction = $direction.Trim().ToLower()
        $tag = "$name [$corridor/$direction]"

        if (-not $halte.PSObject.Properties.Name.Contains($corridor)) {
            $errors.Add("$tag : koridor tidak ada di halte.json")
            continue
        }
        if ($direction -ne 'pergi' -and $direction -ne 'pulang') {
            $errors.Add("$tag : direction harus 'pergi' atau 'pulang'")
            continue
        }
        $directionData = $halte.$corridor.arah.$direction
        if (-not $directionData) {
            $errors.Add("$tag : arah tidak ada di halte.json")
            continue
        }

        if ($f.geometry.type -ne 'LineString') {
            $errors.Add("$tag : geometri harus LineString")
            continue
        }
        $coords = $f.geometry.coordinates
        if (-not $coords -or $coords.Count -lt 2) {
            $errors.Add("$tag : butuh minimal dua titik")
            continue
        }

        $outside = 0
        $duplicates = 0
        $maxSeg = 0.0
        $maxSegAt = -1
        for ($i = 0; $i -lt $coords.Count; $i++) {
            $lng = [double]$coords[$i][0]
            $lat = [double]$coords[$i][1]
            if ($lat -lt $BboxLatMin -or $lat -gt $BboxLatMax -or
                $lng -lt $BboxLngMin -or $lng -gt $BboxLngMax) {
                $outside++
            }
            if ($i -gt 0) {
                $seg = Get-DistanceMeters ([double]$coords[$i - 1][1]) ([double]$coords[$i - 1][0]) $lat $lng
                if ($seg -eq 0) { $duplicates++ }
                if ($seg -gt $maxSeg) { $maxSeg = $seg; $maxSegAt = $i - 1 }
            }
        }

        if ($outside -gt 0) {
            $errors.Add("$tag : $outside titik di luar bbox Padang")
        }
        if ($duplicates -gt 0) {
            $warnings.Add("$tag : $duplicates titik berurutan yang sama persis")
        }
        if ($maxSeg -gt 800) {
            $warnings.Add(("{0} : segmen lurus {1:N0} m di titik #{2} (tambah titik agar mengikuti jalan)" -f $tag, $maxSeg, $maxSegAt))
        }

        # Ujung geometri OSRM untuk arah ini (bila tersedia), sebagai pembanding kedua.
        $osrmFirst = $null
        $osrmLast = $null
        if ($osrm) {
            $osrmCorridor = $osrm.PSObject.Properties[$corridor]
            if ($osrmCorridor) {
                $osrmDirection = $osrmCorridor.Value.PSObject.Properties[$direction]
                if ($osrmDirection -and $osrmDirection.Value.Count -ge 2) {
                    $osrmFirst = $osrmDirection.Value[0]
                    $osrmLast = $osrmDirection.Value[$osrmDirection.Value.Count - 1]
                }
            }
        }

        $stops = $directionData.halte
        $first = $stops[0]
        $last = $stops[$stops.Count - 1]
        $startHalteD = Get-DistanceMeters ([double]$coords[0][1]) ([double]$coords[0][0]) $first.lat $first.lng
        $endHalteD = Get-DistanceMeters ([double]$coords[$coords.Count - 1][1]) ([double]$coords[$coords.Count - 1][0]) $last.lat $last.lng

        $startOsrmD = $null
        $endOsrmD = $null
        if ($osrmFirst) {
            $startOsrmD = Get-DistanceMeters ([double]$coords[0][1]) ([double]$coords[0][0]) ([double]$osrmFirst[0]) ([double]$osrmFirst[1])
        }
        if ($osrmLast) {
            $endOsrmD = Get-DistanceMeters ([double]$coords[$coords.Count - 1][1]) ([double]$coords[$coords.Count - 1][0]) ([double]$osrmLast[0]) ([double]$osrmLast[1])
        }

        # Jarak efektif = yang terdekat di antara halte dan ujung OSRM.
        $startD = $startHalteD
        if ($null -ne $startOsrmD -and $startOsrmD -lt $startD) { $startD = $startOsrmD }
        $endD = $endHalteD
        if ($null -ne $endOsrmD -and $endOsrmD -lt $endD) { $endD = $endOsrmD }

        $startOsrmText = if ($null -ne $startOsrmD) { "{0:N0} m dari ujung OSRM" -f $startOsrmD } else { 'tanpa OSRM' }
        $endOsrmText = if ($null -ne $endOsrmD) { "{0:N0} m dari ujung OSRM" -f $endOsrmD } else { 'tanpa OSRM' }

        Write-Host ("   {0} titik, awal {1:N0} m dari '{2}' ({4}), akhir {3:N0} m dari '{5}' ({6}), segmen maks {7:N0} m" -f `
            $coords.Count, $startHalteD, $first.nama, $endHalteD, $startOsrmText, $last.nama, $endOsrmText, $maxSeg)

        $startChecks = @(@('awal', $startD, $startHalteD, $first.nama, $startOsrmD))
        $endChecks = @(@('akhir', $endD, $endHalteD, $last.nama, $endOsrmD))
        foreach ($pair in ($startChecks + $endChecks)) {
            $label = $pair[0]; $dist = [double]$pair[1]; $halteD = [double]$pair[2]; $stopName = $pair[3]; $osrmD = $pair[4]
            $detail = "halte '{0}' {1:N0} m" -f $stopName, $halteD
            if ($null -ne $osrmD) {
                $detail += (", ujung OSRM {0:N0} m" -f $osrmD)
            }
            if ($dist -gt $ErrorMeters) {
                $errors.Add(("{0} : {1} {2:N0} m dari titik acuan terdekat ({3})" -f $tag, $label, $dist, $detail))
            } elseif ($dist -gt $WarnMeters) {
                $warnings.Add(("{0} : {1} {2:N0} m dari titik acuan terdekat ({3})" -f $tag, $label, $dist, $detail))
            }
        }

        # Spur: garis menempuh jarak jauh lalu kembali ke titik yang hampir sama.
        # Hanya info, karena putaran balik sungguhan juga berbentuk demikian.
        $spurTotal = 0.0
        $spurAt = New-Object System.Collections.Generic.List[string]
        $i = 0
        while ($i -lt $coords.Count - 3) {
            $matched = $false
            for ($j = $i + 3; $j -lt $coords.Count; $j++) {
                $direct = Get-DistanceMeters ([double]$coords[$i][1]) ([double]$coords[$i][0]) ([double]$coords[$j][1]) ([double]$coords[$j][0])
                if ($direct -gt $SpurDirectMeters) { continue }
                $pathLen = 0.0
                for ($k = $i + 1; $k -le $j; $k++) {
                    $pathLen += Get-DistanceMeters ([double]$coords[$k - 1][1]) ([double]$coords[$k - 1][0]) ([double]$coords[$k][1]) ([double]$coords[$k][0])
                }
                if ($pathLen -gt $SpurLengthMeters) {
                    $spurTotal += $pathLen
                    $spurAt.Add(("#{0}-#{1} ({2:N0} m)" -f $i, $j, $pathLen))
                    $i = $j
                    $matched = $true
                    break
                }
            }
            if (-not $matched) { $i++ }
        }
        if ($spurAt.Count -gt 0) {
            $infos.Add(("{0} : {1:N0} m maju-mundur di {2} (bisa jadi putaran balik; cek visual)" -f `
                $tag, $spurTotal, ($spurAt -join ', ')))
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Peringatan ($($warnings.Count)):"
    $warnings | ForEach-Object { Write-Host "  ! $_" }
}

if ($infos.Count -gt 0) {
    Write-Host ""
    Write-Host "Info ($($infos.Count)):"
    $infos | ForEach-Object { Write-Host "  i $_" }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Galat ($($errors.Count)):"
    $errors | ForEach-Object { Write-Host "  x $_" }
    exit 1
}

Write-Host ""
Write-Host "OK: semua berkas valid."
exit 0
