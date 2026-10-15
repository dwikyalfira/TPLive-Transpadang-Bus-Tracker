param(
    [string]$Source = (Join-Path $PSScriptRoot '..\assets\logo\tpl_app_icon_source.png'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\assets\logo')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Error "Sumber logo tidak ditemukan: $Source"
    exit 1
}

function Get-ContentBounds {
    param([System.Drawing.Bitmap]$Bitmap)
    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $minx = $w; $miny = $h; $maxx = -1; $maxy = -1
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 16) {
                if ($x -lt $minx) { $minx = $x }
                if ($x -gt $maxx) { $maxx = $x }
                if ($y -lt $miny) { $miny = $y }
                if ($y -gt $maxy) { $maxy = $y }
            }
        }
    }
    if ($maxx -lt 0) { throw 'Gambar sumber tidak punya area yang terlihat.' }
    return New-Object System.Drawing.Rectangle($minx, $miny, ($maxx - $minx + 1), ($maxy - $miny + 1))
}

function New-LogoAsset {
    param(
        [System.Drawing.Bitmap]$Master,
        [int]$Canvas,
        [double]$Fraction,
        [string]$Background,
        [string]$Path
    )
    $dst = New-Object System.Drawing.Bitmap($Canvas, $Canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        if ($Background) {
            $g.Clear([System.Drawing.ColorTranslator]::FromHtml($Background))
        } else {
            $g.Clear([System.Drawing.Color]::Transparent)
        }
        $size = [int][math]::Round($Canvas * $Fraction)
        $off = [int][math]::Floor(($Canvas - $size) / 2)
        $g.DrawImage($Master, $off, $off, $size, $size)
    } finally {
        $g.Dispose()
    }
    $dst.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
    $bgLabel = 'transparent'
    if ($Background) { $bgLabel = $Background }
    Write-Host ("  {0,-24} canvas={1} content={2:N1}% bg={3}" -f (Split-Path $Path -Leaf), $Canvas, ($Fraction * 100), $bgLabel)
}

$src = New-Object System.Drawing.Bitmap($Source)
try {
    $bounds = Get-ContentBounds $src
    Write-Host ("Sumber: {0} ({1}x{2}), konten {3}x{4}" -f (Split-Path $Source -Leaf), $src.Width, $src.Height, $bounds.Width, $bounds.Height)
    $master = $src.Clone($bounds, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
} finally {
    $src.Dispose()
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

# Proporsi mengikuti aset lama (lihat README / riwayat) agar tata letak identik.
$assets = @(
    @{ Name = 'tpl_logo_original.png';   Canvas = 1024; Fraction = 0.999; Bg = $null },
    @{ Name = 'app_icon.png';            Canvas = 1024; Fraction = 1.000; Bg = '#F47F38' },
    @{ Name = 'app_icon_fg.png';         Canvas = 1024; Fraction = 0.698; Bg = $null },
    @{ Name = 'adaptive_foreground.png'; Canvas = 1080; Fraction = 0.533; Bg = $null },
    @{ Name = 'legacy.png';              Canvas = 1024; Fraction = 0.583; Bg = $null },
    @{ Name = 'splash_pre12.png';        Canvas = 1152; Fraction = 0.619; Bg = $null },
    @{ Name = 'splash_a12.png';          Canvas = 1152; Fraction = 0.520; Bg = $null }
)

Write-Host 'Menulis aset logo:'
foreach ($a in $assets) {
    $out = Join-Path $OutDir $a.Name
    New-LogoAsset -Master $master -Canvas $a.Canvas -Fraction $a.Fraction -Background $a.Bg -Path $out
}

$master.Dispose()
Write-Host 'Selesai.'
