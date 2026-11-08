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

# App Wear OS dibangun lebih dulu lalu di-bundle ke assets APK ponsel agar bisa
# dipasang ke jam dari Pengaturan (wireless debugging). Tanda tangannya sama
# dengan app ponsel (android/key.properties) supaya Data Layer tersambung.
Write-Host "Building app Wear OS (proyek Gradle terpisah: android/wear) ..."
Push-Location (Join-Path $root "android\wear")
try {
    & .\gradlew.bat :app:assembleRelease
    if (-not $?) { exit 1 }
}
finally {
    Pop-Location
}
$wearApk = Join-Path $root "android\wear\app\build\outputs\apk\release\app-release.apk"
$wearDest = Join-Path $root "android\app\src\main\assets\wear"
New-Item -ItemType Directory -Force -Path $wearDest | Out-Null
Copy-Item -LiteralPath $wearApk -Destination (Join-Path $wearDest "tplive-wear.apk") -Force

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
