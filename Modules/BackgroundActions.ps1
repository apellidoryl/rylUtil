function Get-RylWingetPath {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $aliasPath) {
        return $aliasPath
    }

    $package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller `
        -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
    if ($package -and -not [string]::IsNullOrWhiteSpace($package.InstallLocation)) {
        $packagePath = Join-Path $package.InstallLocation "winget.exe"
        if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
            return $packagePath
        }
    }

    return $null
}

function Write-RylActionProgress {
    param(
        [string]$ProgressPath,
        [int]$Percent,
        [string]$Detail,
        [string]$State = "Running"
    )

    if ([string]::IsNullOrWhiteSpace($ProgressPath)) {
        return
    }

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

function Test-RylActionCancellationRequested {
    param([string]$CancelPath)

    return -not [string]::IsNullOrWhiteSpace($CancelPath) -and
        (Test-Path -LiteralPath $CancelPath -PathType Leaf)
}

function Invoke-RylWingetCommand {
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$ProgressPath,
        [Parameter(Mandatory = $true)][string]$ActionName,
        [string]$OutputDirectory,
        [int]$ProgressStart = 0,
        [int]$ProgressEnd = 100
    )

    if ($ProgressStart -lt 0 -or $ProgressEnd -gt 100 -or
        $ProgressEnd -lt $ProgressStart) {
        throw "The requested progress range is invalid."
    }

    $progressRange = $ProgressEnd - $ProgressStart
    $token = [guid]::NewGuid().ToString("N")
    $stdoutPath = Join-Path $env:TEMP "RylUtils-$token-out.txt"
    $stderrPath = Join-Path $env:TEMP "RylUtils-$token-err.txt"
    $statusPath = Join-Path $env:TEMP "RylUtils-$token-status.json"
    try {
        $initialPercent = $ProgressStart + [int][math]::Floor($progressRange * 5 / 100)
        Write-RylActionProgress -ProgressPath $ProgressPath -Percent $initialPercent `
            -Detail "${ActionName}: contacting WinGet"
        $powerShellPath = Join-Path $PSHOME "powershell.exe"
        if (-not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) {
            throw "Windows PowerShell executable was not found at '$powerShellPath'."
        }
        $encodedWingetPath = [Convert]::ToBase64String(
            [Text.Encoding]::Unicode.GetBytes($WingetPath)
        )
        $argumentJson = ConvertTo-Json -InputObject @($Arguments) -Compress
        $encodedArgumentJson = [Convert]::ToBase64String(
            [Text.Encoding]::Unicode.GetBytes($argumentJson)
        )
        $encodedStatusPath = [Convert]::ToBase64String(
            [Text.Encoding]::Unicode.GetBytes($statusPath)
        )
        $workerScript = @"
