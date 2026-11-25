. "$PSScriptRoot\RamMonitor.ps1"
. "$PSScriptRoot\Temperature.ps1"

function Get-RylNetworkRates {
    param([object]$PreviousSample)

    $sampledAt = Get-Date
    try {
        $adapters = @(Get-NetAdapter -ErrorAction Stop |
            Where-Object { $_.Status -eq "Up" })
        $counters = @{}
        if ($adapters.Count -gt 0) {
            $statistics = @(Get-NetAdapterStatistics -Name @($adapters.Name) -ErrorAction Stop)
            foreach ($statistic in $statistics) {
                $counters[[string]$statistic.Name] = [PSCustomObject]@{
                    ReceivedBytes = [double]$statistic.ReceivedBytes
                    SentBytes = [double]$statistic.SentBytes
                }
            }
        }

        $downloadMbps = 0.0
        $uploadMbps = 0.0
        $hasRate = $false
        if ($PreviousSample -and $PreviousSample.Counters) {
            $elapsed = ($sampledAt - [datetime]$PreviousSample.SampledAt).TotalSeconds
            if ($elapsed -gt 0) {
                foreach ($name in $counters.Keys) {
                    if (-not $PreviousSample.Counters.ContainsKey($name)) {
                        continue
                    }

                    $current = $counters[$name]
                    $previous = $PreviousSample.Counters[$name]
                    $receivedDelta = if ($current.ReceivedBytes -ge $previous.ReceivedBytes) {
                        $current.ReceivedBytes - $previous.ReceivedBytes
                    } else {
                        $current.ReceivedBytes
                    }
                    $sentDelta = if ($current.SentBytes -ge $previous.SentBytes) {
                        $current.SentBytes - $previous.SentBytes
                    } else {
                        $current.SentBytes
                    }
                    $downloadMbps += ($receivedDelta * 8 / $elapsed / 1000000)
                    $uploadMbps += ($sentDelta * 8 / $elapsed / 1000000)
                }
                $hasRate = $true
            }
        }

        return [PSCustomObject]@{
            Sample = [PSCustomObject]@{
                SampledAt = $sampledAt
                Counters = $counters
            }
            DownloadMbps = if ($hasRate) { [math]::Round($downloadMbps, 2) } else { $null }
            UploadMbps = if ($hasRate) { [math]::Round($uploadMbps, 2) } else { $null }
            Adapters = @($adapters | ForEach-Object { [string]$_.Name })
            HasRate = $hasRate
            Error = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Sample = $PreviousSample
            DownloadMbps = $null
            UploadMbps = $null
            Adapters = @()
            HasRate = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-RylMonitorSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [object]$PreviousNetworkSample
    )

    $cpuName = "Unavailable"
    $cpuLoad = 0
    $ramTotal = 0
    $ramFree = 0
    $uptime = $null
    $temperature = $null
    $sensorName = "Unavailable"
    $diskTotal = 0
    $diskFree = 0
    $diskUsedPercent = 0
    $diskError = $null

    try {
        $processors = Get-CimInstance Win32_Processor -ErrorAction Stop
        $cpuName = $processors[0].Name
        $cpuLoad = [math]::Round(
            ($processors | Measure-Object LoadPercentage -Average).Average
        )
    }
    catch {
        $cpuName = "CPU query failed"
    }

    try {
        $ram = Get-RAMInfo
        $ramTotal = $ram.Total
        $ramFree = $ram.Free
        $uptime = $ram.Uptime
    }
    catch {
        $ramTotal = 0
        $ramFree = 0
    }

    try {
        $systemDrive = [Environment]::GetEnvironmentVariable("SystemDrive")
        $drive = Get-CimInstance Win32_LogicalDisk `
            -Filter ("DeviceID='{0}'" -f $systemDrive) -ErrorAction Stop |
            Select-Object -First 1
        if (-not $drive -or [double]$drive.Size -le 0) {
            throw "System drive '$systemDrive' could not be queried."
        }
        $diskTotal = [math]::Round([double]$drive.Size / 1GB, 1)
        $diskFree = [math]::Round([double]$drive.FreeSpace / 1GB, 1)
        $diskUsedPercent = [math]::Min(100, [math]::Max(
            0, [int](100 * ([double]$drive.Size - [double]$drive.FreeSpace) / [double]$drive.Size)
        ))
    }
    catch {
        $diskError = $_.Exception.Message
    }

    $network = Get-RylNetworkRates -PreviousSample $PreviousNetworkSample
    $temperatureData = Get-CPUTemperature -Root $Root -Detailed
    $temperature = $temperatureData.Temperature
    $sensorName = $temperatureData.Sensor

    $ramUsed = [math]::Round($ramTotal - $ramFree, 2)
    $ramPercent = if ($ramTotal -gt 0) {
        [math]::Min(100, [math]::Max(0, [int](100 * $ramUsed / $ramTotal)))
    } else {
        0
    }

    [PSCustomObject]@{
        CPU = [math]::Min(100, [math]::Max(0, [int]$cpuLoad))
        CPUName = $cpuName
        RAMTotal = $ramTotal
        RAMFree = $ramFree
        RAMUsed = $ramUsed
        RAMPercent = $ramPercent
        Uptime = $uptime
        DiskTotalGB = $diskTotal
        DiskFreeGB = $diskFree
        DiskUsedPercent = $diskUsedPercent
        DiskError = $diskError
        NetworkDownloadMbps = $network.DownloadMbps
        NetworkUploadMbps = $network.UploadMbps
        NetworkAdapters = $network.Adapters
        NetworkSample = $network.Sample
        NetworkHasRate = $network.HasRate
        NetworkError = $network.Error
        Temperature = $temperature
        Sensor = $sensorName
        TemperatureRequiresElevation = $temperatureData.RequiresElevation
        Time = Get-Date -Format "HH:mm:ss"
    }
}
