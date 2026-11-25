function Get-RylSettings {
    param([Parameter(Mandatory = $true)][string]$Root)

    $settings = @{
        RefreshInterval = 3000
        OfflineDirectory = Join-Path $Root "offline_apps"
        Background = "#11151F"
        Sidebar = "#161B27"
        Panel = "#1E2534"
        Accent = "#4784ED"
        Muted = "#9DA9BE"
    }

    $configPath = Join-Path $Root "Config.xml"
    if (-not (Test-Path -LiteralPath $configPath)) {
        return $settings
    }

    try {
        [xml]$config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop
        if ($config.Settings.Monitor.RefreshInterval) {
            $interval = [int]$config.Settings.Monitor.RefreshInterval
            if ($interval -lt 1000 -or $interval -gt 60000) {
                throw "Monitor refresh interval must be between 1000 and 60000 milliseconds."
            }
            $settings.RefreshInterval = $interval
        }

        if ($config.Settings.Theme.Background) {
            $settings.Background = [string]$config.Settings.Theme.Background
        }
        if ($config.Settings.Theme.Sidebar) {
            $settings.Sidebar = [string]$config.Settings.Theme.Sidebar
        }
        if ($config.Settings.Theme.Panel) {
            $settings.Panel = [string]$config.Settings.Theme.Panel
        }
        if ($config.Settings.Theme.Accent) {
            $settings.Accent = [string]$config.Settings.Theme.Accent
        }
        if ($config.Settings.Theme.Muted) {
            $settings.Muted = [string]$config.Settings.Theme.Muted
        }

        if ($config.Settings.Downloads.OfflineDirectory) {
            $relativeDirectory = [string]$config.Settings.Downloads.OfflineDirectory
            if ([IO.Path]::IsPathRooted($relativeDirectory)) {
                throw "Downloads.OfflineDirectory must be relative to the application folder."
            }
            $settings.OfflineDirectory = Join-Path $Root $relativeDirectory
        }
    }
    catch {
        throw "Cannot read application configuration '$configPath': $($_.Exception.Message)"
    }

    return $settings
}
