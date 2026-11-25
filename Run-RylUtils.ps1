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

$mainScript = Join-Path $sourceRoot "rylUtil-main\Main.ps1"
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
    -WorkingDirectory (Split-Path -Parent $mainScript) -WindowStyle Hidden `
    -ErrorAction Stop | Out-Null