`$ErrorActionPreference = 'Stop'
`$statusPath = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encodedStatusPath'))
try {
    `$wingetPath = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encodedWingetPath'))
    `$argumentJson = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encodedArgumentJson'))
    `$nativeArguments = @([string[]](ConvertFrom-Json -InputObject `$argumentJson -ErrorAction Stop))
    & `$wingetPath @nativeArguments
    `$exitCode = `$LASTEXITCODE
    if (`$null -eq `$exitCode) {
        throw 'WinGet did not return an exit code.'
    }
    `$status = [PSCustomObject]@{ ExitCode = [int]`$exitCode; Detail = '' }
} catch {
    `$status = [PSCustomObject]@{ ExitCode = 1; Detail = `$_.Exception.Message }
}
`$status | ConvertTo-Json -Compress |
    Set-Content -LiteralPath `$statusPath -Encoding UTF8 -ErrorAction Stop
"@
        $encodedWorkerScript = [Convert]::ToBase64String(
            [Text.Encoding]::Unicode.GetBytes($workerScript)
        )
        $process = Start-Process -FilePath $powerShellPath `
            -ArgumentList "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedWorkerScript" `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
            -PassThru -WindowStyle Hidden -ErrorAction Stop
        $lastDetail = "${ActionName}: waiting for WinGet"
        $lastPercent = 8
        while (-not $process.HasExited) {
            $output = ""
            if (Test-Path -LiteralPath $stdoutPath) {
                $output += Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
            }
            if (Test-Path -LiteralPath $stderrPath) {
                $output += "`n" + (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue)
            }

            $matches = [regex]::Matches($output, '(?<!\d)(\d{1,3})\s*%')
            if ($matches.Count -gt 0) {
                $reported = [int]$matches[$matches.Count - 1].Groups[1].Value
                $lastPercent = [math]::Min(95, [math]::Max($lastPercent, $reported))
            }
            $lines = @($output -split '[\r\n]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($lines.Count -gt 0) {
                $lastDetail = ([string]$lines[-1]).Trim()
                if ($lastDetail.Length -gt 100) {
                    $lastDetail = $lastDetail.Substring(0, 100)
                }
            }
            $mappedPercent = $ProgressStart + [int][math]::Floor($progressRange * $lastPercent / 100)
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent $mappedPercent `
                -Detail $lastDetail
            Start-Sleep -Milliseconds 500
            $process.Refresh()
        }
        $process.WaitForExit()

        $finalOutput = ""
        if (Test-Path -LiteralPath $stdoutPath) {
            $finalOutput += Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $finalOutput += "`n" + (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue)
        }
        if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
            throw "WinGet worker did not report an exit status. $finalOutput"
        }
        $workerStatus = Get-Content -LiteralPath $statusPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $workerStatus.ExitCode) {
            throw "WinGet worker returned an invalid exit status. $finalOutput"
        }
        if ([int]$workerStatus.ExitCode -ne 0) {
            $tail = @($finalOutput -split "`r?`n" |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Last 3) -join " "
            throw "WinGet failed for $PackageId (exit code $($workerStatus.ExitCode)). $($workerStatus.Detail) $tail"
        }

        $destination = if ($OutputDirectory) { " to $OutputDirectory" } else { "" }
        Write-RylActionProgress -ProgressPath $ProgressPath -Percent $ProgressEnd `
            -Detail "$ActionName completed$destination" -State "Completed"
        return "$ActionName completed$destination."
    }
    finally {
        foreach ($path in @($stdoutPath, $stderrPath, $statusPath)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            }
        }
    }
}

function Get-RylWingetInstalledPackageIds {
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath,
        [string]$ProgressPath
    )

    $exportPath = Join-Path $env:TEMP `
        ("RylUtils-installed-{0}.json" -f [guid]::NewGuid().ToString("N"))
    try {
        $arguments = @(
            "export", "--output", $exportPath, "--include-versions",
            "--accept-source-agreements", "--disable-interactivity", "--ignore-warnings"
        )
        [void](Invoke-RylWingetCommand -WingetPath $WingetPath `
            -Arguments $arguments -PackageId "installed app inventory" `
            -ProgressPath $ProgressPath -ActionName "Checking installed applications")
        if (-not (Test-Path -LiteralPath $exportPath -PathType Leaf)) {
            throw "WinGet did not create its installed-app export file."
        }

        $export = Get-Content -LiteralPath $exportPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
        $packageIds = @($export.Sources |
            ForEach-Object { $_.Packages } |
            ForEach-Object { [string]$_.PackageIdentifier } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique)
        return $packageIds
    } finally {
        if (Test-Path -LiteralPath $exportPath) {
            Remove-Item -LiteralPath $exportPath -Force -ErrorAction Stop
        }
    }
}

function Get-RylQuickSetupPackageIds {
    return @(
        "Brave.Brave",
        "Google.Chrome",
        "Microsoft.Office",
        "Adobe.Acrobat.Reader.64-bit",
        "Zoom.Zoom",
        "IObit.DriverBooster",
        "VideoLAN.VLC",
        "7zip.7zip"
    )
}

