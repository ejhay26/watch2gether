param (
    [string]$Tag = "v1.0.7",
    [string]$ReleaseDir = "frontend/build/windows/x64/runner/Release",
    [string]$OutputDir = "release-artifacts"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Starting WiX MSI Packaging for Watch2Gether ($Tag) ==="

# 1. Locate WiX Toolset
$wixCandidates = @(
    "C:\Program Files (x86)\WiX Toolset v3.14\bin",
    "C:\Program Files\WiX Toolset v3.14\bin",
    "C:\Program Files (x86)\WiX Toolset v3.11\bin",
    "C:\Program Files\WiX Toolset v3.11\bin"
)

foreach ($dir in $wixCandidates) {
    if (Test-Path $dir) {
        if ($env:PATH -notlike "*$dir*") {
            $env:PATH = "$dir;$env:PATH"
        }
        break
    }
}

$candle = (Get-Command candle.exe -ErrorAction SilentlyContinue)?.Source
$light = (Get-Command light.exe -ErrorAction SilentlyContinue)?.Source
$heat = (Get-Command heat.exe -ErrorAction SilentlyContinue)?.Source

if (-not $candle -or -not $light -or -not $heat) {
    Write-Host "WiX Toolset not found in PATH. Attempting installation via choco..."
    try {
        choco install wixtoolset -y --no-progress
        foreach ($dir in $wixCandidates) {
            if (Test-Path $dir) {
                $env:PATH = "$dir;$env:PATH"
                break
            }
        }
        $candle = (Get-Command candle.exe -ErrorAction SilentlyContinue)?.Source
        $light = (Get-Command light.exe -ErrorAction SilentlyContinue)?.Source
        $heat = (Get-Command heat.exe -ErrorAction SilentlyContinue)?.Source
    } catch {
        Write-Warning "Could not install WiX Toolset automatically: $_"
    }
}

if (-not $candle -or -not $light -or -not $heat) {
    throw "WiX Toolset (candle, light, heat) is not available to build the MSI package."
}

# 2. Normalize version string (e.g. v1.0.7 -> 1.0.7)
$version = $Tag.TrimStart('v')
if ($version -notmatch '^\d+\.\d+\.\d+') {
    $version = "1.0.0"
}
$parts = $version.Split('.')
if ($parts.Length -eq 2) {
    $version = "$version.0"
} elseif ($parts.Length -gt 3) {
    $version = "$($parts[0]).$($parts[1]).$($parts[2])"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Normalize paths to absolute Windows paths with backslashes
$ReleaseDir = [System.IO.Path]::GetFullPath($ReleaseDir).TrimEnd('\', '/')
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir).TrimEnd('\', '/')
$scriptDir = [System.IO.Path]::GetFullPath($scriptDir).TrimEnd('\', '/')

# 3. Harvest files from Release folder
Write-Host "Harvesting files from $ReleaseDir..."
& $heat dir "$ReleaseDir" -cg AppFiles -dr INSTALLFOLDER -gg -scom -sreg -sfrag -srd -var "var.SourceDir" -out "$scriptDir\files.wxs"

if ($LASTEXITCODE -ne 0) {
    throw "heat.exe failed with exit code $LASTEXITCODE"
}

# 4. Compile WiX objects with candle (-arch x64 is valid for candle)
Write-Host "Compiling WiX components..."
& $candle -arch x64 -dProductVersion="$version" -dSourceDir="$ReleaseDir" -dProjectDir="$scriptDir" "$scriptDir\watch2gether.wxs" "$scriptDir\files.wxs" -out "$scriptDir\"

if ($LASTEXITCODE -ne 0) {
    throw "candle.exe failed with exit code $LASTEXITCODE"
}

# 5. Link MSI with light (-arch is NOT valid for light, use -b to specify base directory)
$targetMsiTagged = "$OutputDir\watch2gether-windows-x64-$Tag.msi"
$targetMsiLatest = "$OutputDir\watch2gether-windows-x64.msi"

Write-Host "Linking MSI package: $targetMsiTagged..."
& $light -sval -ext WixUIExtension -b "$ReleaseDir" "$scriptDir\watch2gether.wixobj" "$scriptDir\files.wixobj" -o "$targetMsiTagged"

if ($LASTEXITCODE -ne 0) {
    throw "light.exe failed with exit code $LASTEXITCODE"
}

Copy-Item "$targetMsiTagged" "$targetMsiLatest" -Force
Write-Host "Successfully generated MSI installers: $targetMsiTagged and $targetMsiLatest"
