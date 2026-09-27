Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap('c:\Users\ro224\OneDrive\Desktop\dha-vault\mobile\assets\branding\dha_vault_logo.png')
$p = $bmp.GetPixel(5, 5)
Write-Output "R=$($p.R) G=$($p.G) B=$($p.B) A=$($p.A) Hex=#$($p.R.ToString('X2'))$($p.G.ToString('X2'))$($p.B.ToString('X2'))"
$bmp.Dispose()
