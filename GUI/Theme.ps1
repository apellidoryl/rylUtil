function New-RylLabel {
    param(
        [string]$Text,
        [Drawing.Point]$Location,
        [Drawing.Size]$Size,
        [hashtable]$Theme,
        [int]$FontSize = 10,
        [Drawing.Color]$Color = [Drawing.Color]::White,
        [switch]$Bold
    )

    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.Location = $Location
    $label.Size = $Size
    $label.ForeColor = $Color
    $style = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $label.Font = New-Object Drawing.Font("Segoe UI", $FontSize, $style)
    return $label
}

function New-RylButton {
    param(
        [string]$Text,
        [Drawing.Point]$Location,
        [Drawing.Size]$Size,
        [hashtable]$Theme,
        [switch]$Primary
    )

    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Location = $Location
    $button.Size = $Size
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = if ($Primary) { $Theme.Accent } else { $Theme.Panel }
    $button.ForeColor = [Drawing.Color]::White
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    return $button
}

function New-RylGlyphBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$Glyph,
        [Drawing.Color]$Color = [Drawing.Color]::White,
        [int]$Size = 18
    )

    if ($Glyph -notmatch '^[0-9A-Fa-f]{4,6}$') {
        throw "Invalid Segoe MDL2 glyph '$Glyph'."
    }

    $bitmap = New-Object Drawing.Bitmap($Size, $Size)
    $graphics = $null
    $font = $null
    $brush = $null
    $format = $null
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $font = New-Object Drawing.Font(
            "Segoe MDL2 Assets",
            [single]($Size - 2),
            [Drawing.FontStyle]::Regular,
            [Drawing.GraphicsUnit]::Pixel
        )
        $brush = New-Object Drawing.SolidBrush($Color)
        $format = New-Object Drawing.StringFormat
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $format.Alignment = [Drawing.StringAlignment]::Center
        $format.LineAlignment = [Drawing.StringAlignment]::Center
        $text = [char]::ConvertFromUtf32([Convert]::ToInt32($Glyph, 16))
        $rectangle = New-Object Drawing.RectangleF(0, 0, $Size, $Size)
        $graphics.DrawString($text, $font, $brush, $rectangle, $format)
    }
    catch {
        $bitmap.Dispose()
        throw
    }
    finally {
        foreach ($resource in @($format, $brush, $font, $graphics)) {
            if ($resource) {
                $resource.Dispose()
            }
        }
    }

    return $bitmap
}

function New-RylPage {
    param([hashtable]$Theme, [Drawing.Size]$Size)

    $page = New-Object Windows.Forms.Panel
    $page.Size = $Size
    $page.Anchor = "Top, Bottom, Left, Right"
    $page.BackColor = $Theme.Background
    return $page
}

function New-RylPageHeading {
    param([string]$Text, [hashtable]$Theme)

    return New-RylLabel -Text $Text `
        -Location (New-Object Drawing.Point(26, 24)) `
        -Size (New-Object Drawing.Size(760, 32)) `
        -Theme $Theme -FontSize 17 -Bold
}
