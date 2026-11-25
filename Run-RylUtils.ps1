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

& $mainScript
