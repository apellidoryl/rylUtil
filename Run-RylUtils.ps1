& {
$ErrorActionPreference = "Stop"

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$installRoot = Join-Path $env:LOCALAPPDATA "RylUtils"
$sourceRoot = Join-Path $installRoot "source"
$archivePath = Join-Path $env:TEMP ("RylUtils-" + [guid]::NewGuid().ToString("N") + ".zip")
$archiveUri = "https://github.com/apellidoryl/rylUtil/archive/refs/heads/main.zip"

New-Item -ItemType Directory -Path $sourceRoot -Force -ErrorAction Stop | Out-Null

try {
    Invoke-WebRequest -Uri $archiveUri -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
    Expand-Archive -LiteralPath $archivePath -DestinationPath $sourceRoot -Force -ErrorAction Stop
}
finally {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction Stop
    }
}

$appRoot = Join-Path $sourceRoot "rylUtil-main"
$runtimeBundle = Join-Path $appRoot "RylUtilsRuntimeResources.zip"
if (-not (Test-Path -LiteralPath $runtimeBundle)) {
    throw "RylUtils runtime bundle was not found at '$runtimeBundle'."
}

try {
    Expand-Archive -LiteralPath $runtimeBundle -DestinationPath $appRoot -Force -ErrorAction Stop
}
finally {
    if (Test-Path -LiteralPath $runtimeBundle) {
        Remove-Item -LiteralPath $runtimeBundle -Force -ErrorAction Stop
    }
}

$lhmArchive = Join-Path $appRoot "Assets\LibreHardwareMonitor.zip"
if (-not (Test-Path -LiteralPath $lhmArchive)) {
    throw "LibreHardwareMonitor archive was not found at '$lhmArchive'."
}

$lhmInstall = Join-Path $appRoot "Tools\LibreHardwareMonitor"
New-Item -ItemType Directory -Path $lhmInstall -Force -ErrorAction Stop | Out-Null
try {
    Expand-Archive -LiteralPath $lhmArchive -DestinationPath $lhmInstall -Force -ErrorAction Stop
}
finally {
    if (Test-Path -LiteralPath $lhmArchive) {
        Remove-Item -LiteralPath $lhmArchive -Force -ErrorAction Stop
    }
}

$lhmLibrary = Join-Path $lhmInstall "LibreHardwareMonitorLib.dll"
if (-not (Test-Path -LiteralPath $lhmLibrary)) {
    throw "LibreHardwareMonitorLib.dll was not found after extraction at '$lhmLibrary'."
}

$mainScript = Join-Path $appRoot "Main.ps1"
if (-not (Test-Path -LiteralPath $mainScript)) {
    throw "RylUtils was downloaded, but Main.ps1 was not found at '$mainScript'."
}

$hostCandidates = @()
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $hostCandidates += Join-Path $env:WINDIR "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
}
$hostCandidates += Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$hostCandidates += Join-Path $PSHOME "powershell.exe"
$hostCandidates += Join-Path $PSHOME "pwsh.exe"
$hostExecutable = $hostCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $hostExecutable) {
    throw "Cannot find a PowerShell executable under '$PSHOME'."
}

$quotedScript = '"' + $mainScript.Replace('"', '""') + '"'
$arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $quotedScript -HiddenLaunch"
Start-Process -FilePath $hostExecutable -ArgumentList $arguments `
    -WorkingDirectory $appRoot -WindowStyle Hidden -Verb RunAs `
    -ErrorAction Stop | Out-Null
}
