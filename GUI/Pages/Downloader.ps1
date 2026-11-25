function New-RylDownloaderPage {
    param(
        [hashtable]$Theme,
        [Drawing.Size]$Size,
        [string]$OfflineDirectory,
        [string[]]$Categories
    )

    $page = New-RylPage -Theme $Theme -Size $Size
    $heading = New-RylPageHeading -Text "App downloader" -Theme $Theme
    $page.Controls.Add($heading)

    $searchLabel = New-RylLabel -Text "Search apps" `
        -Location (New-Object Drawing.Point(28, 56)) `
        -Size (New-Object Drawing.Size(76, 22)) -Theme $Theme -Color $Theme.Muted
    $searchBox = New-Object Windows.Forms.TextBox
    $searchBox.Location = New-Object Drawing.Point(106, 52)
    $searchBox.Size = New-Object Drawing.Size(236, 27)
    $searchBox.BackColor = $Theme.Panel
    $searchBox.ForeColor = [Drawing.Color]::White
    $searchBox.BorderStyle = "FixedSingle"
    $searchBox.AccessibleName = "Search apps by name, category, description, or package ID"
    $statusWidth = [int][math]::Max(180, ($Size.Width - 700))
    $wingetStatus = New-RylLabel -Text "Checking WinGet..." `
        -Location (New-Object Drawing.Point(360, 54)) `
        -Size (New-Object Drawing.Size($statusWidth, 24)) `
        -Theme $Theme -Color $Theme.Muted
    $wingetStatus.Anchor = "Top, Left, Right"
    $contentWidth = [int]($Size.Width - 52)
    $retryX = [int]($Size.Width - 330)
    $storeX = [int]($Size.Width - 175)
    $retryButton = New-RylButton -Text "Retry WinGet setup" `
        -Location (New-Object Drawing.Point($retryX, 20)) `
        -Size (New-Object Drawing.Size(145, 34)) -Theme $Theme
    $retryButton.Anchor = "Top, Right"
    $storeButton = New-RylButton -Text "Get App Installer" `
        -Location (New-Object Drawing.Point($storeX, 20)) `
        -Size (New-Object Drawing.Size(145, 34)) -Theme $Theme
    $storeButton.Anchor = "Top, Right"
    $storeButton.Visible = $false

    $categoryPanel = New-Object Windows.Forms.FlowLayoutPanel
    $categoryPanel.Location = New-Object Drawing.Point(26, 88)
    $categoryPanel.Size = New-Object Drawing.Size($contentWidth, 39)
    $categoryPanel.Anchor = "Top, Left, Right"
    $categoryPanel.WrapContents = $false
    $categoryPanel.BackColor = $Theme.Background

    $categories = @("All") + @($Categories | Sort-Object -Unique)
    $categoryPanel.AutoScroll = $true
    $categoryButtons = @()
    foreach ($category in $categories) {
        $button = New-RylButton -Text $category `
            -Location (New-Object Drawing.Point(0, 0)) `
            -Size (New-Object Drawing.Size(96, 32)) -Theme $Theme
        $button.Tag = $category
        $button.Margin = New-Object Windows.Forms.Padding(0, 0, 7, 0)
        if ($category -eq "All") {
            $button.BackColor = $Theme.Accent
        }
        $categoryPanel.Controls.Add($button)
        $categoryButtons += $button
    }

    $appPanel = New-Object Windows.Forms.FlowLayoutPanel
    $appPanel.Location = New-Object Drawing.Point(26, 137)
    $appHeight = [int][math]::Max(250, ($Size.Height - 277))
    $appPanel.Size = New-Object Drawing.Size($contentWidth, $appHeight)
    $appPanel.Anchor = "Top, Bottom, Left, Right"
    $appPanel.AutoScroll = $true
    $appPanel.WrapContents = $true
    $appPanel.BackColor = $Theme.Background

    $offlineY = [int]($Size.Height - 123)
    $folderX = [int]($Size.Width - 168)
    $statusY = [int]($Size.Height - 92)
    $offlineLabelWidth = [int]($Size.Width - 222)
    $actionStatusWidth = [int]($Size.Width - 56)
    $offlineLabel = New-RylLabel -Text "Offline installers: $OfflineDirectory" `
        -Location (New-Object Drawing.Point(28, $offlineY)) `
        -Size (New-Object Drawing.Size($offlineLabelWidth, 22)) -Theme $Theme -Color $Theme.Muted
    $offlineLabel.Anchor = "Bottom, Left, Right"
    $openFolder = New-RylButton -Text "Open folder" `
        -Location (New-Object Drawing.Point($folderX, ($offlineY - 5))) `
        -Size (New-Object Drawing.Size(142, 32)) -Theme $Theme
    $openFolder.Anchor = "Bottom, Right"

    $actionStatus = New-RylLabel -Text "Ready" `
        -Location (New-Object Drawing.Point(28, $statusY)) `
        -Size (New-Object Drawing.Size($actionStatusWidth, 24)) -Theme $Theme -Color $Theme.Muted
    $actionStatus.Anchor = "Bottom, Left, Right"

    foreach ($control in @($searchLabel, $searchBox, $wingetStatus, $retryButton, $storeButton, $categoryPanel, $appPanel, $offlineLabel, $openFolder, $actionStatus)) {
        $page.Controls.Add($control)
    }

    return [PSCustomObject]@{
        Panel = $page
        WingetStatus = $wingetStatus
        SearchBox = $searchBox
        RetryButton = $retryButton
        StoreButton = $storeButton
        CategoryPanel = $categoryPanel
        CategoryButtons = $categoryButtons
        AppPanel = $appPanel
        OfflineDirectory = $OfflineDirectory
        OpenFolderButton = $openFolder
        ActionStatus = $actionStatus
    }
}

function New-RylAppTile {
    param(
        [PSCustomObject]$App,
        [hashtable]$Theme,
        [bool]$WingetAvailable
    )

    $tile = New-Object Windows.Forms.Panel
    $tile.Size = New-Object Drawing.Size(252, 138)
    $tile.Margin = New-Object Windows.Forms.Padding(0, 0, 14, 14)
    $tile.BackColor = $Theme.Panel
    $tile.BorderStyle = "FixedSingle"

    $hasIconImage = $App.IconPath -and (Test-Path -LiteralPath $App.IconPath)
    if ($hasIconImage) {
        $icon = New-Object Windows.Forms.PictureBox
        $icon.SizeMode = "Zoom"
        $icon.Image = [Drawing.Image]::FromFile($App.IconPath)
        $icon.BorderStyle = "None"
    } else {
        $icon = New-Object Windows.Forms.Label
        $icon.TextAlign = "MiddleCenter"
        if ($App.IconGlyph) {
            $icon.Font = New-Object Drawing.Font("Segoe MDL2 Assets", 20, [Drawing.FontStyle]::Regular)
            $icon.Text = [char]::ConvertFromUtf32([Convert]::ToInt32($App.IconGlyph, 16))
        } else {
            $icon.Font = New-Object Drawing.Font("Segoe UI", 13, [Drawing.FontStyle]::Bold)
            $icon.Text = $App.Icon
        }
    }
    $icon.Location = New-Object Drawing.Point(14, 14)
    $icon.Size = New-Object Drawing.Size(46, 46)
    $icon.BackColor = [Drawing.ColorTranslator]::FromHtml($App.Color)
    $icon.AccessibleName = "$($App.Name) icon"
    if (-not $hasIconImage) {
        $icon.ForeColor = [Drawing.Color]::White
    }

    $name = New-RylLabel -Text $App.Name `
        -Location (New-Object Drawing.Point(72, 15)) `
        -Size (New-Object Drawing.Size(170, 23)) -Theme $Theme -FontSize 10 -Bold
    $category = New-RylLabel -Text $App.Category `
        -Location (New-Object Drawing.Point(72, 41)) `
        -Size (New-Object Drawing.Size(165, 20)) -Theme $Theme -FontSize 8 -Color $Theme.Muted
    $description = New-RylLabel -Text $App.Description `
        -Location (New-Object Drawing.Point(14, 64)) `
        -Size (New-Object Drawing.Size(222, 29)) -Theme $Theme -FontSize 8 -Color $Theme.Muted
    $install = New-RylButton -Text ("{0} Install" -f [char]0x2191) `
        -Location (New-Object Drawing.Point(14, 101)) `
        -Size (New-Object Drawing.Size(96, 27)) -Theme $Theme -Primary
    $install.Font = New-Object Drawing.Font("Segoe UI", 8)
    $install.Enabled = $WingetAvailable
    $install.Tag = @{ Action = "InstallApp"; App = $App }

    $download = New-RylButton -Text ("{0} Download installer" -f [char]0x2193) `
        -Location (New-Object Drawing.Point(116, 101)) `
        -Size (New-Object Drawing.Size(128, 27)) -Theme $Theme
    $download.Font = New-Object Drawing.Font("Segoe UI", 7.5)
    $download.Visible = $App.OfflineDownload
    $download.Enabled = $WingetAvailable -and $App.OfflineDownload
    $download.Tag = @{ Action = "DownloadOfflineApp"; App = $App }

    $tile.Controls.Add($icon)
    $tile.Controls.Add($name)
    $tile.Controls.Add($category)
    $tile.Controls.Add($description)
    $tile.Controls.Add($install)
    $tile.Controls.Add($download)
    return $tile
}
