$ErrorActionPreference = "Stop"

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$root = $PSScriptRoot
$lhmArchive = Join-Path $root "Assets\LibreHardwareMonitor.zip"
if (-not (Test-Path -LiteralPath $lhmArchive)) {
    throw "LibreHardwareMonitor archive is missing at '$lhmArchive'."
}

$sevenZipCandidates = @()
if ($env:ProgramFiles) {
    $sevenZipCandidates += Join-Path $env:ProgramFiles "7-Zip\7z.exe"
}
if (${env:ProgramFiles(x86)}) {
    $sevenZipCandidates += Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe"
}
$sevenZip = $sevenZipCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $sevenZip) {
    throw "7-Zip command-line tools were not found. Install 7-Zip to build the runtime bundle."
}

$dependencyCommit = "3d331e3370efb858411f19511373eff65a218701"
$upstreamRoot = "https://raw.githubusercontent.com/LibreHardwareMonitor/LibreHardwareMonitor/$dependencyCommit"
$tempRoot = Join-Path $env:TEMP ("RylUtilsBundle-" + [guid]::NewGuid().ToString("N"))
$bundleRoot = Join-Path $tempRoot "bundle"
$archivePath = Join-Path $tempRoot "RylUtilsRuntimeResources.zip"
$bundlePath = Join-Path $root "RylUtilsRuntimeResources.zip"

try {
    $assetsDirectory = Join-Path $bundleRoot "Assets"
    $licensesDirectory = Join-Path $bundleRoot "Tools\LICENSES"
    $offlineDirectory = Join-Path $bundleRoot "offline_apps"
    New-Item -ItemType Directory -Path $assetsDirectory, $licensesDirectory, $offlineDirectory `
        -Force -ErrorAction Stop | Out-Null

    Copy-Item -LiteralPath $lhmArchive `
        -Destination (Join-Path $assetsDirectory "LibreHardwareMonitor.zip") `
        -Force -ErrorAction Stop

    Invoke-WebRequest -Uri "$upstreamRoot/LICENSE" `
        -OutFile (Join-Path $licensesDirectory "MPL-2.0.txt") `
        -UseBasicParsing -ErrorAction Stop
    Invoke-WebRequest -Uri "$upstreamRoot/THIRD-PARTY-NOTICES.txt" `
        -OutFile (Join-Path $licensesDirectory "THIRD-PARTY-NOTICES.txt") `
        -UseBasicParsing -ErrorAction Stop
    Set-Content -LiteralPath (Join-Path $licensesDirectory "NOTICE.txt") `
        -Value @(
            "LibreHardwareMonitor v0.9.6 runtime files."
            "Source: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/tree/$dependencyCommit"
            "See MPL-2.0.txt and THIRD-PARTY-NOTICES.txt for license terms."
        ) -Encoding UTF8 -ErrorAction Stop
    Set-Content -LiteralPath (Join-Path $assetsDirectory "README.txt") `
        -Value @(
            "Optional third-party app icons are not included in this public bundle."
            "RylUtils uses text glyphs when app icons are unavailable."
        ) -Encoding UTF8 -ErrorAction Stop
    Set-Content -LiteralPath (Join-Path $offlineDirectory "README.txt") `
        -Value @(
            "Third-party installers are not redistributed in this bundle."
            "Use WinGet or obtain installers directly from their publishers."
        ) -Encoding UTF8 -ErrorAction Stop

    Push-Location $bundleRoot
    try {
        & $sevenZip a -tzip -mx=9 -y $archivePath Assets Tools offline_apps
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip failed to create the runtime bundle (exit code $LASTEXITCODE)."
        }
    }
    finally {
        Pop-Location
    }

    Copy-Item -LiteralPath $archivePath -Destination $bundlePath -Force -ErrorAction Stop
    Get-Item -LiteralPath $bundlePath | Select-Object FullName, Length
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Stop
    }
}
