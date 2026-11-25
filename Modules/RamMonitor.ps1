
function Get-RAMInfo {

    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop

    $total = [math]::Round(
        $os.TotalVisibleMemorySize / 1MB, 2
    )

    $free = [math]::Round(
        $os.FreePhysicalMemory / 1MB, 2
    )

    [PSCustomObject]@{
        Total = $total
        Free  = $free
        Used  = [math]::Round($total - $free, 2)
        Uptime = New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)
    }
}
