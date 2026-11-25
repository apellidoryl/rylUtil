param(
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [Parameter(Mandatory = $true)][string]$ProgressPath
)

$ErrorActionPreference = "Stop"
$warnings = @()

function Write-ChangeProgress {
    param([int]$Percent, [string]$Detail, [string]$State = "Running")

    $record = [PSCustomObject]@{
        Percent = [math]::Min(100, [math]::Max(0, $Percent))
        Detail = $Detail
        State = $State
        Updated = Get-Date -Format "HH:mm:ss"
    }
    $temporaryPath = "$ProgressPath.$PID.tmp"
    $record | ConvertTo-Json -Compress |
        Set-Content -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
    Move-Item -LiteralPath $temporaryPath -Destination $ProgressPath -Force -ErrorAction Stop
}

function Save-JsonFile {
    param([string]$Path, [object]$Value)

    $temporaryPath = "$Path.$PID.tmp"
    $Value | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force -ErrorAction Stop
}

try {
    if (-not (Test-Path -LiteralPath $PlanPath)) {
        throw "The requested system-change plan was not found."
    }
    $plan = Get-Content -LiteralPath $PlanPath -Raw -ErrorAction Stop | ConvertFrom-Json
    $backupDirectory = Split-Path -Parent $PlanPath
    $root = [IO.Path]::GetFullPath([string]$plan.Root)
    $expectedRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    if (-not [string]::Equals($root, $expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The change plan does not belong to this application folder."
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "The application folder was not found."
    }
    $backupPrefix = (Join-Path $root "Backups") + [IO.Path]::DirectorySeparatorChar
    $fullPlanPath = [IO.Path]::GetFullPath($PlanPath)
    if (-not $fullPlanPath.StartsWith($backupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The change plan must be stored under the application's backup folder."
    }

    $validatedProfile = $null
    if ($plan.Kind -eq "ApplyDns") {
        . (Join-Path $root "Modules\Network.ps1")
        $profiles = @(Get-RylDnsProfiles -Root $root |
            Where-Object { $_.Id -eq [string]$plan.Profile.Id })
        if ($profiles.Count -ne 1) {
            throw "The DNS profile is not present in the application's profile catalog."
        }
        $validatedProfile = $profiles[0]
        if ($validatedProfile.Name -ne [string]$plan.Profile.Name -or
            ($validatedProfile.IPv4 -join "|") -ne (@($plan.Profile.IPv4) -join "|") -or
            ($validatedProfile.IPv6 -join "|") -ne (@($plan.Profile.IPv6) -join "|")) {
            throw "The DNS profile data does not match the saved profile catalog."
        }
    }

    if ($plan.Kind -eq "ApplyDns" -or $plan.Kind -eq "RestoreDns") {
        $adapter = Get-NetAdapter -InterfaceIndex ([int]$plan.InterfaceIndex) -ErrorAction Stop
        if ($adapter.Name -ne [string]$plan.AdapterName) {
            throw "The selected network adapter no longer matches the change plan."
        }
    }

    if ($plan.Kind -eq "RestoreDns") {
        $networkBackupPrefix = (Join-Path $root "Backups\Network") + [IO.Path]::DirectorySeparatorChar
        $snapshotFullPath = [IO.Path]::GetFullPath([string]$plan.SnapshotPath)
        if (-not $snapshotFullPath.StartsWith($networkBackupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "The DNS snapshot must come from this application's network backups."
        }
        $previousSnapshot = Get-Content -LiteralPath $snapshotFullPath -Raw -ErrorAction Stop |
            ConvertFrom-Json
        if ($previousSnapshot.Kind -ne "ApplyDns" -or -not $previousSnapshot.DNS) {
            throw "The selected backup does not contain a valid applied DNS profile."
        }
    }

    Write-ChangeProgress -Percent 3 -Detail "Saving settings and rollback information"
    foreach ($fileName in @("Config.xml", "Apps.xml", "Bloatware.xml")) {
        $source = Join-Path $root $fileName
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $backupDirectory -Force -ErrorAction Stop
        }
    }

    $snapshot = [ordered]@{
        Created = (Get-Date).ToString("o")
        Kind = [string]$plan.Kind
        Actions = @($plan.Actions)
        RemovedPackages = @()
        DNS = $null
    }

    if ($plan.Kind -eq "ApplyDns" -or $plan.Kind -eq "RestoreDns") {
        $adapterIndex = [int]$plan.InterfaceIndex
        $addresses = @(Get-DnsClientServerAddress -InterfaceIndex $adapterIndex -ErrorAction Stop)
        $snapshot.DNS = [ordered]@{
            InterfaceIndex = $adapterIndex
            AdapterName = [string]$plan.AdapterName
            IPv4 = @($addresses | Where-Object { $_.AddressFamily -eq 2 } |
                ForEach-Object { $_.ServerAddresses })
            IPv6 = @($addresses | Where-Object { $_.AddressFamily -eq 23 } |
                ForEach-Object { $_.ServerAddresses })
        }
    }

    if ($plan.Kind -eq "Optimize" -and @($plan.Actions) -contains "RemoveBloatware") {
        . (Join-Path $root "Modules\OptionalApps.ps1")
        $allowlistPath = Join-Path $root "Bloatware.xml"
        [xml]$allowlist = Get-Content -LiteralPath $allowlistPath -Raw -ErrorAction Stop
        $catalogNames = @($allowlist.OptionalApps.App | ForEach-Object {
            [string]$_.PackageName
        })
        $approvedOptionalPackages = @(Get-RylApprovedOptionalPackageNames)
        $protectedNames = @(
            "Microsoft.DesktopAppInstaller",
            "Microsoft.MicrosoftStore",
            "Microsoft.WindowsStore",
            "Microsoft.StorePurchaseApp",
            "Microsoft.SecHealthUI",
            "Microsoft.WindowsCalculator",
            "Microsoft.WindowsNotepad",
            "Microsoft.WindowsTerminal",
            "Microsoft.Windows.Photos"
        )
        $selectedNames = @($plan.PackageNames | Select-Object -Unique)
        $packageDetails = @()
        foreach ($packageName in $selectedNames) {
            if ($packageName -notin $catalogNames -or
                $packageName -notin $approvedOptionalPackages -or
                $packageName -in $protectedNames -or
                $packageName -match '^Microsoft\.Windows(\.|$)') {
                throw "Package '$packageName' is not eligible for removal."
            }
            $package = Get-AppxPackage -Name $packageName -ErrorAction Stop |
                Where-Object { $_.Name -eq $packageName } |
                Select-Object -First 1
            if (-not $package) {
                throw "Optional app '$packageName' is no longer installed."
            }
            $packageDetails += [PSCustomObject]@{
                PackageName = $package.Name
                PackageFullName = $package.PackageFullName
            }
        }
        $snapshot.RemovedPackages = $packageDetails
    }

    Save-JsonFile -Path (Join-Path $backupDirectory "Snapshot.json") -Value $snapshot

    if ($plan.CreateRestorePoint) {
        Write-ChangeProgress -Percent 10 -Detail "Creating Windows restore point"
        if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
            throw "Windows System Restore is unavailable; no changes were applied."
        }
        Checkpoint-Computer -Description "RylUtils system changes" `
            -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    } elseif ($plan.Kind -eq "Optimize" -and @($plan.Actions) -contains "RemoveBloatware") {
        throw "A restore point is required before removing optional apps."
    }

    if ($plan.Kind -eq "ApplyDns") {
        $profile = $validatedProfile
        Write-ChangeProgress -Percent 25 -Detail "Applying DNS profile to $($plan.AdapterName)"
        $dnsServers = @($profile.IPv4) + @($profile.IPv6)
        if ($dnsServers.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceIndex ([int]$plan.InterfaceIndex) `
                -ServerAddresses $dnsServers -ErrorAction Stop
        } else {
            Set-DnsClientServerAddress -InterfaceIndex ([int]$plan.InterfaceIndex) `
                -ResetServerAddresses -ErrorAction Stop
        }
        Clear-DnsClientCache -ErrorAction Stop
    } elseif ($plan.Kind -eq "RestoreDns") {
        $previous = $previousSnapshot
        $adapterIndex = [int]$previous.DNS.InterfaceIndex
        Write-ChangeProgress -Percent 25 -Detail "Restoring DNS settings"
        $dnsServers = @($previous.DNS.IPv4) + @($previous.DNS.IPv6)
        if ($dnsServers.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceIndex $adapterIndex `
                -ServerAddresses $dnsServers -ErrorAction Stop
        } else {
            Set-DnsClientServerAddress -InterfaceIndex $adapterIndex `
                -ResetServerAddresses -ErrorAction Stop
        }
        Clear-DnsClientCache -ErrorAction Stop
        $previousSnapshot | Add-Member -NotePropertyName Restored -NotePropertyValue $true -Force
        Save-JsonFile -Path $snapshotFullPath -Value $previousSnapshot
    } elseif ($plan.Kind -eq "Optimize") {
        $actions = @($plan.Actions | Select-Object -Unique)
        $stepCount = [math]::Max(1, $actions.Count)
        for ($step = 0; $step -lt $actions.Count; $step++) {
            $action = [string]$actions[$step]
            $basePercent = 15 + [int](75 * $step / $stepCount)
            switch ($action) {
                "FlushDns" {
                    Write-ChangeProgress -Percent $basePercent -Detail "Flushing DNS cache"
                    Clear-DnsClientCache -ErrorAction Stop
                }
                "CleanTemp" {
                    Write-ChangeProgress -Percent $basePercent -Detail "Scanning old temporary files"
                    $cutoff = (Get-Date).AddDays(-7)
                    $files = @(Get-ChildItem -LiteralPath $env:TEMP -File -Force -Recurse `
                        -ErrorAction Stop | Where-Object {
                            $_.LastWriteTime -lt $cutoff -and
                            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
                        })
                    $total = [math]::Max(1, $files.Count)
                    $removed = 0
                    $failed = 0
                    for ($index = 0; $index -lt $files.Count; $index++) {
                        try {
                            Remove-Item -LiteralPath $files[$index].FullName -Force -ErrorAction Stop
                            $removed++
                        }
                        catch {
                            $failed++
                            if ($warnings.Count -lt 3) {
                                $warnings += $_.Exception.Message
                            }
                        }
                        if (($index % 10) -eq 0 -or $index -eq ($files.Count - 1)) {
                            $percent = $basePercent + [int](70 * ($index + 1) / $total / $stepCount)
                            Write-ChangeProgress -Percent $percent `
                                -Detail "Processed $($index + 1) of $($files.Count) old files; removed $removed"
                        }
                    }
                    if ($files.Count -eq 0) {
                        Write-ChangeProgress -Percent ($basePercent + 10) `
                            -Detail "No old temporary files were found"
                    }
                    if ($failed -gt 0) {
                        $warnings += "$failed old temporary file(s) could not be removed."
                    }
                }
                "RemoveBloatware" {
                    $selectedPackages = @($snapshot.RemovedPackages)
                    for ($index = 0; $index -lt $selectedPackages.Count; $index++) {
                        $package = $selectedPackages[$index]
                        Write-ChangeProgress -Percent ($basePercent + [int](70 * $index / [math]::Max(1, $selectedPackages.Count))) `
                            -Detail "Removing $($package.PackageName)"
                        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                    }
                }
                default {
                    throw "Unknown optimization action '$action'."
                }
            }
        }
    } else {
        throw "Unknown system-change plan '$($plan.Kind)'."
    }

    $completionDetail = if ($warnings.Count -gt 0) {
        "Completed with warnings: $($warnings -join ' '); backup saved to $backupDirectory"
    } else {
        "Changes completed; backup saved to $backupDirectory"
    }
    Write-ChangeProgress -Percent 100 -Detail $completionDetail -State "Completed"
    exit 0
}
catch {
    try {
        Write-ChangeProgress -Percent 100 -Detail "Failed: $($_.Exception.Message)" -State "Failed"
    } catch { }
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
