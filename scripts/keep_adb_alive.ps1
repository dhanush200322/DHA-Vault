$adb = "adb"
if (Get-Command adb -ErrorAction SilentlyContinue) {
    $adb = "adb"
} elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe") {
    $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
} elseif (Test-Path "C:\platform-tools\platform-tools\adb.exe") {
    $adb = "C:\platform-tools\platform-tools\adb.exe"
}

Write-Host "Starting persistent ADB reverse daemon for port 4000 using $adb..."
while ($true) {
    try {
        & $adb reverse tcp:4000 tcp:4000 2>$null
    } catch {
        # ignore transient USB glitches
    }
    Start-Sleep -Seconds 2
}
