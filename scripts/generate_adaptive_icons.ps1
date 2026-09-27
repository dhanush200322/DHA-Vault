Add-Type -AssemblyName System.Drawing

$srcPath = "c:\Users\ro224\OneDrive\Desktop\dha-vault\mobile\assets\branding\dha_vault_logo.png"
$resDir = "c:\Users\ro224\OneDrive\Desktop\dha-vault\mobile\android\app\src\main\res"

$src = [System.Drawing.Image]::FromFile($srcPath)

# Generate Adaptive Foreground icons (108dp base)
$fgSizes = @{
    "mipmap-mdpi" = 108
    "mipmap-hdpi" = 162
    "mipmap-xhdpi" = 216
    "mipmap-xxhdpi" = 324
    "mipmap-xxxhdpi" = 432
}

foreach ($folder in $fgSizes.Keys) {
    $size = $fgSizes[$folder]
    $destFolder = Join-Path $resDir $folder
    if (-not (Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }
    
    $destPath = Join-Path $destFolder "ic_launcher_foreground.png"
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    
    # Safe zone scale (around 68% of size so nothing gets clipped by launcher mask)
    $shieldSize = [int]($size * 0.68)
    $offset = [int](($size - $shieldSize) / 2)
    
    $g.DrawImage($src, $offset, $offset, $shieldSize, $shieldSize)
    $g.Dispose()
    
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "Generated foreground: $destPath ($size x $size)"
}

$src.Dispose()
