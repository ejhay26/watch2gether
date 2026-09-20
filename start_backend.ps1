Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Watch2Gether Server & Tunnel Launcher   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Set environment PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Program Files\Go\bin"

# 1. Start Backend Server
Set-Location -Path "$PSScriptRoot\backend"
Write-Host "Starting Go Backend Server on port 8080..." -ForegroundColor Green
$serverProcess = Start-Process -FilePath "$PSScriptRoot\backend\bin\server.exe" -PassThru -NoNewWindow

Start-Sleep -Seconds 2

# 2. Start Ngrok Tunnel
Write-Host "Starting Ngrok Tunnel to https://nuclei-oil-modular.ngrok-free.dev..." -ForegroundColor Green
$ngrokProcess = Start-Process -FilePath "ngrok" -ArgumentList "http", "--url=https://nuclei-oil-modular.ngrok-free.dev", "8080" -PassThru -NoNewWindow

Write-Host "Both Backend and Ngrok Tunnel are RUNNING." -ForegroundColor Cyan
Write-Host "Public URL: https://nuclei-oil-modular.ngrok-free.dev" -ForegroundColor Yellow
Write-Host "Local URL:  http://localhost:8080" -ForegroundColor Yellow
Write-Host "Press Ctrl+C or stop processes to exit." -ForegroundColor Gray

try {
    $serverProcess.WaitForExit()
} finally {
    Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue
    Stop-Process -Id $ngrokProcess.Id -ErrorAction SilentlyContinue
}
