function New-RylUtilitiesPage {
    param([hashtable]$Theme, [Drawing.Size]$Size)

    $page = New-RylPage -Theme $Theme -Size $Size
    $page.Controls.Add((New-RylPageHeading -Text "System utilities" -Theme $Theme))

    $tabsWidth = [int]($Size.Width - 52)
    $tabsHeight = [int]($Size.Height - 109)
    $tabs = New-Object Windows.Forms.TabControl
    $tabs.Location = New-Object Drawing.Point(26, 74)
    $tabs.Size = New-Object Drawing.Size($tabsWidth, $tabsHeight)
    $tabs.Anchor = "Top, Bottom, Left, Right"
    $tabs.Font = New-Object Drawing.Font("Segoe UI", 9)

    $networkTab = New-Object Windows.Forms.TabPage
    $networkTab.Text = "Network / DNS"
    $networkTab.BackColor = $Theme.Background
    $networkTab.AutoScroll = $true
    $networkTab.AutoScrollMargin = New-Object Drawing.Size(12, 12)
    $optimizationTab = New-Object Windows.Forms.TabPage
    $optimizationTab.Text = "PC optimization"
    $optimizationTab.BackColor = $Theme.Background
    $optimizationTab.AutoScroll = $true
    $optimizationTab.AutoScrollMargin = New-Object Drawing.Size(12, 12)
    $updatesTab = New-Object Windows.Forms.TabPage
    $updatesTab.Text = "Windows updates"
    $updatesTab.BackColor = $Theme.Background
    $updatesTab.AutoScroll = $true
    $updatesTab.AutoScrollMargin = New-Object Drawing.Size(12, 12)
    $quickToolsTab = New-Object Windows.Forms.TabPage
    $quickToolsTab.Text = "Quick tools"
    $quickToolsTab.BackColor = $Theme.Background
    $quickToolsTab.AutoScroll = $true
    $quickToolsTab.AutoScrollMargin = New-Object Drawing.Size(12, 12)
    $tabs.TabPages.AddRange(@($networkTab, $optimizationTab, $updatesTab, $quickToolsTab))

    $adapterLabel = New-RylLabel -Text "Network adapter" `
        -Location (New-Object Drawing.Point(20, 20)) `
        -Size (New-Object Drawing.Size(300, 22)) -Theme $Theme -Bold
    $adapter = New-Object Windows.Forms.ComboBox
    $adapter.Location = New-Object Drawing.Point(20, 47)
    $adapter.Size = New-Object Drawing.Size(350, 30)
    $adapter.DropDownStyle = "DropDownList"
    $adapter.DisplayMember = "Name"
    $adapter.BackColor = $Theme.Panel
    $adapter.ForeColor = [Drawing.Color]::White

    $dnsLabel = New-RylLabel -Text "DNS provider" `
        -Location (New-Object Drawing.Point(20, 97)) `
        -Size (New-Object Drawing.Size(300, 22)) -Theme $Theme -Bold
    $dnsProfile = New-Object Windows.Forms.ComboBox
    $dnsProfile.Location = New-Object Drawing.Point(20, 124)
    $dnsProfile.Size = New-Object Drawing.Size(350, 30)
    $dnsProfile.DropDownStyle = "DropDownList"
    $dnsProfile.DisplayMember = "Name"
    $dnsProfile.BackColor = $Theme.Panel
    $dnsProfile.ForeColor = [Drawing.Color]::White
    $dnsDescription = New-RylLabel -Text "Choose a provider to view its DNS servers." `
        -Location (New-Object Drawing.Point(20, 163)) `
        -Size (New-Object Drawing.Size(535, 42)) -Theme $Theme -Color $Theme.Muted
    $applyDns = New-RylButton -Text "Apply DNS profile" `
        -Location (New-Object Drawing.Point(20, 225)) `
        -Size (New-Object Drawing.Size(180, 38)) -Theme $Theme -Primary
    $restoreDns = New-RylButton -Text "Restore last DNS backup" `
        -Location (New-Object Drawing.Point(214, 225)) `
        -Size (New-Object Drawing.Size(205, 38)) -Theme $Theme
    $flushDns = New-RylButton -Text "Flush DNS cache" `
        -Location (New-Object Drawing.Point(20, 278)) `
        -Size (New-Object Drawing.Size(180, 38)) -Theme $Theme
    $networkStatus = New-RylLabel -Text "DNS changes save a backup of the selected adapter settings." `
        -Location (New-Object Drawing.Point(20, 333)) `
        -Size (New-Object Drawing.Size(730, 50)) -Theme $Theme -Color $Theme.Muted
    foreach ($control in @($adapterLabel, $adapter, $dnsLabel, $dnsProfile, $dnsDescription, $applyDns, $restoreDns, $flushDns, $networkStatus)) {
        $networkTab.Controls.Add($control)
    }

    $minimal = New-RylButton -Text "Minimal" `
        -Location (New-Object Drawing.Point(18, 14)) `
        -Size (New-Object Drawing.Size(116, 34)) -Theme $Theme
    $standard = New-RylButton -Text "Standard" `
        -Location (New-Object Drawing.Point(143, 14)) `
        -Size (New-Object Drawing.Size(116, 34)) -Theme $Theme
    $full = New-RylButton -Text "Full" `
        -Location (New-Object Drawing.Point(268, 14)) `
        -Size (New-Object Drawing.Size(116, 34)) -Theme $Theme

    $tasksLabel = New-RylLabel -Text "Choose tasks (unchecked = unchanged)" `
        -Location (New-Object Drawing.Point(18, 58)) `
        -Size (New-Object Drawing.Size(300, 22)) -Theme $Theme -Bold
    $tasks = New-Object Windows.Forms.CheckedListBox
    $tasks.Location = New-Object Drawing.Point(18, 84)
    $tasks.Size = New-Object Drawing.Size(300, 146)
    $tasks.CheckOnClick = $true
    $tasks.BackColor = $Theme.Panel
    $tasks.ForeColor = [Drawing.Color]::White
    [void]$tasks.Items.Add("Flush DNS cache")
    [void]$tasks.Items.Add("Clean old files from Temp")
    [void]$tasks.Items.Add("Remove checked optional apps")

    $appsLabel = New-RylLabel -Text "Optional apps (allow-listed; none selected by default)" `
        -Location (New-Object Drawing.Point(336, 58)) `
        -Size (New-Object Drawing.Size(430, 22)) -Theme $Theme -Bold
    $optionalApps = New-Object Windows.Forms.CheckedListBox
    $optionalApps.Location = New-Object Drawing.Point(336, 84)
    $optionalApps.Size = New-Object Drawing.Size(430, 210)
    $optionalApps.CheckOnClick = $true
    $optionalApps.BackColor = $Theme.Panel
    $optionalApps.ForeColor = [Drawing.Color]::White

    $restorePoint = New-Object Windows.Forms.CheckBox
    $restorePoint.Location = New-Object Drawing.Point(18, 244)
    $restorePoint.Size = New-Object Drawing.Size(300, 25)
    $restorePoint.Text = "Create Windows restore point first"
    $restorePoint.Checked = $true
    $restorePoint.ForeColor = [Drawing.Color]::White
    $restorePoint.BackColor = $Theme.Background
    $applyOptimization = New-RylButton -Text "Apply selected tasks" `
        -Location (New-Object Drawing.Point(18, 284)) `
        -Size (New-Object Drawing.Size(180, 38)) -Theme $Theme -Primary
    $openRestore = New-RylButton -Text "Open System Restore" `
        -Location (New-Object Drawing.Point(212, 284)) `
        -Size (New-Object Drawing.Size(180, 38)) -Theme $Theme
    $safetyWarning = New-RylLabel -Text "Warning: temp cleanup and app removal may not be reversible. A restore point is recommended; removed apps may need reinstalling from Microsoft Store." `
        -Location (New-Object Drawing.Point(18, 342)) `
        -Size (New-Object Drawing.Size(748, 58)) -Theme $Theme -Color ([Drawing.Color]::Orange)
    foreach ($control in @($minimal, $standard, $full, $tasksLabel, $tasks, $appsLabel, $optionalApps, $restorePoint, $applyOptimization, $openRestore, $safetyWarning)) {
        $optimizationTab.Controls.Add($control)
    }

    $updateStatus = New-RylLabel -Text "Checking Windows Update policy..." `
        -Location (New-Object Drawing.Point(20, 26)) `
        -Size (New-Object Drawing.Size(720, 30)) -Theme $Theme -Color $Theme.Muted
    $updateDescription = New-RylLabel -Text "These controls set the machine-wide NoAutoUpdate policy and require administrator approval. Organization policy may override local settings." `
        -Location (New-Object Drawing.Point(20, 66)) `
        -Size (New-Object Drawing.Size(720, 58)) -Theme $Theme -Color $Theme.Muted
    $disableUpdates = New-RylButton -Text "Disable automatic updates" `
        -Location (New-Object Drawing.Point(20, 145)) `
        -Size (New-Object Drawing.Size(230, 40)) -Theme $Theme
    $enableUpdates = New-RylButton -Text "Enable automatic updates" `
        -Location (New-Object Drawing.Point(265, 145)) `
        -Size (New-Object Drawing.Size(230, 40)) -Theme $Theme -Primary
    foreach ($control in @($updateStatus, $updateDescription, $disableUpdates, $enableUpdates)) {
        $updatesTab.Controls.Add($control)
    }

    $quickDescription = New-RylLabel -Text "Shortcuts open Windows settings, tools, or web pages; remote code is not executed." `
        -Location (New-Object Drawing.Point(20, 20)) `
        -Size (New-Object Drawing.Size(760, 42)) -Theme $Theme -Color $Theme.Muted
    $quickTools = [ordered]@{}
    $quickToolSpecs = @(
        @{ Name = "Startup apps"; Target = "ms-settings:startupapps" },
        @{ Name = "Storage Sense"; Target = "ms-settings:storagesense" },
        @{ Name = "Installed apps"; Target = "ms-settings:appsfeatures" },
        @{ Name = "Power settings"; Target = "ms-settings:powersleep" },
        @{ Name = "Disk Cleanup"; Target = "cleanmgr.exe" },
        @{ Name = "Task Manager"; Target = "taskmgr.exe" },
        @{ Name = "Resource Monitor"; Target = "resmon.exe" },
        @{ Name = "Windows Security"; Target = "windowsdefender:" },
        @{ Name = "Windows activation"; Target = "Script:OpenActivationSettings.ps1" },
        @{ Name = "View activation script"; Target = "Script:OpenActivationScriptPage.ps1" }
    )
    for ($index = 0; $index -lt $quickToolSpecs.Count; $index++) {
        $spec = $quickToolSpecs[$index]
        $column = $index % 2
        $row = [math]::Floor($index / 2)
        $left = [int](20 + (295 * $column))
        $top = [int](82 + (54 * $row))
        $button = New-RylButton -Text $spec.Name `
            -Location (New-Object Drawing.Point($left, $top)) `
            -Size (New-Object Drawing.Size(270, 40)) -Theme $Theme
        $button.Tag = $spec.Target
        $quickTools[$spec.Name] = $button
        $quickToolsTab.Controls.Add($button)
    }
    $quickToolsTab.Controls.Add($quickDescription)

    $page.Controls.Add($tabs)
    return [PSCustomObject]@{
        Panel = $page
        Tabs = $tabs
        NetworkAdapter = $adapter
        DnsProfile = $dnsProfile
        DnsDescription = $dnsDescription
        ApplyDnsButton = $applyDns
        RestoreDnsButton = $restoreDns
        FlushDnsButton = $flushDns
        NetworkStatus = $networkStatus
        PresetButtons = @{ Minimal = $minimal; Standard = $standard; Full = $full }
        TaskList = $tasks
        OptionalApps = $optionalApps
        RestorePoint = $restorePoint
        ApplyOptimizationButton = $applyOptimization
        OpenRestoreButton = $openRestore
        SafetyWarning = $safetyWarning
        DisableUpdatesButton = $disableUpdates
        EnableUpdatesButton = $enableUpdates
        UpdateStatus = $updateStatus
        QuickTools = $quickTools
    }
}
