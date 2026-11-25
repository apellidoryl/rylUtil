function New-RylWpfQuickSetupCard {
    param([Parameter(Mandatory = $true)][PSCustomObject]$App)

    $content = New-Object System.Windows.Controls.StackPanel
    $heading = New-Object System.Windows.Controls.StackPanel
    $heading.Orientation = "Horizontal"
    $iconBorder = New-Object System.Windows.Controls.Border
    $iconBorder.Width = 44
    $iconBorder.Height = 44
    $iconBorder.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $iconBorder.Background = ConvertTo-RylBrush ([string]$App.Color)
    $iconBorder.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    if ($App.IconPath -and (Test-Path -LiteralPath $App.IconPath)) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = New-Object System.Uri([IO.Path]::GetFullPath($App.IconPath))
        $bitmap.EndInit()
        $image = New-Object System.Windows.Controls.Image
        $image.Source = $bitmap
        $image.Stretch = "Uniform"
        $image.Margin = New-Object System.Windows.Thickness(7)
        $iconBorder.Child = $image
    } else {
        $glyph = if ($App.IconGlyph) {
            [char]::ConvertFromUtf32([Convert]::ToInt32($App.IconGlyph, 16))
        } else {
            [string]$App.Icon
        }
        $glyphText = New-RylWpfText -Text $glyph -FontSize 21 -Bold
        $glyphText.HorizontalAlignment = "Center"
        $glyphText.VerticalAlignment = "Center"
        $iconBorder.Child = $glyphText
    }
    [void]$heading.Children.Add($iconBorder)
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Content = New-RylWpfText -Text ([string]$App.Name) -FontSize 13 -Bold -Wrap
    $check.Tag = $App
    $check.VerticalAlignment = "Center"
    [void]$heading.Children.Add($check)
    [void]$content.Children.Add($heading)
    $description = New-RylWpfText -Text ([string]$App.Description) -FontSize 11 `
        -Color "#AAB6CA" -Wrap
    $description.Margin = New-Object System.Windows.Thickness(0, 10, 0, 8)
    [void]$content.Children.Add($description)
    $status = New-RylWpfText -Text "Checking offline files..." -FontSize 11 `
        -Color "#9DA9BE" -Wrap
    [void]$content.Children.Add($status)
    $card = New-RylWpfCard -Content $content
    $card.Width = 275
    $card.MinHeight = 142
    $card.Padding = New-Object System.Windows.Thickness(13)
    return [PSCustomObject]@{
        Border = $card
        CheckBox = $check
        Status = $status
        App = $App
    }
}

function New-RylWpfQuickSetupPage {
    param(
        [Parameter(Mandatory = $true)][PSCustomObject[]]$Apps,
        [Parameter(Mandatory = $true)][string]$OfflineDirectory
    )

    $appsById = @{}
    foreach ($app in $Apps) {
        $appsById[[string]$app.PackageId] = $app
    }
    $cards = @()
    foreach ($packageId in (Get-RylQuickSetupPackageIds)) {
        if (-not $appsById.ContainsKey($packageId)) {
            throw "Quick Setup package '$packageId' is missing from Apps.xml."
        }
        $cards += New-RylWpfQuickSetupCard -App $appsById[$packageId]
    }

    $grid = New-Object System.Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))

    $header = New-Object System.Windows.Controls.StackPanel
    [void]$header.Children.Add((New-RylWpfText -Text "Quick setup" -FontSize 21 -Bold))
    [void]$header.Children.Add((New-RylWpfText `
        -Text "Use installers already in offline_apps, or download apps here, then install only the apps you select." `
        -FontSize 12 -Color "#AAB6CA" -Wrap))
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    [void]$grid.Children.Add($header)

    $options = New-Object System.Windows.Controls.StackPanel
    $options.Margin = New-Object System.Windows.Thickness(0, 12, 0, 8)
    $commands = New-Object System.Windows.Controls.WrapPanel
    $selectAll = New-RylWpfButton -Text "Select all"
    $selectNone = New-RylWpfButton -Text "Select none"
    $download = New-RylWpfButton -Text "Download selected" -Primary $true
    $download.IsEnabled = $false
    $install = New-RylWpfButton -Text "Install selected"
    $refresh = New-RylWpfButton -Text "Refresh status"
    $openFolder = New-RylWpfButton -Text "Open offline folder"
    foreach ($button in @($selectAll, $selectNone, $download, $install, $refresh, $openFolder)) {
        [void]$commands.Children.Add($button)
    }
    [void]$options.Children.Add($commands)

    $modeRow = New-Object System.Windows.Controls.StackPanel
    $modeRow.Orientation = "Horizontal"
    $modeRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 7)
    $modeLabel = New-RylWpfText -Text "Install mode:" -FontSize 12 -Color "#AAB6CA"
    $modeLabel.VerticalAlignment = "Center"
    $modeLabel.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
    [void]$modeRow.Children.Add($modeLabel)
    $sequence = New-Object System.Windows.Controls.RadioButton
    $sequence.Content = "Sequence (recommended)"
    $sequence.GroupName = "QuickSetupInstallMode"
    $sequence.IsChecked = $true
    $sequence.Foreground = ConvertTo-RylBrush "#E6EBF4"
    $sequence.Margin = New-Object System.Windows.Thickness(0, 0, 18, 0)
    [void]$modeRow.Children.Add($sequence)
    $parallel = New-Object System.Windows.Controls.RadioButton
    $parallel.Content = "Parallel (may conflict or show multiple UAC prompts)"
    $parallel.GroupName = "QuickSetupInstallMode"
    $parallel.Foreground = ConvertTo-RylBrush "#E6EBF4"
    [void]$modeRow.Children.Add($parallel)
    [void]$options.Children.Add($modeRow)

    $warning = New-RylWpfText -Text `
        "Brave, Chrome, OfficeSetup.exe, and the Adobe Reader downloader need Internet access. For a full Microsoft 365 offline source, use Download selected (several GB); an eligible license is required, and activation may need Internet." `
        -FontSize 11 -Color "#FFB36B" -Wrap
    [void]$options.Children.Add($warning)
    [System.Windows.Controls.Grid]::SetRow($options, 1)
    [void]$grid.Children.Add($options)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    $scroll.HorizontalScrollBarVisibility = "Disabled"
    $panel = New-Object System.Windows.Controls.WrapPanel
    $panel.Margin = New-Object System.Windows.Thickness(0, 4, 0, 4)
    foreach ($card in $cards) {
        [void]$panel.Children.Add($card.Border)
    }
    $scroll.Content = $panel
    [System.Windows.Controls.Grid]::SetRow($scroll, 2)
    [void]$grid.Children.Add($scroll)

    $footer = New-Object System.Windows.Controls.StackPanel
    $status = New-RylWpfText -Text `
        "Choose apps, download installers, and then install the selected apps." `
        -FontSize 11 -Color "#AAB6CA" -Wrap
    [void]$footer.Children.Add($status)
    $folderText = New-RylWpfText -Text "Offline folder: $OfflineDirectory" `
        -FontSize 10 -Color "#8593AA" -Wrap
    [void]$footer.Children.Add($folderText)
    [System.Windows.Controls.Grid]::SetRow($footer, 3)
    [void]$grid.Children.Add($footer)

    return @{
        Page = $grid
        Cards = $cards
        SelectAllButton = $selectAll
        SelectNoneButton = $selectNone
        DownloadButton = $download
        InstallButton = $install
        RefreshButton = $refresh
        OpenFolderButton = $openFolder
        SequenceMode = $sequence
        ParallelMode = $parallel
        Status = $status
    }
}
