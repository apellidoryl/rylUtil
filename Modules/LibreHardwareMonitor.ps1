function Initialize-LibreHardwareMonitor {
    param([Parameter(Mandatory = $true)][string]$Root)

    $zip = Join-Path $Root "Assets\LibreHardwareMonitor.zip"
    $install = Join-Path $Root "Tools\LibreHardwareMonitor"
    $library = Join-Path $install "LibreHardwareMonitorLib.dll"

    if (-not (Test-Path -LiteralPath $library)) {
        if (-not (Test-Path -LiteralPath $zip)) {
            return [PSCustomObject]@{
                Success = $false
                Message = "LibreHardwareMonitor library and archive were not found."
            }
        }

        try {
            New-Item -ItemType Directory -Path $install -Force -ErrorAction Stop |
                Out-Null
            Expand-Archive -LiteralPath $zip -DestinationPath $install -Force -ErrorAction Stop
        }
        catch {
            return [PSCustomObject]@{
                Success = $false
                Message = "LibreHardwareMonitor extraction failed: $($_.Exception.Message)"
            }
        }
    }

    if (-not (Test-Path -LiteralPath $library)) {
        return [PSCustomObject]@{
            Success = $false
            Message = "LibreHardwareMonitorLib.dll was not found after extraction."
        }
    }

    [PSCustomObject]@{
        Success = $true
        Message = "LibreHardwareMonitor sensor library ready"
        Path = $library
    }
}
