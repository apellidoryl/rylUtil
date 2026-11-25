function New-RylMonitorPage {
    param([hashtable]$Theme, [Drawing.Size]$Size)

    $page = New-RylPage -Theme $Theme -Size $Size
    $heading = New-RylPageHeading -Text "System overview" -Theme $Theme
    $page.Controls.Add($heading)

    $cards = @{}
    $cardSpecs = @(
        @{ Key = "CPU"; Title = "CPU LOAD"; Left = 26; Top = 77; Color = [Drawing.Color]::LightSkyBlue; FontSize = 23; ShowBar = $true },
        @{ Key = "RAM"; Title = "MEMORY IN USE"; Left = 298; Top = 77; Color = [Drawing.Color]::LightGreen; FontSize = 23; ShowBar = $true },
        @{ Key = "Temp"; Title = "CPU TEMPERATURE"; Left = 570; Top = 77; Color = [Drawing.Color]::Orange; FontSize = 23; ShowBar = $true },
        @{ Key = "Disk"; Title = "SYSTEM DRIVE"; Left = 26; Top = 245; Color = [Drawing.Color]::LightSkyBlue; FontSize = 21; ShowBar = $true },
        @{ Key = "Network"; Title = "NETWORK RX / TX"; Left = 298; Top = 245; Color = [Drawing.Color]::LightGreen; FontSize = 10; ShowBar = $true },
        @{ Key = "Uptime"; Title = "SYSTEM UPTIME"; Left = 570; Top = 245; Color = [Drawing.Color]::Plum; FontSize = 19; ShowBar = $false }
    )

    foreach ($spec in $cardSpecs) {
        $panel = New-Object Windows.Forms.Panel
        $panel.Location = New-Object Drawing.Point($spec.Left, $spec.Top)
        $panel.Size = New-Object Drawing.Size(250, 145)
        $panel.BackColor = $Theme.Panel

        $caption = New-RylLabel -Text $spec.Title `
            -Location (New-Object Drawing.Point(18, 15)) `
            -Size (New-Object Drawing.Size(215, 24)) -Theme $Theme -Color $Theme.Muted
        $value = New-RylLabel -Text "Waiting for sample..." `
            -Location (New-Object Drawing.Point(18, 49)) `
            -Size (New-Object Drawing.Size(215, 48)) -Theme $Theme `
            -FontSize $spec.FontSize -Color $spec.Color -Bold
        $bar = $null
        if ($spec.ShowBar) {
            $bar = New-Object Windows.Forms.ProgressBar
            $bar.Location = New-Object Drawing.Point(18, 111)
            $bar.Size = New-Object Drawing.Size(213, 9)
            $panel.Controls.Add($bar)
        }

        $panel.Controls.Add($caption)
        $panel.Controls.Add($value)
        $page.Controls.Add($panel)
        $cards[$spec.Key] = @{ Value = $value; Bar = $bar }
    }

    $detailsY = 410
    $detailsHeight = [int][math]::Min(180, [math]::Max(90, ($Size.Height - 490)))
    $buttonY = [int]($detailsY + $detailsHeight + 20)
    $detailsWidth = [int]($Size.Width - 52)
    $details = New-Object Windows.Forms.TextBox
    $details.Location = New-Object Drawing.Point(26, $detailsY)
    $details.Size = New-Object Drawing.Size($detailsWidth, $detailsHeight)
    $details.Anchor = "Top, Left, Right"
    $details.Multiline = $true
    $details.ReadOnly = $true
    $details.BackColor = $Theme.Panel
    $details.ForeColor = [Drawing.Color]::FromArgb(203, 215, 232)
    $details.BorderStyle = "None"
    $details.Font = New-Object Drawing.Font("Consolas", 10)
    $page.Controls.Add($details)

    $refresh = New-RylButton -Text "Refresh now" `
        -Location (New-Object Drawing.Point(26, $buttonY)) `
        -Size (New-Object Drawing.Size(145, 39)) -Theme $Theme -Primary
    $page.Controls.Add($refresh)

    $elevate = New-RylButton -Text "Restart as administrator" `
        -Location (New-Object Drawing.Point(187, $buttonY)) `
        -Size (New-Object Drawing.Size(220, 39)) -Theme $Theme
    $elevate.Visible = $false
    $page.Controls.Add($elevate)

    return [PSCustomObject]@{
        Panel = $page
        Cards = $cards
        Details = $details
        RefreshButton = $refresh
        ElevationButton = $elevate
    }
}