function Get-RylQuickSetupInstallerPath {
    param(
        [Parameter(Mandatory = $true)][string]$OfflineDirectory,
        [Parameter(Mandatory = $true)][string]$PackageId
    )

    if ($PackageId -notin (Get-RylQuickSetupPackageIds)) {
        throw "Package '$PackageId' is not part of the quick-setup allowlist."
    }
    $packageDirectory = Join-Path $OfflineDirectory $PackageId
    if ($PackageId -eq "Microsoft.Office" -and
        (Test-Path -LiteralPath $packageDirectory -PathType Container)) {
        $setup = Get-ChildItem -LiteralPath $packageDirectory -File -Recurse `
            -Filter "setup.exe" -ErrorAction Stop |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1
        if ($setup) {
            return $setup.FullName
        }
    }

    if ($PackageId -ne "Microsoft.Office" -and
        (Test-Path -LiteralPath $packageDirectory -PathType Container)) {
        $installer = Get-ChildItem -LiteralPath $packageDirectory -File -Recurse `
            -ErrorAction Stop |
            Where-Object { $_.Extension -in @(".exe", ".msi") } |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1
        if ($installer) {
            return $installer.FullName
        }
    }

    $rootInstallerPatterns = @{
        "Brave.Brave" = @("BraveBrowserSetup*.exe")
        "Google.Chrome" = @("ChromeSetup.exe")
        "Microsoft.Office" = @("OfficeSetup.exe")
        "Adobe.Acrobat.Reader.64-bit" = @("Reader_en_install.exe")
        "Zoom.Zoom" = @("ZoomInstallerFull.exe")
        "IObit.DriverBooster" = @("driver_booster_setup.exe")
        "7zip.7zip" = @("7z*-x64.exe")
    }
    if (Test-Path -LiteralPath $OfflineDirectory -PathType Container) {
        foreach ($pattern in $rootInstallerPatterns[$PackageId]) {
            $installer = Get-ChildItem -LiteralPath $OfflineDirectory -File `
                -Filter $pattern -ErrorAction Stop |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 1
            if ($installer) {
                return $installer.FullName
            }
        }
    }

    throw "No supported installer for '$PackageId' was found in '$packageDirectory' or '$OfflineDirectory'."
}

function Invoke-RylOfficeOfflineSourceDownload {
    param(
        [Parameter(Mandatory = $true)][string]$SetupPath,
        [Parameter(Mandatory = $true)][string]$PackageDirectory,
        [Parameter(Mandatory = $true)][string]$ProgressPath,
        [int]$ProgressStart,
        [int]$ProgressEnd
    )

    $sourceDirectory = Join-Path $PackageDirectory "OfficeSource"
    New-Item -ItemType Directory -Path $sourceDirectory -Force -ErrorAction Stop |
        Out-Null
    $downloadConfigPath = Join-Path $PackageDirectory "office-download.xml"
    $installConfigPath = Join-Path $PackageDirectory "office-install.xml"
    $escapedSource = [System.Security.SecurityElement]::Escape($sourceDirectory)
    $downloadConfig = @"
<Configuration>
  <Add SourcePath="$escapedSource" OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
</Configuration>
"@
    $installConfig = @"
<Configuration>
  <Add SourcePath="$escapedSource" OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
  <Display Level="Full" AcceptEULA="FALSE" />
</Configuration>
"@
    $downloadConfig | Set-Content -LiteralPath $downloadConfigPath `
        -Encoding UTF8 -ErrorAction Stop
    $installConfig | Set-Content -LiteralPath $installConfigPath `
        -Encoding UTF8 -ErrorAction Stop

    $progressRange = $ProgressEnd - $ProgressStart
    $runningPercent = $ProgressStart + [int][math]::Floor($progressRange * 0.65)
    Write-RylActionProgress -ProgressPath $ProgressPath -Percent $runningPercent `
        -Detail "Downloading full Microsoft 365 Apps offline source; Microsoft setup does not report a percentage"
    $quotedConfig = '"' + $downloadConfigPath.Replace('"', '""') + '"'
    $process = Start-Process -FilePath $SetupPath `
        -ArgumentList "/download $quotedConfig" `
        -WorkingDirectory $PackageDirectory -PassThru -WindowStyle Hidden `
        -ErrorAction Stop
    while (-not $process.HasExited) {
        Start-Sleep -Seconds 2
        $process.Refresh()
        if (-not $process.HasExited) {
            Write-RylActionProgress -ProgressPath $ProgressPath `
                -Percent $runningPercent `
                -Detail "Downloading full Microsoft 365 Apps offline source; Microsoft setup does not report a percentage"
        }
    }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "Microsoft 365 offline source download failed (setup.exe exit code $($process.ExitCode))."
    }

    $officeDataDirectory = Join-Path $sourceDirectory "Office\Data"
    if (-not (Test-Path -LiteralPath $officeDataDirectory -PathType Container) -or
        -not (Get-ChildItem -LiteralPath $officeDataDirectory -Force -ErrorAction Stop |
            Select-Object -First 1)) {
        throw "Microsoft setup exited successfully but did not create the expected offline Office data."
    }
    Write-RylActionProgress -ProgressPath $ProgressPath -Percent $ProgressEnd `
        -Detail "Full Microsoft 365 Apps offline source prepared in $sourceDirectory"
}

function Start-RylQuickSetupInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$InstallerPath,
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$OfflineDirectory
    )

    $workingDirectory = Split-Path -Parent $InstallerPath
    if ($PackageId -eq "Microsoft.Office" -and
        [IO.Path]::GetFileName($InstallerPath) -ieq "setup.exe") {
        $officeSource = Join-Path (Join-Path $OfflineDirectory $PackageId) "OfficeSource\Office\Data"
        $installConfig = Join-Path (Join-Path $OfflineDirectory $PackageId) "office-install.xml"
        if (-not (Test-Path -LiteralPath $officeSource -PathType Container) -or
            -not (Test-Path -LiteralPath $installConfig -PathType Leaf)) {
            throw "The full Office offline source is missing. Download Microsoft 365 from the Quick Setup page first."
        }
        $arguments = '/configure "' + $installConfig.Replace('"', '""') + '"'
        return Start-Process -FilePath $InstallerPath -ArgumentList $arguments `
            -WorkingDirectory $workingDirectory -Verb RunAs -PassThru `
            -WindowStyle Normal -ErrorAction Stop
    }

    if ([IO.Path]::GetExtension($InstallerPath) -eq ".msi") {
        $msiexec = Join-Path $env:WINDIR "System32\msiexec.exe"
        $arguments = '/i "' + $InstallerPath.Replace('"', '""') + '"'
        return Start-Process -FilePath $msiexec -ArgumentList $arguments `
            -WorkingDirectory $workingDirectory -Verb RunAs -PassThru `
            -WindowStyle Normal -ErrorAction Stop
    }

    return Start-Process -FilePath $InstallerPath -WorkingDirectory $workingDirectory `
        -Verb RunAs -PassThru -WindowStyle Normal -ErrorAction Stop
}

function Invoke-RylBackgroundAction {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$PackageId,
        [string[]]$PackageIds = @(),
        [string]$OfflineDirectory,
        [bool]$DisableAutomaticUpdates = $false,
        [string]$ProgressPath,
        [string]$PlanPath,
        [ValidateSet("Sequence", "Parallel")][string]$InstallMode = "Sequence",
        [string]$CancelPath
    )

    switch ($Action) {
        "CheckWinget" {
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 5 `
                -Detail "Checking WinGet availability"
            $wingetPath = Get-RylWingetPath
            if (-not $wingetPath) {
                Write-RylActionProgress -ProgressPath $ProgressPath -Percent 35 `
                    -Detail "Checking Microsoft App Installer registration"
                $package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller `
                    -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($package) {
                    Write-RylActionProgress -ProgressPath $ProgressPath -Percent 65 `
                        -Detail "App Installer is registered, but its WinGet executable was not found"
                }
            }
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                -Detail $(if ($wingetPath) { "WinGet is ready" } else { "WinGet is unavailable" }) `
                -State "Completed"
            return [PSCustomObject]@{
                Available = [bool]$wingetPath
                StoreRequired = -not [bool]$wingetPath
            }
        }
        "CheckInstalledApps" {
            $wingetPath = Get-RylWingetPath
            if (-not $wingetPath) {
                throw "WinGet is not installed. Install Microsoft App Installer first."
            }
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 10 `
                -Detail "Reading installed package IDs from WinGet"
            $packageIds = @(Get-RylWingetInstalledPackageIds `
                -WingetPath $wingetPath -ProgressPath $ProgressPath)
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                -Detail "Detected $($packageIds.Count) WinGet-managed installed apps" `
                -State "Completed"
            return [PSCustomObject]@{
                PackageIds = $packageIds
                Count = $packageIds.Count
            }
        }
        "InstallApp" {
            $wingetPath = Get-RylWingetPath
            if (-not $wingetPath) {
                throw "WinGet is not installed. Install Microsoft App Installer first."
            }
            if ($PackageId -notmatch '^[A-Za-z0-9._+-]+$') {
                throw "Invalid WinGet package ID '$PackageId'."
            }
            $arguments = @(
                "install", "--id", $PackageId, "--exact", "--source", "winget",
                "--silent", "--accept-package-agreements", "--accept-source-agreements"
            )
            return Invoke-RylWingetCommand -WingetPath $wingetPath -Arguments $arguments `
                -PackageId $PackageId -ProgressPath $ProgressPath -ActionName "Installing $PackageId"
        }
        "UninstallApp" {
            $wingetPath = Get-RylWingetPath
            if (-not $wingetPath) {
                throw "WinGet is not installed. Install Microsoft App Installer first."
            }
            if ($PackageId -notmatch '^[A-Za-z0-9._+-]+$') {
                throw "Invalid WinGet package ID '$PackageId'."
            }
            $arguments = @(
                "uninstall", "--id", $PackageId, "--exact",
                "--accept-source-agreements", "--disable-interactivity"
            )
            return Invoke-RylWingetCommand -WingetPath $wingetPath -Arguments $arguments `
                -PackageId $PackageId -ProgressPath $ProgressPath -ActionName "Uninstalling $PackageId"
        }
        "DownloadOfflineApp" {
            $wingetPath = Get-RylWingetPath
            if (-not $wingetPath) {
                throw "WinGet is not installed. Install Microsoft App Installer first."
            }

            if ([string]::IsNullOrWhiteSpace($OfflineDirectory)) {
                throw "The offline installer folder is not configured."
            }
            $packageDirectory = Join-Path $OfflineDirectory $PackageId
            New-Item -ItemType Directory -Path $packageDirectory -Force -ErrorAction Stop |
                Out-Null

            if ($PackageId -notmatch '^[A-Za-z0-9._+-]+$') {
                throw "Invalid WinGet package ID '$PackageId'."
            }
            $arguments = @(
                "download", "--id", $PackageId, "--exact", "--source", "winget",
                "--download-directory", $packageDirectory,
                "--accept-package-agreements", "--accept-source-agreements"
            )
            return Invoke-RylWingetCommand -WingetPath $wingetPath -Arguments $arguments `
                -PackageId $PackageId -ProgressPath $ProgressPath `
                -ActionName "Downloading $PackageId installer" -OutputDirectory $packageDirectory
        }
        "DownloadQuickSetupApps" {
            if ([string]::IsNullOrWhiteSpace($OfflineDirectory)) {
                throw "The offline installer folder is not configured."
            }
            $selectedIds = @($PackageIds | Select-Object -Unique)
            if ($selectedIds.Count -eq 0) {
                throw "Select at least one quick-setup app to download."
            }
            $allowedIds = Get-RylQuickSetupPackageIds
            foreach ($id in $selectedIds) {
                if ($id -notin $allowedIds) {
                    throw "Package '$id' is not part of the quick-setup allowlist."
                }
            }
            $wingetPath = Get-RylWingetPath
            if (-not $wingetPath) {
                throw "WinGet is not installed. Install Microsoft App Installer first."
            }

            New-Item -ItemType Directory -Path $OfflineDirectory -Force -ErrorAction Stop |
                Out-Null
            $results = @()
            for ($index = 0; $index -lt $selectedIds.Count; $index++) {
                $id = [string]$selectedIds[$index]
                $packageDirectory = Join-Path $OfflineDirectory $id
                New-Item -ItemType Directory -Path $packageDirectory -Force -ErrorAction Stop |
                    Out-Null
                $progressStart = [int][math]::Floor(100 * $index / $selectedIds.Count)
                $progressEnd = [int][math]::Floor(100 * ($index + 1) / $selectedIds.Count)
                $installerEnd = if ($id -eq "Microsoft.Office") {
                    $progressStart + [int][math]::Max(1, [math]::Floor(
                        ($progressEnd - $progressStart) * 0.35
                    ))
                } else {
                    $progressEnd
                }
                $arguments = @(
                    "download", "--id", $id, "--exact", "--source", "winget",
                    "--download-directory", $packageDirectory,
                    "--accept-package-agreements", "--accept-source-agreements"
                )
                $actionName = "Downloading $id installer ($($index + 1) of $($selectedIds.Count))"
                [void](Invoke-RylWingetCommand -WingetPath $wingetPath `
                    -Arguments $arguments -PackageId $id -ProgressPath $ProgressPath `
                    -ActionName $actionName -OutputDirectory $packageDirectory `
                    -ProgressStart $progressStart -ProgressEnd $installerEnd)

                if ($id -eq "Microsoft.Office") {
                    $setupPath = Get-RylQuickSetupInstallerPath `
                        -OfflineDirectory $OfflineDirectory -PackageId $id
                    Invoke-RylOfficeOfflineSourceDownload -SetupPath $setupPath `
                        -PackageDirectory $packageDirectory -ProgressPath $ProgressPath `
                        -ProgressStart $installerEnd -ProgressEnd $progressEnd
                    $results += "Microsoft 365 Apps offline source prepared"
                } else {
                    $results += "$id downloaded"
                }
            }
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                -Detail ($results -join "; ") -State "Completed"
            return "Quick setup downloads saved under $OfflineDirectory."
        }
        "InstallQuickSetupApps" {
            if ([string]::IsNullOrWhiteSpace($OfflineDirectory)) {
                throw "The offline installer folder is not configured."
            }
            $selectedIds = @($PackageIds | Select-Object -Unique)
            if ($selectedIds.Count -eq 0) {
                throw "Select at least one downloaded quick-setup app to install."
            }
            $allowedIds = Get-RylQuickSetupPackageIds
            $installPlan = @()
            foreach ($id in $selectedIds) {
                if ($id -notin $allowedIds) {
                    throw "Package '$id' is not part of the quick-setup allowlist."
                }
                $installerPath = Get-RylQuickSetupInstallerPath `
                    -OfflineDirectory $OfflineDirectory -PackageId $id
                if ($id -eq "Microsoft.Office" -and
                    [IO.Path]::GetFileName($installerPath) -ieq "setup.exe") {
                    $officeSource = Join-Path (Join-Path $OfflineDirectory $id) "OfficeSource\Office\Data"
                    $officeConfig = Join-Path (Join-Path $OfflineDirectory $id) "office-install.xml"
                    if (-not (Test-Path -LiteralPath $officeSource -PathType Container) -or
                        -not (Test-Path -LiteralPath $officeConfig -PathType Leaf)) {
                        throw "The full Office offline source is missing. Download Microsoft 365 from the Quick Setup page first."
                    }
                }
                $installPlan += [PSCustomObject]@{
                    PackageId = [string]$id
                    InstallerPath = $installerPath
                }
            }

            $completed = 0
            $cancelled = $false
            $rebootRequired = $false
            $failures = @()
            try {
                if ($InstallMode -eq "Sequence") {
                    for ($index = 0; $index -lt $installPlan.Count; $index++) {
                        if (Test-RylActionCancellationRequested -CancelPath $CancelPath) {
                            $cancelled = $true
                            break
                        }
                        $item = $installPlan[$index]
                        $basePercent = 5 + [int][math]::Floor(85 * $index / $installPlan.Count)
                        Write-RylActionProgress -ProgressPath $ProgressPath `
                            -Percent $basePercent `
                            -Detail "Starting installer for $($item.PackageId) ($($index + 1) of $($installPlan.Count))"
                        $process = Start-RylQuickSetupInstaller `
                            -InstallerPath $item.InstallerPath `
                            -PackageId $item.PackageId -OfflineDirectory $OfflineDirectory
                        while (-not $process.HasExited) {
                            Write-RylActionProgress -ProgressPath $ProgressPath `
                                -Percent ($basePercent + 1) `
                                -Detail "Waiting for $($item.PackageId) installer to finish"
                            Start-Sleep -Milliseconds 500
                            $process.Refresh()
                        }
                        $process.WaitForExit()
                        $exitCode = $process.ExitCode
                        $process.Dispose()
                        if ($exitCode -notin @(0, 1641, 3010)) {
                            throw "$($item.PackageId) installer failed (exit code $exitCode). Later installers were not started."
                        }
                        if ($exitCode -in @(1641, 3010)) {
                            $rebootRequired = $true
                        }
                        $completed++
                        if (Test-RylActionCancellationRequested -CancelPath $CancelPath) {
                            $cancelled = $true
                            break
                        }
                    }
                } else {
                    $pending = New-Object System.Collections.ArrayList
                    $launchFailures = @()
                    foreach ($item in $installPlan) {
                        if (Test-RylActionCancellationRequested -CancelPath $CancelPath) {
                            $cancelled = $true
                            break
                        }
                        try {
                            $process = Start-RylQuickSetupInstaller `
                                -InstallerPath $item.InstallerPath `
                                -PackageId $item.PackageId -OfflineDirectory $OfflineDirectory
                            [void]$pending.Add([PSCustomObject]@{
                                PackageId = $item.PackageId
                                Process = $process
                            })
                            Write-RylActionProgress -ProgressPath $ProgressPath `
                                -Percent (5 + [int][math]::Floor(35 * $pending.Count / $installPlan.Count)) `
                                -Detail "Started $($pending.Count) of $($installPlan.Count) installers in parallel"
                        } catch {
                            $launchFailures += "$($item.PackageId): $($_.Exception.Message)"
                            break
                        }
                    }
                    while ($pending.Count -gt 0) {
                        for ($index = $pending.Count - 1; $index -ge 0; $index--) {
                            $item = $pending[$index]
                            $item.Process.Refresh()
                            if ($item.Process.HasExited) {
                                $item.Process.WaitForExit()
                                $exitCode = $item.Process.ExitCode
                                $item.Process.Dispose()
                                if ($exitCode -notin @(0, 1641, 3010)) {
                                    $failures += "$($item.PackageId) installer failed (exit code $exitCode)."
                                } elseif ($exitCode -in @(1641, 3010)) {
                                    $rebootRequired = $true
                                }
                                $pending.RemoveAt($index)
                                $completed++
                            }
                        }
                        if ($pending.Count -gt 0) {
                            $waitingFor = @($pending | ForEach-Object { $_.PackageId }) -join ", "
                            $percent = 40 + [int][math]::Floor(55 * $completed / $installPlan.Count)
                            $waitingDetail = if (Test-RylActionCancellationRequested -CancelPath $CancelPath) {
                                $cancelled = $true
                                "Stop requested; allowing running installers to finish: $waitingFor"
                            } else {
                                "Completed $completed of $($installPlan.Count); waiting for $waitingFor"
                            }
                            Write-RylActionProgress -ProgressPath $ProgressPath `
                                -Percent $percent `
                                -Detail $waitingDetail
                            Start-Sleep -Milliseconds 500
                        }
                    }
                    if ($launchFailures.Count -gt 0) {
                        $failures += "Could not start all parallel installers: $($launchFailures -join '; ')"
                    }
                    if ($failures.Count -gt 0) {
                        throw ($failures -join " ")
                    }
                    if (Test-RylActionCancellationRequested -CancelPath $CancelPath) {
                        $cancelled = $true
                    }
                }
                if ($cancelled) {
                    $skipped = $installPlan.Count - $completed
                    $completionDetail = if ($skipped -gt 0) {
                        "Stopped after $completed of $($installPlan.Count) installer(s). $skipped not-yet-started installer(s) were skipped; running installers were allowed to finish."
                    } else {
                        "Stop was requested after all $completed selected installer(s) had finished."
                    }
                    Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                        -Detail $completionDetail -State "Cancelled"
                    return $completionDetail
                }
                $completionDetail = "Finished $completed selected installer(s) in $($InstallMode.ToLowerInvariant()) mode."
                if ($rebootRequired) {
                    $completionDetail += " One or more installers requested a restart."
                }
                Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                    -Detail $completionDetail -State "Completed"
                return $completionDetail
            } catch {
                Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                    -Detail "Failed: $($_.Exception.Message)" -State "Failed"
                throw
            }
        }
        "FlushDns" {
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 25 -Detail "Flushing DNS cache"
            Clear-DnsClientCache -ErrorAction Stop
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                -Detail "DNS resolver cache cleared" -State "Completed"
            return "DNS resolver cache cleared."
        }
        "CleanTemp" {
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 10 `
                -Detail "Scanning old temporary files"
            $cutoff = (Get-Date).AddDays(-7)
            $files = Get-ChildItem -LiteralPath $env:TEMP -File -Force -Recurse `
                -ErrorAction Stop | Where-Object {
                    $_.LastWriteTime -lt $cutoff -and
                    -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
                }
            $removed = 0
            $failed = 0
            $failureDetails = @()
            foreach ($file in $files) {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $removed++
                }
                catch {
                    $failed++
                    if ($failureDetails.Count -lt 3) {
                        $failureDetails += $_.Exception.Message
                    }
                }
                if (($removed + $failed) % 10 -eq 0) {
                    $percent = 10 + [int](85 * ($removed + $failed) / [math]::Max(1, $files.Count))
                    Write-RylActionProgress -ProgressPath $ProgressPath -Percent $percent `
                        -Detail "Processed $($removed + $failed) of $($files.Count) old temporary files"
                }
            }
            $summary = "Removed $removed old temporary file(s); $failed could not be removed."
            if ($failureDetails.Count -gt 0) {
                $summary += " $($failureDetails -join ' ')"
            }
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                -Detail $summary -State "Completed"
            return $summary
        }
        "ApplySystemPlan" {
            if (-not $PlanPath -or -not (Test-Path -LiteralPath $PlanPath)) {
                throw "The system-change plan was not found."
            }
            $hostExecutable = Join-Path $PSHOME "powershell.exe"
            if (-not (Test-Path -LiteralPath $hostExecutable)) {
                $hostExecutable = Join-Path $PSHOME "pwsh.exe"
            }
            if (-not (Test-Path -LiteralPath $hostExecutable)) {
                throw "Cannot find a PowerShell executable for the elevated action."
            }
            $helperPath = Join-Path $Root "Modules\ApplySystemChanges.ps1"
            $quotedHelper = '"' + $helperPath.Replace('"', '""') + '"'
            $quotedPlan = '"' + $PlanPath.Replace('"', '""') + '"'
            $quotedProgress = '"' + $ProgressPath.Replace('"', '""') + '"'
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File $quotedHelper -PlanPath $quotedPlan -ProgressPath $quotedProgress"
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 3 `
                -Detail "Requesting administrator approval"
            $process = Start-Process -FilePath $hostExecutable -ArgumentList $arguments `
                -WorkingDirectory $Root -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                $failureDetail = "exit code $($process.ExitCode)"
                if (Test-Path -LiteralPath $ProgressPath) {
                    $helperProgress = Get-Content -LiteralPath $ProgressPath -Raw -ErrorAction Stop |
                        ConvertFrom-Json
                    if ($helperProgress.State -eq "Failed") {
                        $failureDetail = [string]$helperProgress.Detail
                    }
                }
                throw "Elevated system changes failed: $failureDetail"
            }
            $completedProgress = Get-Content -LiteralPath $ProgressPath -Raw -ErrorAction Stop |
                ConvertFrom-Json
            return [string]$completedProgress.Detail
        }
        "SetAutomaticUpdates" {
            $reg = Join-Path $env:WINDIR "System32\reg.exe"
            $policyPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            $policyProviderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            if ($DisableAutomaticUpdates) {
                $arguments = "add $policyPath /v NoAutoUpdate /t REG_DWORD /d 1 /f"
                $changeDetail = "Automatic Windows Updates disabled by policy"
            } else {
                $currentPolicy = Get-ItemProperty -Path $policyProviderPath `
                    -Name NoAutoUpdate -ErrorAction SilentlyContinue
                if ($null -ne $currentPolicy) {
                    $arguments = "delete $policyPath /v NoAutoUpdate /f"
                } else {
                    $arguments = ""
                }
                $changeDetail = "Local automatic-update disable policy removed"
            }

            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 10 `
                -Detail "Requesting administrator approval"
            if ($arguments) {
                $process = Start-Process -FilePath $reg -ArgumentList $arguments `
                    -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                if ($process.ExitCode -ne 0) {
                    throw "Windows Update policy change failed (reg.exe exit code $($process.ExitCode))."
                }
            }
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 80 `
                -Detail "Verifying the Windows Update policy"
            $verifiedPolicy = Get-ItemProperty -Path $policyProviderPath `
                -Name NoAutoUpdate -ErrorAction SilentlyContinue
            if ($DisableAutomaticUpdates -and
                ($null -eq $verifiedPolicy -or $verifiedPolicy.NoAutoUpdate -ne 1)) {
                throw "Windows Update disable policy could not be verified after the elevated change."
            }
            if (-not $DisableAutomaticUpdates -and
                $null -ne $verifiedPolicy -and $verifiedPolicy.NoAutoUpdate -eq 1) {
                throw "The local Windows Update disable policy is still present. A domain or organization policy may be restoring it."
            }
            Write-RylActionProgress -ProgressPath $ProgressPath -Percent 100 `
                -Detail $changeDetail -State "Completed"
            return "$changeDetail."
        }
        default {
            throw "Unknown background action '$Action'."
        }
    }
}
