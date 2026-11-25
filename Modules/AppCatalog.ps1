function Get-RylAppCatalog {
    param([Parameter(Mandatory = $true)][string]$Root)

    $catalogPath = Join-Path $Root "Apps.xml"
    if (-not (Test-Path -LiteralPath $catalogPath)) {
        throw "App catalog was not found: $catalogPath"
    }

    try {
        [xml]$catalog = Get-Content -LiteralPath $catalogPath -Raw -ErrorAction Stop
    }
    catch {
        throw "Cannot read app catalog '$catalogPath': $($_.Exception.Message)"
    }

    $apps = @()
    foreach ($entry in $catalog.Apps.App) {
        $packageId = [string]$entry.PackageId
        if ([string]::IsNullOrWhiteSpace($packageId) -or $packageId -notmatch '^[A-Za-z0-9._+-]+$') {
            throw "Invalid package ID in app catalog: '$packageId'."
        }

        $iconGlyph = [string]$entry.IconGlyph
        if (-not [string]::IsNullOrWhiteSpace($iconGlyph) -and
            $iconGlyph -notmatch '^[0-9A-Fa-f]{4,6}$') {
            throw "Invalid icon glyph for '$($entry.Name)': '$iconGlyph'."
        }

        $iconPath = $null
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.IconPath)) {
            $iconPath = Join-Path $Root ([string]$entry.IconPath)
        }

        $apps += [PSCustomObject]@{
            Name = [string]$entry.Name
            PackageId = $packageId
            Category = [string]$entry.Category
            Icon = [string]$entry.Icon
            IconGlyph = $iconGlyph
            IconPath = $iconPath
            Color = [string]$entry.Color
            OfflineDownload = [bool]::Parse([string]$entry.OfflineDownload)
            Description = [string]$entry.Description
        }
    }

    if ($apps.Count -eq 0) {
        throw "The app catalog '$catalogPath' contains no apps."
    }

    return $apps
}
