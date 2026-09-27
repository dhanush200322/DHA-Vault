Add-Type -AssemblyName System.Drawing
$sourcePath = "c:\Users\ro224\OneDrive\Desktop\dha-vault\mobile\assets\branding\dha_vault_logo.png"
$srcImg = [System.Drawing.Image]::FromFile($sourcePath)

$targets = [ordered]@{
    "mobile\android\app\src\main\res\mipmap-mdpi\ic_launcher.png" = 48
    "mobile\android\app\src\main\res\mipmap-hdpi\ic_launcher.png" = 72
    "mobile\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" = 96
    "mobile\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" = 144
    "mobile\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" = 192
}

foreach ($entry in $targets.GetEnumerator()) {
    $path = $entry.Key
    $size = $entry.Value
    $fullPath = Join-Path "c:\Users\ro224\OneDrive\Desktop\dha-vault" $path
    $dest = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    $g.Dispose()
    $dest.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $dest.Dispose()
    Write-Host "Generated $path ($size x $size)"
}

$srcImg.Dispose()
Write-Host "All launcher icons generated successfully!"
