# Runs the app on a USB-connected Android device against the local backend.
#
# The device cannot reach this machine over Wi-Fi: the network here isolates
# clients from each other, so a LAN address is refused even on the same subnet.
# `adb reverse` forwards the device's own localhost:3000 back over USB instead.
#
# It has to be re-run whenever the device reconnects -- including during some
# install cycles -- which is why the app intermittently reported that it could
# not reach the server. This script re-establishes it every time.

$ErrorActionPreference = 'Stop'

$device = (& adb devices | Select-String "`tdevice$")
if (-not $device) {
    Write-Error "No Android device connected. Plug it in and enable USB debugging."
}

& adb reverse --remove-all 2>$null | Out-Null
& adb reverse tcp:3000 tcp:3000 | Out-Null
Write-Host "adb reverse: device localhost:3000 -> this machine's :3000" -ForegroundColor Green

# Confirm the backend is actually up before launching, so a refused connection
# is reported here rather than as "cannot reach the server" inside the app.
try {
    $health = Invoke-WebRequest -Uri 'http://127.0.0.1:3000/health' -TimeoutSec 5 -UseBasicParsing
    Write-Host "backend /health: $($health.StatusCode)" -ForegroundColor Green
} catch {
    Write-Warning "Backend is not answering on http://127.0.0.1:3000 - start it with 'npm start' in backend/ first."
}

& flutter run
