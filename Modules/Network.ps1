function Get-RylDnsProfiles {
    param([Parameter(Mandatory = $true)][string]$Root)

    $path = Join-Path $Root "DnsProfiles.xml"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "DNS profile catalog was not found: $path"
    }

    [xml]$catalog = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
    $profiles = @()
    $profileIds = @()
    foreach ($entry in $catalog.DnsProfiles.Profile) {
        $profileId = [string]$entry.Id
        $profileName = [string]$entry.Name
        if ([string]::IsNullOrWhiteSpace($profileId) -or
            [string]::IsNullOrWhiteSpace($profileName) -or
            $profileId -in $profileIds) {
            throw "DNS profile IDs and names must be non-empty and IDs must be unique in '$path'."
        }
        $profileIds += $profileId

        $ipv4 = @($entry.IPv4.Server | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        } | ForEach-Object { [string]$_ })
        $ipv6 = @($entry.IPv6.Server | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        } | ForEach-Object { [string]$_ })
        foreach ($address in $ipv4) {
            $parsed = $null
            if (-not [System.Net.IPAddress]::TryParse($address, [ref]$parsed) -or
                $parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
                throw "Invalid DNS server address '$address' in '$path'."
            }
        }
        foreach ($address in $ipv6) {
            $parsed = $null
            if (-not [System.Net.IPAddress]::TryParse($address, [ref]$parsed) -or
                $parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
                throw "Invalid DNS server address '$address' in '$path'."
            }
        }

        $profiles += [PSCustomObject]@{
            Id = $profileId
            Name = $profileName
            Description = [string]$entry.Description
            IPv4 = $ipv4
            IPv6 = $ipv6
        }
    }
    return $profiles
}

function Get-RylNetworkAdapters {
    $adapters = Get-NetAdapter -ErrorAction Stop |
        Where-Object { $_.Status -eq "Up" } |
        Sort-Object -Property InterfaceIndex

    return @($adapters | ForEach-Object {
        [PSCustomObject]@{
            InterfaceIndex = [int]$_.InterfaceIndex
            Name = [string]$_.Name
            Status = [string]$_.Status
        }
    })
}
