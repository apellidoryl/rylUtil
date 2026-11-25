
param(
    [switch]$HiddenLaunch
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot

if (-not $HiddenLaunch) {
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

    $quotedScript = '"' + $PSCommandPath.Replace('"', '""') + '"'
    $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $quotedScript -HiddenLaunch"
    Start-Process -FilePath $hostExecutable -ArgumentList $arguments `
        -WorkingDirectory $Root -WindowStyle Hidden -ErrorAction Stop | Out-Null
    return
}

function Write-RylStartupLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    $logPath = Join-Path $Root "Logs\startup.log"
    $logDirectory = Split-Path -Parent $logPath
    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop |
            Out-Null
    }
    Add-Content -LiteralPath $logPath `
        -Value ("{0} {1}" -f (Get-Date -Format "o"), $Message) `
        -Encoding UTF8 -ErrorAction Stop
}

try {
    . "$Root\Modules\LibreHardwareMonitor.ps1"
    $lhm = Initialize-LibreHardwareMonitor -Root $Root

    . "$Root\GUI\WpfMainWindow.ps1"
    $settings = Get-RylSettings -Root $Root
    Start-RylWpfGUI -Root $Root -Settings $settings -LHMStatus $lhm.Message
}
catch {
    $startupException = $_.Exception
    $startupError = "RylUtils could not start:`r`n$($startupException.Message)"
    try {
        Write-RylStartupLog -Message ("Startup failed: " + $startupException.ToString())
    }
    catch {
        $startupError += "`r`nStartup log could not be written: $($_.Exception.Message)"
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][Windows.Forms.MessageBox]::Show(
            $startupError,
            "RylUtils startup error",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        )
    }
    catch {
        [Console]::Error.WriteLine($startupError)
        [Console]::Error.WriteLine($_.Exception.Message)
    }
    throw
}