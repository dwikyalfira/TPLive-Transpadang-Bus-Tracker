# Memeriksa berkas GeoJSON koridor yang digambar manual di assets/routes/.
#
# Untuk tiap berkas:
#  - harus FeatureCollection dengan minimal satu fitur LineString (>= 2 titik);
#  - setiap fitur wajib punya properti corridor (K1..K6) dan direction (pergi/pulang);
#  - semua titik harus di dalam bbox Padang;
#  - titik awal/akhir dibandingkan dengan halte ujung arah tersebut.
#
# Keluar dengan kode 1 bila ada galat (warn tidak menggagalkan).
#
# Contoh: powershell -ExecutionPolicy Bypass -File scripts/validate_corridor_routes.ps1
param(
    [string]$RoutesDir = (Join-Path $PSScriptRoot '..\assets\routes'),
    [string]$HalteFile = (Join-Path $PSScriptRoot '..\assets\halte.json'),
    [double]$WarnMeters = 500,
    [double]$ErrorMeters = 2000
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
$files = Get-ChildItem -Path $RoutesDir -Filter '*.geojson' -ErrorAction SilentlyContinue

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

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

        $stops = $directionData.halte
        $first = $stops[0]
        $last = $stops[$stops.Count - 1]
        $startD = Get-DistanceMeters ([double]$coords[0][1]) ([double]$coords[0][0]) $first.lat $first.lng
        $endD = Get-DistanceMeters ([double]$coords[$coords.Count - 1][1]) ([double]$coords[$coords.Count - 1][0]) $last.lat $last.lng

        Write-Host ("   {0} titik, awal {1:N0} m dari '{2}', akhir {3:N0} m dari '{4}', segmen maks {5:N0} m" -f `
            $coords.Count, $startD, $first.nama, $endD, $last.nama, $maxSeg)

        foreach ($pair in @(@('awal', $startD, $first.nama), @('akhir', $endD, $last.nama))) {
            $label = $pair[0]; $dist = [double]$pair[1]; $stopName = $pair[2]
            if ($dist -gt $ErrorMeters) {
                $errors.Add(("{0} : {1} {2:N0} m dari halte '{3}' (maks {4:N0} m)" -f $tag, $label, $dist, $stopName, $ErrorMeters))
            } elseif ($dist -gt $WarnMeters) {
                $warnings.Add(("{0} : {1} {2:N0} m dari halte '{3}' (periksa apakah garis sudah mencapai terminal)" -f $tag, $label, $dist, $stopName))
            }
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Peringatan ($($warnings.Count)):"
    $warnings | ForEach-Object { Write-Host "  ! $_" }
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
