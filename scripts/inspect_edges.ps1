Add-Type -AssemblyName System.Drawing

$srcPath = "c:\Users\ro224\OneDrive\Desktop\dha-vault\mobile\assets\branding\dha_vault_logo.png"
$bmp = New-Object System.Drawing.Bitmap($srcPath)
$width = $bmp.Width
$height = $bmp.Height

Write-Output "Dimensions: $width x $height"

# Check samples along edge and diagonals
for ($i = 0; $i -lt 10; $i++) {
    $x = [int]($i * $width / 10)
    $p = $bmp.GetPixel($x, 5)
    Write-Output "Top edge at x=$($x) : R=$($p.R) G=$($p.G) B=$($p.B)"
}
$bmp.Dispose()
