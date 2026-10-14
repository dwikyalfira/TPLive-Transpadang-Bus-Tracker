param(
    [switch]$Install,
    [string]$Device
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$defines = Join-Path $root "dart_defines.json"

if (-not (Test-Path -LiteralPath $defines)) {
    Write-Error "dart_defines.json tidak ditemukan di $root. Buat file itu (lihat dart_defines.example.json) sebelum build."
    exit 1
}

Write-Host "Building release dengan defines dari dart_defines.json ..."
Push-Location $root
try {
    & flutter build apk --release --dart-define-from-file="$defines"
    if (-not $?) { exit 1 }
}
finally {
    Pop-Location
}

$apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
Write-Host "APK: $apk"

if ($Install) {
    $adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (-not (Test-Path -LiteralPath $adb)) {
        $adb = "adb"
    }

    $adbArgs = @("install", "-r", $apk)
    if ($Device) {
        $adbArgs = @("-s", $Device) + $adbArgs
    }

    Write-Host "Menginstal ke device ..."
    & $adb @adbArgs
}
