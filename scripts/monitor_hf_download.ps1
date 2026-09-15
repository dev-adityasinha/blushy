param(
    [string]$ModelDir = "$env:USERPROFILE\.cache\huggingface\hub\models--facebook--m2m100_418M",
    [int64]$Expected = 1940000000
)

function Format-Bytes([long]$bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    return "$bytes B"
}

Write-Host "Monitoring model cache directory: $ModelDir"

while (-not (Test-Path $ModelDir)) {
    Write-Host "Waiting for model directory..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

while ($true) {
    $files = Get-ChildItem -Path $ModelDir -Filter "pytorch_model.bin*" -Recurse -ErrorAction SilentlyContinue
    $size = 0
    if ($files) { $size = ($files | Measure-Object -Property Length -Sum).Sum }
    $pct = 0
    if ($Expected -gt 0) { $pct = [math]::Min(100, [math]::Round((($size) / $Expected) * 100, 2)) }

    $status = "$(Format-Bytes $size) / $(Format-Bytes $Expected) ($pct%)"
    Write-Progress -Activity "Downloading model facebook/m2m100_418M" -Status $status -PercentComplete $pct

    if ($pct -ge 100) {
        Write-Host "Download appears complete. Files:"
        Get-ChildItem -Path $ModelDir -Filter "pytorch_model.bin*" -Recurse | Select-Object FullName, @{Name='Size';Expression={Format-Bytes $_.Length}}
        break
    }

    Start-Sleep -Seconds 2
}

Write-Host "Monitor finished." -ForegroundColor Green
