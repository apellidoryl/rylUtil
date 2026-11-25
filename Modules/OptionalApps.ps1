function Get-RylApprovedOptionalPackageNames {
    return @(
        "Clipchamp.Clipchamp",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.GamingApp",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.YourPhone",
        "Microsoft.3DBuilder",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MixedReality.Portal",
        "Microsoft.People",
        "Microsoft.WindowsMaps",
        "Microsoft.SkypeApp",
        "Microsoft.OneConnect",
        "Microsoft.Messaging",
        "Microsoft.Print3D",
        "Microsoft.BingFinance",
        "Microsoft.BingSports"
    )
}

function Get-RylOptionalApps {
    param([Parameter(Mandatory = $true)][string]$Root)

    $path = Join-Path $Root "Bloatware.xml"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Optional-app allowlist was not found: $path"
    }

    [xml]$catalog = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
    $installed = Get-AppxPackage -ErrorAction Stop
    $approvedNames = @(Get-RylApprovedOptionalPackageNames)
    $apps = @()
    foreach ($entry in $catalog.OptionalApps.App) {
        $packageName = [string]$entry.PackageName
        if ($packageName -notmatch '^[A-Za-z0-9._-]+$') {
            throw "Invalid optional-app package name '$packageName' in '$path'."
        }
        if ($packageName -notin $approvedNames) {
            throw "Optional-app package '$packageName' is not in the approved removal list."
        }

        foreach ($package in @($installed | Where-Object { $_.Name -eq $packageName })) {
            $apps += [PSCustomObject]@{
                DisplayName = [string]$entry.DisplayName
                PackageName = $package.Name
                PackageFullName = $package.PackageFullName
                Version = [string]$package.Version
                Description = [string]$entry.Description
            }
        }
    }
    return $apps
}
