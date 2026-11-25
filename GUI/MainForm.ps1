Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. "$PSScriptRoot\Theme.ps1"
. "$PSScriptRoot\Pages\Monitor.ps1"
. "$PSScriptRoot\Pages\Utilities.ps1"
. "$PSScriptRoot\Pages\Downloader.ps1"
. "$PSScriptRoot\..\Modules\Configuration.ps1"
. "$PSScriptRoot\..\Modules\AppCatalog.ps1"
. "$PSScriptRoot\..\Modules\SystemMonitor.ps1"
. "$PSScriptRoot\..\Modules\Network.ps1"
. "$PSScriptRoot\..\Modules\OptionalApps.ps1"
. "$PSScriptRoot\..\Modules\BackgroundActions.ps1"

function Start-MonitorGUI {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [hashtable]$Settings,
        [string]$LHMStatus = "Checking hardware..."
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    if (-not $Settings) {
        $Settings = Get-RylSettings -Root $Root
    }

    $theme = @{
        Background = [Drawing.ColorTranslator]::FromHtml($Settings.Background)
        Sidebar = [Drawing.ColorTranslator]::FromHtml($Settings.Sidebar)
        Panel = [Drawing.ColorTranslator]::FromHtml($Settings.Panel)
        Accent = [Drawing.ColorTranslator]::FromHtml($Settings.Accent)
        Muted = [Drawing.ColorTranslator]::FromHtml($Settings.Muted)
    }
    $appCatalog = Get-RylAppCatalog -Root $Root

    $form = New-Object Windows.Forms.Form
    $form.Text = "RylUtils"
    $workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $windowWidth = [math]::Min(1480, [math]::Max(1180, $workingArea.Width - 48))
    $windowHeight = [math]::Min(960, [math]::Max(680, $workingArea.Height - 48))
    $form.Size = New-Object Drawing.Size($windowWidth, $windowHeight)
    $form.MinimumSize = New-Object Drawing.Size(1100, 680)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $theme.Background
    $form.ForeColor = [Drawing.Color]::White
    $form.Font = New-Object Drawing.Font("Segoe UI", 10)

    $hostCandidates = @()
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $hostCandidates += Join-Path $env:WINDIR "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    }
    $hostCandidates += Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    $hostCandidates += Join-Path $PSHOME "powershell.exe"
    $hostCandidates += Join-Path $PSHOME "pwsh.exe"
    $powerShellPath = $hostCandidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if (-not $powerShellPath) {
        throw "Cannot find a PowerShell executable for administrator restart."
    }

    $sidebar = New-Object Windows.Forms.Panel
    $sidebar.Size = New-Object Drawing.Size(210, $form.ClientSize.Height)
    $sidebar.Anchor = "Top, Bottom, Left"
    $sidebar.BackColor = $theme.Sidebar
    $form.Controls.Add($sidebar)

    $brand = New-RylLabel -Text "RYL  /  UTILITIES" `
        -Location (New-Object Drawing.Point(20, 24)) `
        -Size (New-Object Drawing.Size(175, 36)) -Theme $theme -FontSize 13 -Bold
    $sidebar.Controls.Add($brand)
    $navCaption = New-RylLabel -Text "WORKSPACE" `
        -Location (New-Object Drawing.Point(22, 91)) `
        -Size (New-Object Drawing.Size(165, 22)) -Theme $theme -FontSize 8 -Color $theme.Muted -Bold
    $sidebar.Controls.Add($navCaption)

    $topbar = New-Object Windows.Forms.Panel
    $topbar.Location = New-Object Drawing.Point(210, 0)
    $workspaceWidth = $form.ClientSize.Width - 210
    $workspaceHeight = $form.ClientSize.Height - 76
    $topbar.Size = New-Object Drawing.Size($workspaceWidth, 76)
    $topbar.Anchor = "Top, Left, Right"
    $topbar.BackColor = $theme.Sidebar
    $form.Controls.Add($topbar)

    $pageTitle = New-RylLabel -Text "Monitor" `
        -Location (New-Object Drawing.Point(28, 17)) `
        -Size (New-Object Drawing.Size(500, 28)) -Theme $theme -FontSize 16 -Bold
    $pageSubtitle = New-RylLabel -Text "Live system performance" `
        -Location (New-Object Drawing.Point(30, 46)) `
        -Size (New-Object Drawing.Size(500, 20)) -Theme $theme -Color $theme.Muted
    $status = New-RylLabel -Text $LHMStatus `
        -Location (New-Object Drawing.Point(580, 27)) `
        -Size (New-Object Drawing.Size(285, 25)) -Theme $theme -Color $theme.Muted
    $status.Anchor = "Top, Right"
    $status.TextAlign = "MiddleRight"
    $progress = New-Object Windows.Forms.ProgressBar
    $progress.Location = New-Object Drawing.Point(580, 57)
    $progress.Size = New-Object Drawing.Size(285, 12)
    $progress.Anchor = "Top, Right"
    $progress.Visible = $false
    foreach ($control in @($pageTitle, $pageSubtitle, $status, $progress)) {
        $topbar.Controls.Add($control)
    }

    $content = New-Object Windows.Forms.Panel
    $content.Location = New-Object Drawing.Point(210, 76)
    $content.Size = New-Object Drawing.Size($workspaceWidth, $workspaceHeight)
    $content.Anchor = "Top, Bottom, Left, Right"
    $content.BackColor = $theme.Background
    $form.Controls.Add($content)

    $pageSize = New-Object Drawing.Size($workspaceWidth, $workspaceHeight)
    $monitor = New-RylMonitorPage -Theme $theme -Size $pageSize
    $utilities = New-RylUtilitiesPage -Theme $theme -Size $pageSize
    $downloader = New-RylDownloaderPage -Theme $theme -Size $pageSize `
        -OfflineDirectory $Settings.OfflineDirectory `
        -Categories @($appCatalog | ForEach-Object { $_.Category } | Sort-Object -Unique)
    $monitor.Panel.Visible = $true
    $utilities.Panel.Visible = $false
    $downloader.Panel.Visible = $false
    foreach ($page in @($monitor.Panel, $utilities.Panel, $downloader.Panel)) {
        $content.Controls.Add($page)
    }

    $pages = @{
        Monitor = $monitor.Panel
        Utilities = $utilities.Panel
        Downloader = $downloader.Panel
    }
    $navItems = @(
        @{ Name = "Monitor"; Text = "Monitor"; Glyph = "E770"; Top = 126 },
        @{ Name = "Utilities"; Text = "Utilities"; Glyph = "E713"; Top = 174 },
        @{ Name = "Downloader"; Text = "App downloader"; Glyph = "E896"; Top = 222 }
    )
    $navButtons = @()
    foreach ($item in $navItems) {
        $button = New-RylButton -Text $item.Text `
            -Location (New-Object Drawing.Point(14, $item.Top)) `
            -Size (New-Object Drawing.Size(182, 40)) -Theme $theme
        $button.Tag = $item.Name
        $button.TextAlign = "MiddleLeft"
        $button.Image = New-RylGlyphBitmap -Glyph $item.Glyph -Size 18
        $button.ImageAlign = "MiddleLeft"
        $button.TextImageRelation = "ImageBeforeText"
        $button.Padding = New-Object Windows.Forms.Padding(12, 0, 0, 0)
        $button.BackColor = if ($item.Name -eq "Monitor") { $theme.Accent } else { $theme.Sidebar }
        $sidebar.Controls.Add($button)
        $navButtons += $button
    }

    $state = @{
        Root = $Root
        PowerShellPath = $powerShellPath
        Theme = $theme
        Settings = $Settings
        Pages = $pages
        PageTitle = $pageTitle
        PageSubtitle = $pageSubtitle
        NavButtons = $navButtons
        Status = $status
        Progress = $progress
        Monitor = $monitor
        Utilities = $utilities
        Downloader = $downloader
        Apps = $appCatalog
        SelectedCategory = "All"
        WingetAvailable = $false
        MonitorRunspace = [runspacefactory]::CreateRunspace()
        MonitorPowerShell = $null
        MonitorAsync = $null
        ActionRunspace = $null
        ActionPowerShell = $null
        ActionAsync = $null
        ActionName = ""
        ActionProgressPath = ""
        ActionProgressPathOwned = $false
        ActivePlanKind = ""
        OptionalAppCatalog = @()
        AutoUpdateDisabled = $false
        MonitorNetworkSample = $null
    }
    $form.Tag = $state
    $state.MonitorRunspace.Open()

    function Start-BackgroundAction {
        param(
            [string]$Name,
            [string]$Action,
            [string]$PackageId,
            [bool]$DisableAutomaticUpdates = $false,
            [string]$ProgressPath,
            [string]$PlanPath
        )

        $current = $form.Tag
        if ($current.ActionPowerShell) {
            $current.Status.Text = "Wait for the current background action to finish."
            return
        }

        $ownsProgressPath = [string]::IsNullOrWhiteSpace($ProgressPath)
        if ($ownsProgressPath) {
            $ProgressPath = Join-Path $env:TEMP ("RylUtils-progress-{0}-{1}.json" -f $PID, [guid]::NewGuid().ToString("N"))
        }
        Write-RylActionProgress -ProgressPath $ProgressPath -Percent 1 -Detail "$Name starting"

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $script = {
            param($ModulePath, $ActionName, $AppRoot, $Id, $OfflineDirectory, $DisableUpdates, $ActionProgress, $PlanFile)
            . $ModulePath
            Invoke-RylBackgroundAction -Action $ActionName -Root $AppRoot `
                -PackageId $Id -OfflineDirectory $OfflineDirectory `
                -DisableAutomaticUpdates $DisableUpdates -ProgressPath $ActionProgress `
                -PlanPath $PlanFile
        }
        [void]$powerShell.AddScript($script.ToString())
        [void]$powerShell.AddArgument((Join-Path $current.Root "Modules\BackgroundActions.ps1"))
        [void]$powerShell.AddArgument($Action)
        [void]$powerShell.AddArgument($current.Root)
        [void]$powerShell.AddArgument($PackageId)
        [void]$powerShell.AddArgument($current.Settings.OfflineDirectory)
        [void]$powerShell.AddArgument($DisableAutomaticUpdates)
        [void]$powerShell.AddArgument($ProgressPath)
        [void]$powerShell.AddArgument($PlanPath)

        $current.ActionRunspace = $runspace
        $current.ActionPowerShell = $powerShell
        $current.ActionAsync = $powerShell.BeginInvoke()
        $current.ActionName = $Action
        $current.ActionProgressPath = $ProgressPath
        $current.ActionProgressPathOwned = $ownsProgressPath
        $current.Progress.Style = "Continuous"
        $current.Progress.Value = 1
        $current.Progress.Visible = $true
        $current.Downloader.ActionStatus.Text = "$Name is running..."
        $current.Status.Text = "$Name in progress"
    }

    function Start-MonitorRefresh {
        $current = $form.Tag
        if ($current.MonitorAsync -and -not $current.MonitorAsync.IsCompleted) {
            return
        }
        if ($current.MonitorPowerShell) {
            $current.MonitorPowerShell.Dispose()
        }

        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $current.MonitorRunspace
        $script = {
            param($ModulePath, $AppRoot, $PreviousNetworkSample)
            . $ModulePath
            Get-RylMonitorSnapshot -Root $AppRoot `
                -PreviousNetworkSample $PreviousNetworkSample
        }
        [void]$powerShell.AddScript($script.ToString())
        [void]$powerShell.AddArgument((Join-Path $current.Root "Modules\SystemMonitor.ps1"))
        [void]$powerShell.AddArgument($current.Root)
        [void]$powerShell.AddArgument($current.MonitorNetworkSample)
        $current.MonitorPowerShell = $powerShell
        $current.MonitorAsync = $powerShell.BeginInvoke()
        if (-not $current.ActionPowerShell) {
            $current.Status.Text = "Updating hardware readings..."
        }
    }

    function Update-AutoUpdateStatus {
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        $value = Get-ItemProperty -Path $path -Name NoAutoUpdate -ErrorAction SilentlyContinue
        $current = $form.Tag
        $current.AutoUpdateDisabled = ($null -ne $value -and $value.NoAutoUpdate -eq 1)
        if ($current.AutoUpdateDisabled) {
            $current.Utilities.UpdateStatus.Text = "Policy currently disables automatic updates."
            $current.Utilities.DisableUpdatesButton.Enabled = $false
            $current.Utilities.EnableUpdatesButton.Enabled = $true
        } elseif ($null -ne $value -and $value.NoAutoUpdate -eq 0) {
            $current.Utilities.UpdateStatus.Text = "Policy explicitly allows automatic updates."
            $current.Utilities.DisableUpdatesButton.Enabled = $true
            $current.Utilities.EnableUpdatesButton.Enabled = $false
        } else {
            $current.Utilities.UpdateStatus.Text = "No explicit automatic-update block is set."
            $current.Utilities.DisableUpdatesButton.Enabled = $true
            $current.Utilities.EnableUpdatesButton.Enabled = $true
        }
    }

    function Get-LatestDnsBackup {
            $directory = Join-Path $form.Tag.Root "Backups\Network"
            if (-not (Test-Path -LiteralPath $directory)) {
                return $null
            }
            $backups = Get-ChildItem -LiteralPath $directory -Directory -ErrorAction Stop |
                Sort-Object -Property LastWriteTime -Descending
            foreach ($backup in $backups) {
                $snapshotPath = Join-Path $backup.FullName "Snapshot.json"
                if (Test-Path -LiteralPath $snapshotPath) {
                    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw -ErrorAction Stop |
                        ConvertFrom-Json
                    if ($snapshot.DNS -and $snapshot.Kind -eq "ApplyDns" -and
                        -not $snapshot.Restored) {
                        return $snapshotPath
                }
            }
        }
            return $null
        }

    function Start-SystemChangePlan {
            param(
                [Parameter(Mandatory = $true)][string]$Kind,
                [string[]]$Actions = @(),
                [string[]]$PackageNames = @(),
                [object]$Profile,
                [int]$InterfaceIndex = 0,
                [string]$AdapterName,
                [bool]$CreateRestorePoint = $false,
                [string]$SnapshotPath
            )

            $current = $form.Tag
            if ($current.ActionPowerShell) {
                $current.Status.Text = "Wait for the current background action to finish."
                return $false
            }
            $group = if ($Kind -eq "ApplyDns" -or $Kind -eq "RestoreDns") {
                "Network"
            } else {
                "Optimization"
            }
            $backupRoot = Join-Path $current.Root "Backups\$group"
            $backupDirectory = Join-Path $backupRoot (Get-Date -Format "yyyyMMdd-HHmmssfff")
            New-Item -ItemType Directory -Path $backupDirectory -Force -ErrorAction Stop | Out-Null
            $planPath = Join-Path $backupDirectory "Plan.json"
            $progressPath = Join-Path $backupDirectory "Progress.json"
            $plan = [PSCustomObject]@{
                Root = $current.Root
                Kind = $Kind
                Actions = @($Actions)
                PackageNames = @($PackageNames)
                Profile = $Profile
                InterfaceIndex = $InterfaceIndex
                AdapterName = $AdapterName
                CreateRestorePoint = $CreateRestorePoint
                SnapshotPath = $SnapshotPath
            }
            $plan | ConvertTo-Json -Depth 8 |
                Set-Content -LiteralPath $planPath -Encoding UTF8 -ErrorAction Stop
            $current.ActivePlanKind = $Kind
            Start-BackgroundAction -Name "Applying $group changes" -Action "ApplySystemPlan" `
                -PlanPath $planPath -ProgressPath $progressPath
            $current.LastBackupPath = $backupDirectory
            return $true
        }

    function Initialize-UtilityOptions {
            $current = $form.Tag
            try {
                $adapters = Get-RylNetworkAdapters
                foreach ($adapterEntry in $adapters) {
                    [void]$current.Utilities.NetworkAdapter.Items.Add($adapterEntry)
                }
                if ($current.Utilities.NetworkAdapter.Items.Count -gt 0) {
                    $current.Utilities.NetworkAdapter.SelectedIndex = 0
                } else {
                    $current.Utilities.NetworkStatus.Text = "No active network adapters were found."
                    $current.Utilities.ApplyDnsButton.Enabled = $false
                }
            }
            catch {
                $current.Utilities.NetworkStatus.Text = "Could not enumerate adapters: $($_.Exception.Message)"
                $current.Utilities.ApplyDnsButton.Enabled = $false
            }

            try {
                $profiles = Get-RylDnsProfiles -Root $current.Root
                foreach ($profile in $profiles) {
                    [void]$current.Utilities.DnsProfile.Items.Add($profile)
                }
                if ($current.Utilities.DnsProfile.Items.Count -gt 0) {
                    $current.Utilities.DnsProfile.SelectedIndex = 0
                }
            }
            catch {
                $current.Utilities.NetworkStatus.Text = "Could not load DNS profiles: $($_.Exception.Message)"
                $current.Utilities.ApplyDnsButton.Enabled = $false
            }

            try {
                $current.OptionalAppCatalog = @(Get-RylOptionalApps -Root $current.Root)
                foreach ($app in $current.OptionalAppCatalog) {
                    [void]$current.Utilities.OptionalApps.Items.Add($app.DisplayName)
                }
                if ($current.OptionalAppCatalog.Count -eq 0) {
                    [void]$current.Utilities.OptionalApps.Items.Add("No allow-listed optional apps are installed")
                    $current.Utilities.OptionalApps.Enabled = $false
                    $current.Utilities.TaskList.SetItemChecked(2, $false)
                }
            }
            catch {
                $current.Utilities.SafetyWarning.Text = "Could not load optional-app inventory: $($_.Exception.Message)"
                $current.Utilities.OptionalApps.Enabled = $false
            }

            try {
            $current.Utilities.RestoreDnsButton.Enabled = [bool](Get-LatestDnsBackup)
            }
            catch {
                $current.Utilities.NetworkStatus.Text = "Could not read DNS backups: $($_.Exception.Message)"
                $current.Utilities.RestoreDnsButton.Enabled = $false
            }
    }

    function Set-AppCatalog {
        param([string]$Category = "All")

        $current = $form.Tag
        foreach ($tile in @($current.Downloader.AppPanel.Controls)) {
            foreach ($control in $tile.Controls) {
                if (($control -is [Windows.Forms.Label] -or
                    $control -is [Windows.Forms.PictureBox]) -and $control.Image) {
                    $control.Image.Dispose()
                }
            }
            $tile.Dispose()
        }
        $current.Downloader.AppPanel.Controls.Clear()

        $apps = @($current.Apps)
        if ($Category -ne "All") {
            $apps = @($apps | Where-Object { $_.Category -eq $Category })
        }
        $query = [string]$current.Downloader.SearchBox.Text
        if (-not [string]::IsNullOrWhiteSpace($query)) {
            $apps = @($apps | Where-Object {
                $searchText = "{0} {1} {2} {3}" -f $_.Name, $_.PackageId, $_.Category, $_.Description
                $searchText.IndexOf($query.Trim(), [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        }
        foreach ($app in $apps) {
            $tile = New-RylAppTile -App $app -Theme $current.Theme `
                -WingetAvailable $current.WingetAvailable
            foreach ($button in @($tile.Controls | Where-Object { $_ -is [Windows.Forms.Button] })) {
                $button.Add_Click({
                    param($sender, $eventArgs)
                    $action = $sender.Tag
                    $appEntry = $action.App
                    $name = if ($action.Action -eq "DownloadOfflineApp") {
                        "Downloading $($appEntry.Name) offline installer"
                    } else {
                        "Installing $($appEntry.Name)"
                    }
                    Start-BackgroundAction -Name $name -Action $action.Action `
                        -PackageId $appEntry.PackageId
                })
            }
            $current.Downloader.AppPanel.Controls.Add($tile)
        }
        if ($apps.Count -eq 0) {
            $emptyState = New-RylLabel -Text "No apps match this search." `
                -Location (New-Object Drawing.Point(18, 18)) `
                -Size (New-Object Drawing.Size(420, 32)) `
                -Theme $current.Theme -Color $current.Theme.Muted
            $current.Downloader.AppPanel.Controls.Add($emptyState)
        }
        $current.SelectedCategory = $Category
        foreach ($button in $current.Downloader.CategoryButtons) {
            $button.BackColor = if ($button.Tag -eq $Category) {
                $current.Theme.Accent
            } else {
                $current.Theme.Panel
            }
        }
    }

    foreach ($button in $navButtons) {
        $button.Add_Click({
            param($sender, $eventArgs)
            $selectedPage = [string]$sender.Tag
            $current = $form.Tag
            foreach ($entry in $current.Pages.GetEnumerator()) {
                $entry.Value.Visible = ($entry.Key -eq $selectedPage)
            }
            $current.PageTitle.Text = $selectedPage
            $current.PageSubtitle.Text = switch ($selectedPage) {
                "Monitor" { "Live system performance" }
                "Utilities" { "Maintenance tools and update settings" }
                "Downloader" { "Browse, install, or save offline installers" }
            }
            foreach ($navButton in $current.NavButtons) {
                $navButton.BackColor = if ($navButton.Tag -eq $selectedPage) {
                    $current.Theme.Accent
                } else {
                    $current.Theme.Sidebar
                }
            }
        })
    }

    foreach ($button in $downloader.CategoryButtons) {
        $button.Add_Click({
            param($sender, $eventArgs)
            Set-AppCatalog -Category ([string]$sender.Tag)
        })
    }
    $downloader.SearchBox.Add_TextChanged({
        $current = $form.Tag
        Set-AppCatalog -Category $current.SelectedCategory
    })

    $utilities.DnsProfile.Add_SelectedIndexChanged({
        $profile = $form.Tag.Utilities.DnsProfile.SelectedItem
        if ($profile) {
            $servers = @($profile.IPv4) + @($profile.IPv6)
            $serverText = if ($servers.Count -gt 0) {
                "Servers: $($servers -join ', ')"
            } else {
                "Uses servers supplied by DHCP."
            }
            $form.Tag.Utilities.DnsDescription.Text = "$($profile.Description)`r`n$serverText"
        }
    })
    $utilities.ApplyDnsButton.Add_Click({
        $current = $form.Tag
        $adapter = $current.Utilities.NetworkAdapter.SelectedItem
        $profile = $current.Utilities.DnsProfile.SelectedItem
        if (-not $adapter -or -not $profile) {
            $current.Utilities.NetworkStatus.Text = "Select an active adapter and a DNS profile first."
            return
        }
        $answer = [Windows.Forms.MessageBox]::Show(
            "Apply $($profile.Name) DNS servers to '$($adapter.Name)'? The current settings will be backed up first.",
            "Confirm DNS change",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
            $started = Start-SystemChangePlan -Kind "ApplyDns" -Profile $profile `
                -InterfaceIndex $adapter.InterfaceIndex -AdapterName $adapter.Name
            if ($started) {
                $current.Utilities.NetworkStatus.Text = "Applying DNS profile and saving a backup..."
            }
        }
    })
    $utilities.RestoreDnsButton.Add_Click({
        $current = $form.Tag
        try {
            $snapshotPath = Get-LatestDnsBackup
            if (-not $snapshotPath) {
                $current.Utilities.NetworkStatus.Text = "No DNS backup was found."
                return
            }
            $snapshot = Get-Content -LiteralPath $snapshotPath -Raw -ErrorAction Stop |
                ConvertFrom-Json
            $answer = [Windows.Forms.MessageBox]::Show(
                "Restore the saved DNS settings for '$($snapshot.DNS.AdapterName)'?",
                "Confirm DNS restore",
                [Windows.Forms.MessageBoxButtons]::YesNo,
                [Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
                $started = Start-SystemChangePlan -Kind "RestoreDns" `
                    -InterfaceIndex ([int]$snapshot.DNS.InterfaceIndex) `
                    -AdapterName ([string]$snapshot.DNS.AdapterName) -SnapshotPath $snapshotPath
                if ($started) {
                    $current.Utilities.NetworkStatus.Text = "Restoring DNS settings from the saved backup..."
                }
            }
        }
        catch {
            $current.Utilities.NetworkStatus.Text = "DNS restore could not start: $($_.Exception.Message)"
        }
    })
    $utilities.FlushDnsButton.Add_Click({
        Start-BackgroundAction -Name "Flushing DNS cache" -Action "FlushDns"
    })

    foreach ($presetEntry in $utilities.PresetButtons.GetEnumerator()) {
        $presetEntry.Value.Add_Click({
            param($sender, $eventArgs)
            $current = $form.Tag
            $preset = [string]$sender.Text
            $current.Utilities.SafetyWarning.Text = "Warning: temp cleanup and app removal may not be reversible. A restore point is recommended; removed apps may need reinstalling from Microsoft Store."
            for ($index = 0; $index -lt $current.Utilities.TaskList.Items.Count; $index++) {
                $current.Utilities.TaskList.SetItemChecked($index, $false)
            }
            for ($index = 0; $index -lt $current.Utilities.OptionalApps.Items.Count; $index++) {
                $current.Utilities.OptionalApps.SetItemChecked($index, $false)
            }
            if ($preset -eq "Minimal") {
                $current.Utilities.TaskList.SetItemChecked(0, $true)
            } elseif ($preset -eq "Standard") {
                $current.Utilities.TaskList.SetItemChecked(0, $true)
                $current.Utilities.TaskList.SetItemChecked(1, $true)
            } elseif ($preset -eq "Full") {
                $current.Utilities.TaskList.SetItemChecked(0, $true)
                $current.Utilities.TaskList.SetItemChecked(1, $true)
                $current.Utilities.TaskList.SetItemChecked(2, $true)
                for ($index = 0; $index -lt $current.Utilities.OptionalApps.Items.Count; $index++) {
                    if ($current.Utilities.OptionalApps.Enabled) {
                        $current.Utilities.OptionalApps.SetItemChecked($index, $true)
                    }
                }
                $current.Utilities.SafetyWarning.Text = "Full preset selected. Review each checked optional app before applying; packages will be removed only from this user profile."
            } else {
                $current.Utilities.SafetyWarning.Text = "Warning: temp cleanup and app removal may not be reversible. A restore point is recommended; removed apps may need reinstalling from Microsoft Store."
            }
        })
    }

    $utilities.ApplyOptimizationButton.Add_Click({
        $current = $form.Tag
        $selectedTasks = @($current.Utilities.TaskList.CheckedIndices |
            ForEach-Object { [int]$_ })
        if ($selectedTasks.Count -eq 0) {
            $current.Status.Text = "Select at least one optimization task."
            return
        }

        $actions = @()
        if (0 -in $selectedTasks) { $actions += "FlushDns" }
        if (1 -in $selectedTasks) { $actions += "CleanTemp" }
        if (2 -in $selectedTasks) { $actions += "RemoveBloatware" }
        $packageNames = @()
        foreach ($index in $current.Utilities.OptionalApps.CheckedIndices) {
            if ($index -lt $current.OptionalAppCatalog.Count) {
                $packageNames += $current.OptionalAppCatalog[$index].PackageName
            }
        }
        if ("RemoveBloatware" -in $actions -and $packageNames.Count -eq 0) {
            $current.Status.Text = "Select one or more installed optional apps to remove."
            return
        }
        if ("RemoveBloatware" -in $actions -and -not $current.Utilities.RestorePoint.Checked) {
            $current.Status.Text = "A restore point is required before removing optional apps."
            return
        }

        $warning = "Apply the selected optimization tasks?"
        if ("CleanTemp" -in $actions -or "RemoveBloatware" -in $actions) {
            $warning = "Selected tasks may delete files or remove apps and may not be reversible. The selected apps are current-user packages from a vetted allowlist. Continue?"
        }
        $answer = [Windows.Forms.MessageBox]::Show(
            $warning,
            "Confirm optimization",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
            Start-SystemChangePlan -Kind "Optimize" -Actions $actions `
                -PackageNames $packageNames `
                -CreateRestorePoint $current.Utilities.RestorePoint.Checked
        }
    })
    $utilities.OpenRestoreButton.Add_Click({
        try {
            Start-Process -FilePath (Join-Path $env:WINDIR "System32\rstrui.exe") `
                -ErrorAction Stop
        }
        catch {
            $form.Tag.Status.Text = "Could not open System Restore: $($_.Exception.Message)"
        }
    })

    function Request-AutoUpdateChange {
        param([bool]$Enable)

        $disable = -not $Enable
        $message = if ($disable) {
            "This will set a machine-wide policy to disable automatic Windows Updates and request administrator approval. The PC may miss security updates. Continue?"
        } else {
            "This will set the machine-wide NoAutoUpdate policy to allow automatic Windows Updates and request administrator approval. Organization policy may override this. Continue?"
        }
        $answer = [Windows.Forms.MessageBox]::Show(
            $message,
            "Confirm Windows Update change",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
            Start-BackgroundAction -Name "Windows Update policy" `
                -Action "SetAutomaticUpdates" -DisableAutomaticUpdates $disable
        }
    }
    $utilities.DisableUpdatesButton.Add_Click({
        Request-AutoUpdateChange -Enable $false
    })
    $utilities.EnableUpdatesButton.Add_Click({
        Request-AutoUpdateChange -Enable $true
    })

    foreach ($button in $utilities.QuickTools.Values) {
        $button.Add_Click({
            param($sender, $eventArgs)

            $current = $form.Tag
            $target = [string]$sender.Tag
            try {
                if ($target -match '^Script:') {
                    $scriptName = $target.Substring(7)
                    if ($scriptName -notmatch '^[A-Za-z0-9_-]+\.ps1$') {
                        throw "Invalid quick-tool script name."
                    }
                    $scriptPath = Join-Path (Join-Path $current.Root "Tools") $scriptName
                    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                        throw "Quick-tool script was not found: $scriptPath"
                    }
                    $quotedScript = '"' + $scriptPath.Replace('"', '""') + '"'
                    $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $quotedScript"
                    Start-Process -FilePath $current.PowerShellPath -ArgumentList $arguments `
                        -WorkingDirectory $current.Root -WindowStyle Hidden -ErrorAction Stop
                } elseif ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') {
                    Start-Process -FilePath $target -ErrorAction Stop
                } else {
                    $toolPath = Join-Path (Join-Path $env:WINDIR "System32") $target
                    if (-not (Test-Path -LiteralPath $toolPath)) {
                        throw "Windows tool was not found: $toolPath"
                    }
                    Start-Process -FilePath $toolPath -ErrorAction Stop
                }
                $current.Status.Text = "$($sender.Text) opened."
            } catch {
                $current.Status.Text = "Could not open $($sender.Text): $($_.Exception.Message)"
            }
        })
    }

    $downloader.RetryButton.Add_Click({
        Start-BackgroundAction -Name "WinGet setup" -Action "CheckWinget"
    })
    $downloader.StoreButton.Add_Click({
        Start-Process -FilePath "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction Stop
    })
    $downloader.OpenFolderButton.Add_Click({
        $folder = $form.Tag.Settings.OfflineDirectory
        New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$folder`"" -ErrorAction Stop
    })
    $monitor.RefreshButton.Add_Click({ Start-MonitorRefresh })
    $monitor.ElevationButton.Add_Click({
        $answer = [Windows.Forms.MessageBox]::Show(
            "The CPU exposes temperature sensors but returned no values. Restart RylUtils with administrator approval to read them?",
            "Administrator access required",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) {
            return
        }

        try {
            $scriptPath = Join-Path $form.Tag.Root "Main.ps1"
            $quotedScript = '"' + $scriptPath.Replace('"', '""') + '"'
            $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $quotedScript -HiddenLaunch"
            Start-Process -FilePath $form.Tag.PowerShellPath -ArgumentList $arguments `
                -WorkingDirectory $form.Tag.Root -Verb RunAs -WindowStyle Hidden `
                -ErrorAction Stop | Out-Null
            $form.Close()
        }
        catch {
            $form.Tag.Status.Text = "Could not restart elevated: $($_.Exception.Message)"
        }
    })

    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = [math]::Max(1000, $Settings.RefreshInterval)
    $timer.Add_Tick({
        $current = $form.Tag

        if ($current.ActionPowerShell -and
            -not [string]::IsNullOrWhiteSpace($current.ActionProgressPath) -and
            (Test-Path -LiteralPath $current.ActionProgressPath)) {
            try {
                $progressInfo = Get-Content -LiteralPath $current.ActionProgressPath -Raw -ErrorAction Stop |
                    ConvertFrom-Json
                $percent = [math]::Min(100, [math]::Max(0, [int]$progressInfo.Percent))
                $current.Progress.Style = "Continuous"
                $current.Progress.Value = $percent
                $current.Status.Text = "$percent%  $($progressInfo.Detail)"
                $current.Downloader.ActionStatus.Text = "$percent%  $($progressInfo.Detail)"
            }
            catch {
                $current.Status.Text = "Progress update unavailable: $($_.Exception.Message)"
            }
        }

        if ($current.MonitorAsync -and $current.MonitorAsync.IsCompleted) {
            try {
                $result = $current.MonitorPowerShell.EndInvoke($current.MonitorAsync) |
                    Select-Object -Last 1
                if ($result) {
                    $current.Monitor.Cards.CPU.Value.Text = "$($result.CPU)%"
                    $current.Monitor.Cards.CPU.Bar.Value = $result.CPU
                    $current.Monitor.Cards.RAM.Value.Text = "$($result.RAMUsed) GB"
                    $current.Monitor.Cards.RAM.Bar.Value = $result.RAMPercent
                    if ($result.DiskTotalGB -gt 0) {
                        $current.Monitor.Cards.Disk.Value.Text = "$($result.DiskUsedPercent)% used"
                        $current.Monitor.Cards.Disk.Bar.Value = $result.DiskUsedPercent
                    } else {
                        $current.Monitor.Cards.Disk.Value.Text = "N/A"
                        $current.Monitor.Cards.Disk.Bar.Value = 0
                    }
                    if ($result.NetworkError) {
                        $current.Monitor.Cards.Network.Value.Text = "Unavailable"
                        $current.Monitor.Cards.Network.Bar.Value = 0
                    } elseif (@($result.NetworkAdapters).Count -eq 0) {
                        $current.Monitor.Cards.Network.Value.Text = "No active adapter"
                        $current.Monitor.Cards.Network.Bar.Value = 0
                    } elseif ($result.NetworkHasRate) {
                        $current.Monitor.Cards.Network.Value.Text = "RX {0:N1} / TX {1:N1} Mb/s" -f `
                            $result.NetworkDownloadMbps, $result.NetworkUploadMbps
                        $totalNetworkMbps = [double]$result.NetworkDownloadMbps +
                            [double]$result.NetworkUploadMbps
                        $current.Monitor.Cards.Network.Bar.Value = [math]::Min(
                            100, [math]::Max(0, [int][math]::Round($totalNetworkMbps))
                        )
                    } else {
                        $current.Monitor.Cards.Network.Value.Text = "Sampling network..."
                        $current.Monitor.Cards.Network.Bar.Value = 0
                    }
                    if ($result.Uptime) {
                        $uptimeDays = [int][math]::Floor($result.Uptime.TotalDays)
                        $current.Monitor.Cards.Uptime.Value.Text = if ($uptimeDays -gt 0) {
                            "{0}d {1}h" -f $uptimeDays, $result.Uptime.Hours
                        } else {
                            "{0}h {1}m" -f $result.Uptime.Hours, $result.Uptime.Minutes
                        }
                    } else {
                        $current.Monitor.Cards.Uptime.Value.Text = "N/A"
                    }
                    if ($null -ne $result.Temperature) {
                        $degree = [char]0x00B0
                        $current.Monitor.Cards.Temp.Value.Text = "{0} {1}C" -f $result.Temperature, $degree
                        $current.Monitor.Cards.Temp.Bar.Value = [math]::Min(
                            100, [math]::Max(0, [int]($result.Temperature * 2))
                        )
                    } else {
                        $current.Monitor.Cards.Temp.Value.Text = "N/A"
                        $current.Monitor.Cards.Temp.Bar.Value = 0
                    }
                    $current.Monitor.ElevationButton.Visible = [bool]$result.TemperatureRequiresElevation
                    $current.MonitorNetworkSample = $result.NetworkSample
                    $systemDrive = [Environment]::GetEnvironmentVariable("SystemDrive")
                    $diskDetails = if ($result.DiskTotalGB -gt 0) {
                        "$systemDrive $($result.DiskFreeGB) GB free / $($result.DiskTotalGB) GB"
                    } else {
                        "Unavailable: $($result.DiskError)"
                    }
                    $networkRateDetails = if ($result.NetworkHasRate) {
                        "RX $($result.NetworkDownloadMbps) / TX $($result.NetworkUploadMbps) Mb/s"
                    } else {
                        [string]$result.NetworkError
                    }
                    $current.Monitor.Details.Text = @"
DISK: $diskDetails
NETWORK: $(@($result.NetworkAdapters) -join ', ') $networkRateDetails
UPTIME: $($result.Uptime)
TEMPERATURE SENSOR: $($result.Sensor)
LAST UPDATE: $($result.Time)
"@
                    if (-not $current.ActionPowerShell) {
                        $current.Status.Text = if ($result.TemperatureRequiresElevation) {
                            "Administrator approval needed for CPU temperature"
                        } else {
                            "Monitoring active"
                        }
                    }
                }
            }
            catch {
                if (-not $current.ActionPowerShell) {
                    $current.Status.Text = "Monitoring error: $($_.Exception.Message)"
                }
            }
            finally {
                $current.MonitorPowerShell.Dispose()
                $current.MonitorPowerShell = $null
                $current.MonitorAsync = $null
            }
        }

        if ($current.ActionPowerShell -and $current.ActionAsync.IsCompleted) {
            $actionName = $current.ActionName
            try {
                $result = @($current.ActionPowerShell.EndInvoke($current.ActionAsync))
                if ($current.ActionPowerShell.Streams.Error.Count -gt 0) {
                    $lastError = $current.ActionPowerShell.Streams.Error[
                        $current.ActionPowerShell.Streams.Error.Count - 1
                    ]
                    throw $lastError.Exception.Message
                }
                if ($actionName -eq "CheckWinget" -and $result.Count -gt 0) {
                    $current.WingetAvailable = [bool]$result[-1].Available
                    $current.Downloader.StoreButton.Visible = [bool]$result[-1].StoreRequired
                    if ($current.WingetAvailable) {
                        $current.Downloader.WingetStatus.Text = "WinGet is ready."
                        $current.Downloader.WingetStatus.ForeColor = [Drawing.Color]::LightGreen
                    } else {
                        $current.Downloader.WingetStatus.Text = "App Installer is not available. Install it from Microsoft Store."
                        $current.Downloader.WingetStatus.ForeColor = [Drawing.Color]::Orange
                    }
                    Set-AppCatalog -Category $current.SelectedCategory
                    $current.Downloader.ActionStatus.Text = $current.Downloader.WingetStatus.Text
                } else {
                    $message = if ($result.Count -gt 0) {
                        [string]$result[-1]
                    } else {
                        "$actionName completed."
                    }
                    $current.Downloader.ActionStatus.Text = $message
                    $current.Status.Text = $message
                    if ($actionName -eq "ApplySystemPlan" -and
                        $current.ActivePlanKind -in @("ApplyDns", "RestoreDns")) {
                        $current.Utilities.NetworkStatus.Text = $message
                        $current.Utilities.RestoreDnsButton.Enabled = [bool](Get-LatestDnsBackup)
                    }
                }
            }
            catch {
                $failureDetail = $_.Exception.Message
                if ($actionName -eq "ApplySystemPlan" -and
                    (Test-Path -LiteralPath $current.ActionProgressPath)) {
                    try {
                        $helperProgress = Get-Content -LiteralPath $current.ActionProgressPath `
                            -Raw -ErrorAction Stop | ConvertFrom-Json
                        if ($helperProgress.State -eq "Failed" -and
                            -not [string]::IsNullOrWhiteSpace([string]$helperProgress.Detail)) {
                            $failureDetail = [string]$helperProgress.Detail
                        }
                    }
                    catch {
                        $failureDetail += " (Could not read elevated-action details: $($_.Exception.Message))"
                    }
                }
                $message = "$actionName failed: $failureDetail"
                $current.Downloader.ActionStatus.Text = $message
                $current.Status.Text = $message
                if ($actionName -eq "ApplySystemPlan" -and
                    $current.ActivePlanKind -in @("ApplyDns", "RestoreDns")) {
                    $current.Utilities.NetworkStatus.Text = $message
                }
                if ($actionName -eq "CheckWinget") {
                    $current.Downloader.WingetStatus.Text = $message
                    $current.Downloader.WingetStatus.ForeColor = [Drawing.Color]::Salmon
                    $current.Downloader.StoreButton.Visible = $true
                }
            }
            finally {
                $current.ActionPowerShell.Dispose()
                $current.ActionRunspace.Close()
                $current.ActionRunspace.Dispose()
                $current.ActionPowerShell = $null
                $current.ActionRunspace = $null
                $current.ActionAsync = $null
                $current.ActionName = ""
                $current.ActivePlanKind = ""
                if ($current.ActionProgressPathOwned -and
                    (Test-Path -LiteralPath $current.ActionProgressPath)) {
                    Remove-Item -LiteralPath $current.ActionProgressPath -Force -ErrorAction SilentlyContinue
                }
                $current.ActionProgressPath = ""
                $current.ActionProgressPathOwned = $false
                $current.Progress.Style = "Continuous"
                $current.Progress.Value = 0
                $current.Progress.Visible = $false
                if ($actionName -eq "SetAutomaticUpdates") {
                    Update-AutoUpdateStatus
                }
            }
        }

        if (-not $current.MonitorAsync) {
            Start-MonitorRefresh
        }
    })

    $form.Add_Shown({
        $timer.Start()
        Start-MonitorRefresh
        Update-AutoUpdateStatus
        Initialize-UtilityOptions
        Set-AppCatalog -Category "All"
        Start-BackgroundAction -Name "WinGet setup" -Action "CheckWinget"
    })

    $form.Add_FormClosing({
        $timer.Stop()
        $current = $form.Tag
        if ($current.MonitorPowerShell) {
            if ($current.MonitorAsync -and -not $current.MonitorAsync.IsCompleted) {
                $current.MonitorPowerShell.Stop()
            }
            $current.MonitorPowerShell.Dispose()
        }
        $current.MonitorRunspace.Close()
        $current.MonitorRunspace.Dispose()
        foreach ($navButton in $current.NavButtons) {
            if ($navButton.Image) {
                $navButton.Image.Dispose()
            }
        }

        if ($current.ActionPowerShell) {
            if ($current.ActionAsync -and -not $current.ActionAsync.IsCompleted) {
                $current.ActionPowerShell.Stop()
            }
            $current.ActionPowerShell.Dispose()
        }
        if ($current.ActionRunspace) {
            $current.ActionRunspace.Close()
            $current.ActionRunspace.Dispose()
        }
        $timer.Dispose()
    })

    Set-AppCatalog -Category "All"
    [void]$form.ShowDialog()
}
