# test_resize.ps1
Write-Host "PS2EXE Conhost Test Script"
Write-Host "Attempting to resize window to 120x35..."
try {
    $desiredSize = New-Object System.Management.Automation.Host.Size(120, 35)
    $Host.UI.RawUI.WindowSize = $desiredSize
    Start-Sleep -Milliseconds 100 # Give a moment for the resize to apply if it's going to
    $currentSize = $Host.UI.RawUI.WindowSize
    Write-Host "Desired size: 120x35. Actual size: $($currentSize.Width)x$($currentSize.Height)"
    if ($currentSize.Width -eq 120 -and $currentSize.Height -eq 35) {
        Write-Host "SUCCESS: Window resized as expected."
    } else {
        Write-Host "NOTE: Window did not resize as expected. This is normal in Windows Terminal."
    }
} catch {
    Write-Host "ERROR: Failed to set window size. $_"
}
Write-Host "Script finished. Press Enter to exit."
Read-Host
