Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

. "$PSScriptRoot\..\Modules\Configuration.ps1"
. "$PSScriptRoot\..\Modules\AppCatalog.ps1"
. "$PSScriptRoot\..\Modules\SystemMonitor.ps1"
. "$PSScriptRoot\..\Modules\Network.ps1"
. "$PSScriptRoot\..\Modules\OptionalApps.ps1"
. "$PSScriptRoot\..\Modules\BackgroundActions.ps1"
. "$PSScriptRoot\Pages\QuickSetup.ps1"

function ConvertTo-RylBrush {
    param([Parameter(Mandatory = $true)][string]$Color)

    return New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    )
}

function New-RylWpfText {
    param(
        [string]$Text,
        [double]$FontSize = 13,
        [string]$Color = "#F3F6FC",
        [switch]$Bold,
        [switch]$Wrap
    )

    $control = New-Object System.Windows.Controls.TextBlock
    $control.Text = $Text
    $control.FontSize = $FontSize
    $control.Foreground = ConvertTo-RylBrush $Color
    if ($Bold) {
        $control.FontWeight = [System.Windows.FontWeights]::SemiBold
    }
    if ($Wrap) {
        $control.TextWrapping = [System.Windows.TextWrapping]::Wrap
    }
    return $control
}

function New-RylWpfButton {
    param(
        [string]$Text,
        [bool]$Primary = $false,
        [double]$MinWidth = 0
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Text
    $button.MinHeight = 38
    $button.MinWidth = $MinWidth
    $button.Padding = New-Object System.Windows.Thickness(14, 7, 14, 7)
    $button.Margin = New-Object System.Windows.Thickness(0, 0, 10, 10)
    $button.Foreground = ConvertTo-RylBrush "#F5F7FB"
    $button.Background = if ($Primary) {
        ConvertTo-RylBrush "#4784ED"
    } else {
        ConvertTo-RylBrush "#293347"
    }
    $button.BorderBrush = ConvertTo-RylBrush "#3A4861"
    $button.BorderThickness = New-Object System.Windows.Thickness(1)
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    return $button
}

function New-RylWpfScrollViewer {
    param([Parameter(Mandatory = $true)][System.Windows.UIElement]$Content)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.Content = $Content
    $scroll.VerticalScrollBarVisibility = "Auto"
    $scroll.HorizontalScrollBarVisibility = "Disabled"
    return $scroll
}

function New-RylWpfSection {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$Description
    )

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = New-Object System.Windows.Thickness(0, 0, 0, 16)
    $heading = New-RylWpfText -Text $Title -FontSize 15 -Bold
    $heading.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    [void]$stack.Children.Add($heading)
    if ($Description) {
        $descriptionText = New-RylWpfText -Text $Description -FontSize 12 `
            -Color "#AAB6CA" -Wrap
        $descriptionText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 9)
        [void]$stack.Children.Add($descriptionText)
    }
    return $stack
}

function New-RylWpfCard {
    param([Parameter(Mandatory = $true)][System.Windows.UIElement]$Content)

    $border = New-Object System.Windows.Controls.Border
    $border.Background = ConvertTo-RylBrush "#1E2534"
    $border.BorderBrush = ConvertTo-RylBrush "#2C374B"
    $border.BorderThickness = New-Object System.Windows.Thickness(1)
    $border.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $border.Padding = New-Object System.Windows.Thickness(18)
    $border.Margin = New-Object System.Windows.Thickness(0, 0, 12, 12)
    $border.Child = $Content
    return $border
}

function New-RylWpfConfirm {
    param(
        [System.Windows.Window]$Owner,
        [string]$Message,
        [string]$Title
    )

    return [System.Windows.MessageBox]::Show(
        $Owner,
        $Message,
        $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    ) -eq [System.Windows.MessageBoxResult]::Yes
}

function Start-RylWpfGUI {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [hashtable]$Settings,
        [string]$LHMStatus = "Checking hardware..."
    )

    if (-not $Settings) {
        $Settings = Get-RylSettings -Root $Root
    }
    $appCatalog = @(Get-RylAppCatalog -Root $Root)

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RylUtils" Width="1400" Height="900" MinWidth="1180" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="#11151F"
        FontFamily="Segoe UI" Foreground="#F3F6FC">
  <Window.Resources>
    <Style TargetType="{x:Type Button}">
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="0,0,9,9"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#3A4861"/>
      <Setter Property="Background" Value="#293347"/>
      <Setter Property="Foreground" Value="#F5F7FB"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="MinHeight" Value="38"/>
    </Style>
    <Style TargetType="{x:Type TextBox}">
      <Setter Property="Background" Value="#171D2A"/>
      <Setter Property="Foreground" Value="#F3F6FC"/>
      <Setter Property="BorderBrush" Value="#3A4861"/>
      <Setter Property="Padding" Value="9,7"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
    <Style TargetType="{x:Type ComboBox}">
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="Foreground" Value="#11151F"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Margin" Value="0,4,0,12"/>
    </Style>
    <Style TargetType="{x:Type ComboBoxItem}">
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="Foreground" Value="#11151F"/>
      <Setter Property="Padding" Value="8,5"/>
      <Style.Triggers>
        <Trigger Property="IsHighlighted" Value="True">
          <Setter Property="Background" Value="#DCEBFA"/>
          <Setter Property="Foreground" Value="#11151F"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="{x:Type TabControl}">
      <Setter Property="Background" Value="#11151F"/>
      <Setter Property="BorderBrush" Value="#2C374B"/>
      <Setter Property="Foreground" Value="#F3F6FC"/>
    </Style>
    <Style TargetType="{x:Type TabItem}">
      <Setter Property="Padding" Value="16,9"/>
      <Setter Property="Background" Value="#1E2534"/>
      <Setter Property="Foreground" Value="#E8EDF6"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#FFFFFF"/>
          <Setter Property="Foreground" Value="#11151F"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="{x:Type CheckBox}">
      <Setter Property="Foreground" Value="#E6EBF4"/>
      <Setter Property="Margin" Value="0,5,0,5"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
  </Window.Resources>
  <Grid x:Name="ShellRoot">
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="218"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <Border x:Name="Sidebar" Grid.Row="0" Grid.Column="0" Background="#161B27">
      <DockPanel LastChildFill="True" Margin="15,20,15,16">
        <StackPanel DockPanel.Dock="Top">
          <TextBlock Text="RYL / UTILITIES" FontSize="16" FontWeight="Bold"
                     Margin="8,3,0,5"/>
          <TextBlock Text="SYSTEM WORKSPACE" FontSize="10" Foreground="#9DA9BE"
                     Margin="9,0,0,25"/>
        </StackPanel>
        <StackPanel x:Name="NavPanel" DockPanel.Dock="Top"/>
        <TextBlock DockPanel.Dock="Bottom" Text="Windows desktop tools"
                   Foreground="#71809A" FontSize="11" Margin="8,12,0,0"/>
      </DockPanel>
    </Border>
    <Grid Grid.Row="0" Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="76"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <Border Grid.Row="0" Background="#161B27" Padding="25,12">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel VerticalAlignment="Center">
            <TextBlock x:Name="PageTitle" Text="Monitor" FontSize="18"
                       FontWeight="SemiBold"/>
            <TextBlock x:Name="PageSubtitle" Text="Live system performance"
                       Foreground="#9DA9BE" FontSize="12" Margin="0,2,0,0"/>
          </StackPanel>
          <TextBlock x:Name="HeaderStatus" Grid.Column="1"
                     Text="Starting monitor..." Foreground="#AAB6CA"
                     VerticalAlignment="Center" TextAlignment="Right"
                     TextTrimming="CharacterEllipsis" MaxWidth="420"/>
        </Grid>
      </Border>
      <ContentControl x:Name="MainContent" Grid.Row="1" Margin="24,18,24,16"/>
    </Grid>
    <Border x:Name="ActionFooter" Grid.Row="1" Grid.ColumnSpan="2"
            Background="#161B27" BorderBrush="#2C374B" BorderThickness="0,1,0,0"
            Padding="18,9">
      <StackPanel>
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <ProgressBar x:Name="ActionProgress" Height="7" Minimum="0" Maximum="100"
                       Value="0" VerticalAlignment="Center" Margin="0,0,16,0"/>
          <Button x:Name="ActionStopButton" Grid.Column="1" Content="Stop"
                  IsEnabled="False" Visibility="Collapsed" MinWidth="82"
                  Background="#8F3030" BorderBrush="#C75B5B"
                  ToolTip="Stop queued installers after any currently running installer finishes."
                  Margin="0,0,8,0" MinHeight="30"/>
          <Button x:Name="DetailsToggle" Grid.Column="2" MinWidth="130"
                  Padding="10,4" Margin="0" MinHeight="30">
            <StackPanel Orientation="Horizontal">
              <TextBlock x:Name="DetailsGlyph" Text="&#xE70D;"
                         FontFamily="Segoe MDL2 Assets" Margin="0,0,7,0"/>
              <TextBlock x:Name="DetailsLabel" Text="Show details"/>
            </StackPanel>
          </Button>
        </Grid>
        <TextBlock x:Name="ActionSummary" Text="Ready" Foreground="#B8C3D7"
                   FontSize="12" Margin="1,7,0,0" TextWrapping="Wrap"/>
        <Border x:Name="DetailsHost" Visibility="Collapsed" Margin="0,8,0,0"
                Background="#11151F" BorderBrush="#2C374B" BorderThickness="1"
                CornerRadius="6" Padding="8">
          <TextBox x:Name="DetailsText" IsReadOnly="True" AcceptsReturn="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                   HorizontalScrollBarVisibility="Disabled" BorderThickness="0"
                   Background="#11151F" FontFamily="Consolas" FontSize="11"
                   MinHeight="86" MaxHeight="150"/>
        </Border>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@

    $xmlReader = New-Object System.Xml.XmlNodeReader([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($xmlReader)
    $workingArea = [System.Windows.SystemParameters]::WorkArea
    $window.Width = [math]::Min(1480, [math]::Max(1180, $workingArea.Width - 48))
    $window.Height = [math]::Min(960, [math]::Max(680, $workingArea.Height - 48))
    $ui = @{
        Sidebar = $window.FindName("Sidebar")
        NavPanel = $window.FindName("NavPanel")
        PageTitle = $window.FindName("PageTitle")
        PageSubtitle = $window.FindName("PageSubtitle")
        HeaderStatus = $window.FindName("HeaderStatus")
        MainContent = $window.FindName("MainContent")
        Progress = $window.FindName("ActionProgress")
        ActionSummary = $window.FindName("ActionSummary")
        StopAction = $window.FindName("ActionStopButton")
        DetailsToggle = $window.FindName("DetailsToggle")
        DetailsGlyph = $window.FindName("DetailsGlyph")
        DetailsLabel = $window.FindName("DetailsLabel")
        DetailsHost = $window.FindName("DetailsHost")
        DetailsText = $window.FindName("DetailsText")
    }

    $theme = @{
        Background = ConvertTo-RylBrush $Settings.Background
        Sidebar = ConvertTo-RylBrush $Settings.Sidebar
        Panel = ConvertTo-RylBrush $Settings.Panel
        Accent = ConvertTo-RylBrush $Settings.Accent
        Muted = ConvertTo-RylBrush $Settings.Muted
    }
    $window.Background = $theme.Background
    $ui.Sidebar.Background = $theme.Sidebar

    $monitorGrid = New-Object System.Windows.Controls.Grid
    $monitorGrid.Margin = New-Object System.Windows.Thickness(2, 0, 2, 0)
    $monitorGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $monitorGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))
    $monitorGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $monitorGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $monitorHeading = New-Object System.Windows.Controls.StackPanel
    [void]$monitorHeading.Children.Add((New-RylWpfText -Text "System overview" -FontSize 21 -Bold))
    [void]$monitorHeading.Children.Add((New-RylWpfText -Text "Live readings refresh automatically." -FontSize 12 -Color "#9DA9BE"))
    [System.Windows.Controls.Grid]::SetRow($monitorHeading, 0)
    [void]$monitorGrid.Children.Add($monitorHeading)
    $metricGrid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $metricGrid.Columns = 3
    $metricGrid.Rows = 2
    $metricGrid.Margin = New-Object System.Windows.Thickness(0, 18, 0, 6)
    $metricSpecs = @(
        @{ Key = "CPU"; Caption = "CPU LOAD"; Color = "#85C7FF"; Bar = $true },
        @{ Key = "RAM"; Caption = "MEMORY IN USE"; Color = "#8FE0A5"; Bar = $true },
        @{ Key = "Temp"; Caption = "CPU TEMPERATURE"; Color = "#FFB36B"; Bar = $true },
        @{ Key = "Disk"; Caption = "SYSTEM DRIVE"; Color = "#85C7FF"; Bar = $true },
        @{ Key = "Network"; Caption = "NETWORK RX / TX"; Color = "#8FE0A5"; Bar = $true },
        @{ Key = "Uptime"; Caption = "SYSTEM UPTIME"; Color = "#D2A5FF"; Bar = $false }
    )
    $cards = @{}
    foreach ($spec in $metricSpecs) {
        $cardContent = New-Object System.Windows.Controls.StackPanel
        [void]$cardContent.Children.Add((New-RylWpfText -Text $spec.Caption -FontSize 11 -Color "#9DA9BE" -Bold))
        $value = New-RylWpfText -Text "Waiting for sample..." -FontSize 23 -Color $spec.Color -Bold -Wrap
        $value.Margin = New-Object System.Windows.Thickness(0, 18, 0, 12)
        [void]$cardContent.Children.Add($value)
        $bar = $null
        if ($spec.Bar) {
            $bar = New-Object System.Windows.Controls.ProgressBar
            $bar.Minimum = 0
            $bar.Maximum = 100
            $bar.Height = 6
            $bar.Foreground = ConvertTo-RylBrush $spec.Color
            $bar.Background = ConvertTo-RylBrush "#303B4F"
            [void]$cardContent.Children.Add($bar)
        }
        $card = New-RylWpfCard -Content $cardContent
        $card.MinHeight = 150
        [void]$metricGrid.Children.Add($card)
        $cards[$spec.Key] = @{ Value = $value; Bar = $bar }
    }
    [System.Windows.Controls.Grid]::SetRow($metricGrid, 1)
    [void]$monitorGrid.Children.Add($metricGrid)
    $monitorDetails = New-Object System.Windows.Controls.TextBox
    $monitorDetails.IsReadOnly = $true
    $monitorDetails.TextWrapping = "Wrap"
    $monitorDetails.VerticalScrollBarVisibility = "Auto"
    $monitorDetails.Height = 82
    $monitorDetails.Margin = New-Object System.Windows.Thickness(0, 3, 0, 12)
    $monitorDetails.Background = ConvertTo-RylBrush "#1E2534"
    $monitorDetails.BorderBrush = ConvertTo-RylBrush "#2C374B"
    $monitorDetails.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $monitorDetails.FontSize = 11
    [System.Windows.Controls.Grid]::SetRow($monitorDetails, 2)
    [void]$monitorGrid.Children.Add($monitorDetails)
    $monitorActions = New-Object System.Windows.Controls.StackPanel
    $monitorActions.Orientation = "Horizontal"
    $refreshButton = New-RylWpfButton -Text "Refresh now" -Primary $true
    $elevationButton = New-RylWpfButton -Text "Restart as administrator"
    $elevationButton.Visibility = "Collapsed"
    [void]$monitorActions.Children.Add($refreshButton)
    [void]$monitorActions.Children.Add($elevationButton)
    [System.Windows.Controls.Grid]::SetRow($monitorActions, 3)
    [void]$monitorGrid.Children.Add($monitorActions)
    $monitor = @{
        Page = New-RylWpfScrollViewer -Content $monitorGrid
        Cards = $cards
        Details = $monitorDetails
        RefreshButton = $refreshButton
        ElevationButton = $elevationButton
        NetworkSample = $null
    }

    $utilitiesTabs = New-Object System.Windows.Controls.TabControl
    $utilitiesTabs.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
    $utilityControls = @{}
    $networkStack = New-Object System.Windows.Controls.StackPanel
    $networkStack.Margin = New-Object System.Windows.Thickness(18)
    [void]$networkStack.Children.Add((New-RylWpfText -Text "Network adapter" -FontSize 14 -Bold))
    $adapterCombo = New-Object System.Windows.Controls.ComboBox
    $adapterCombo.DisplayMemberPath = "Name"
    [void]$networkStack.Children.Add($adapterCombo)
    [void]$networkStack.Children.Add((New-RylWpfText -Text "DNS provider" -FontSize 14 -Bold))
    $dnsCombo = New-Object System.Windows.Controls.ComboBox
    $dnsCombo.DisplayMemberPath = "Name"
    [void]$networkStack.Children.Add($dnsCombo)
    $dnsDescription = New-RylWpfText -Text "Choose a provider to view its DNS servers." -Color "#AAB6CA" -Wrap
    $dnsDescription.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    [void]$networkStack.Children.Add($dnsDescription)
    $networkButtons = New-Object System.Windows.Controls.WrapPanel
    $applyDnsButton = New-RylWpfButton -Text "Apply DNS profile" -Primary $true
    $restoreDnsButton = New-RylWpfButton -Text "Restore last DNS backup"
    $flushDnsButton = New-RylWpfButton -Text "Flush DNS cache"
    [void]$networkButtons.Children.Add($applyDnsButton)
    [void]$networkButtons.Children.Add($restoreDnsButton)
    [void]$networkButtons.Children.Add($flushDnsButton)
    [void]$networkStack.Children.Add($networkButtons)
    $networkStatus = New-RylWpfText -Text "DNS changes save a backup of the selected adapter settings." -Color "#AAB6CA" -Wrap
    $networkStatus.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0)
    [void]$networkStack.Children.Add($networkStatus)
    $utilityControls.NetworkAdapter = $adapterCombo
    $utilityControls.DnsProfile = $dnsCombo
    $utilityControls.DnsDescription = $dnsDescription
    $utilityControls.ApplyDnsButton = $applyDnsButton
    $utilityControls.RestoreDnsButton = $restoreDnsButton
    $utilityControls.FlushDnsButton = $flushDnsButton
    $utilityControls.NetworkStatus = $networkStatus
    $networkTab = New-Object System.Windows.Controls.TabItem
    $networkTab.Header = "Network / DNS"
    $networkTab.Content = New-RylWpfScrollViewer -Content $networkStack
    [void]$utilitiesTabs.Items.Add($networkTab)

    $optimizationStack = New-Object System.Windows.Controls.StackPanel
    $optimizationStack.Margin = New-Object System.Windows.Thickness(18)
    [void]$optimizationStack.Children.Add((New-RylWpfText -Text "Optimization presets" -FontSize 15 -Bold))
    $presetRow = New-Object System.Windows.Controls.WrapPanel
    $presetButtons = @{}
    foreach ($presetName in @("Minimal", "Standard", "Full")) {
        $presetButton = New-RylWpfButton -Text $presetName
        $presetButtons[$presetName] = $presetButton
        [void]$presetRow.Children.Add($presetButton)
    }
    [void]$optimizationStack.Children.Add($presetRow)
    [void]$optimizationStack.Children.Add((New-RylWpfText -Text "Tasks (unchecked tasks remain unchanged)" -FontSize 14 -Bold))
    $taskChecks = @()
    foreach ($taskName in @("Flush DNS cache", "Clean old files from Temp", "Remove checked optional apps")) {
        $check = New-Object System.Windows.Controls.CheckBox
        $check.Content = $taskName
        $taskChecks += $check
        [void]$optimizationStack.Children.Add($check)
    }
    [void]$optimizationStack.Children.Add((New-RylWpfText -Text "Optional apps (allow-listed; none selected by default)" -FontSize 14 -Bold))
    $optionalList = New-Object System.Windows.Controls.StackPanel
    $optionalList.Margin = New-Object System.Windows.Thickness(0, 4, 0, 8)
    [void]$optimizationStack.Children.Add($optionalList)
    $restorePointCheck = New-Object System.Windows.Controls.CheckBox
    $restorePointCheck.Content = "Create Windows restore point first"
    $restorePointCheck.IsChecked = $true
    [void]$optimizationStack.Children.Add($restorePointCheck)
    $optimizationButtons = New-Object System.Windows.Controls.WrapPanel
    $applyOptimizationButton = New-RylWpfButton -Text "Apply selected tasks" -Primary $true
    $openRestoreButton = New-RylWpfButton -Text "Open System Restore"
    [void]$optimizationButtons.Children.Add($applyOptimizationButton)
    [void]$optimizationButtons.Children.Add($openRestoreButton)
    [void]$optimizationStack.Children.Add($optimizationButtons)
    $safetyWarning = New-RylWpfText -Text "Warning: temp cleanup and app removal may not be reversible. A restore point is recommended; removed apps may need reinstalling from Microsoft Store." -Color "#FFB36B" -Wrap
    [void]$optimizationStack.Children.Add($safetyWarning)
    $utilityControls.TaskChecks = $taskChecks
    $utilityControls.OptionalList = $optionalList
    $utilityControls.RestorePoint = $restorePointCheck
    $utilityControls.PresetButtons = $presetButtons
    $utilityControls.ApplyOptimizationButton = $applyOptimizationButton
    $utilityControls.OpenRestoreButton = $openRestoreButton
    $utilityControls.SafetyWarning = $safetyWarning
    $optimizationTab = New-Object System.Windows.Controls.TabItem
    $optimizationTab.Header = "PC optimization"
    $optimizationTab.Content = New-RylWpfScrollViewer -Content $optimizationStack
    [void]$utilitiesTabs.Items.Add($optimizationTab)

    $updatesStack = New-Object System.Windows.Controls.StackPanel
    $updatesStack.Margin = New-Object System.Windows.Thickness(20)
    $updateStatus = New-RylWpfText -Text "Checking Windows Update policy..." -FontSize 16 -Color "#AAB6CA" -Bold
    $updateStatus.Margin = New-Object System.Windows.Thickness(0, 3, 0, 10)
    [void]$updatesStack.Children.Add($updateStatus)
    [void]$updatesStack.Children.Add((New-RylWpfText -Text "These controls remove or set the local machine-wide NoAutoUpdate policy and request administrator approval. Domain or organization policy can override local settings." -Color "#AAB6CA" -Wrap))
    $updateButtons = New-Object System.Windows.Controls.WrapPanel
    $disableUpdatesButton = New-RylWpfButton -Text "Disable automatic updates"
    $enableUpdatesButton = New-RylWpfButton -Text "Enable automatic updates" -Primary $true
    [void]$updateButtons.Children.Add($disableUpdatesButton)
    [void]$updateButtons.Children.Add($enableUpdatesButton)
    [void]$updatesStack.Children.Add($updateButtons)
    [void]$updatesStack.Children.Add((New-RylWpfText -Text "Disabling updates can leave this PC without security fixes. Enabling removes this app's local disable setting; it cannot override organization-managed policy." -Color "#FFB36B" -Wrap))
    $utilityControls.DisableUpdatesButton = $disableUpdatesButton
    $utilityControls.EnableUpdatesButton = $enableUpdatesButton
    $utilityControls.UpdateStatus = $updateStatus
    $updatesTab = New-Object System.Windows.Controls.TabItem
    $updatesTab.Header = "Windows updates"
    $updatesTab.Content = New-RylWpfScrollViewer -Content $updatesStack
    [void]$utilitiesTabs.Items.Add($updatesTab)

    $quickStack = New-Object System.Windows.Controls.StackPanel
    $quickStack.Margin = New-Object System.Windows.Thickness(18)
    [void]$quickStack.Children.Add((New-RylWpfText -Text "Quick tools" -FontSize 16 -Bold))
    [void]$quickStack.Children.Add((New-RylWpfText -Text "Shortcuts open Windows settings, tools, or web pages; remote code is not executed." -Color "#AAB6CA" -Wrap))
    $quickPanel = New-Object System.Windows.Controls.WrapPanel
    $quickPanel.Margin = New-Object System.Windows.Thickness(0, 12, 0, 0)
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
    foreach ($spec in $quickToolSpecs) {
        $quickButton = New-RylWpfButton -Text $spec.Name
        $quickButton.MinWidth = 190
        $quickButton.Tag = $spec.Target
        $quickTools[$spec.Name] = $quickButton
        [void]$quickPanel.Children.Add($quickButton)
    }
    [void]$quickStack.Children.Add($quickPanel)
    $quickTab = New-Object System.Windows.Controls.TabItem
    $quickTab.Header = "Quick tools"
    $quickTab.Content = New-RylWpfScrollViewer -Content $quickStack
    [void]$utilitiesTabs.Items.Add($quickTab)
    $utilitiesTabs.Add_SelectionChanged({
        foreach ($tab in $utilitiesTabs.Items) {
            if ($tab.IsSelected) {
                $tab.Background = ConvertTo-RylBrush "#FFFFFF"
                $tab.Foreground = ConvertTo-RylBrush "#11151F"
            } else {
                $tab.Background = ConvertTo-RylBrush "#1E2534"
                $tab.Foreground = ConvertTo-RylBrush "#E8EDF6"
            }
        }
    })
    foreach ($tab in $utilitiesTabs.Items) {
        if ($tab.IsSelected) {
            $tab.Background = ConvertTo-RylBrush "#FFFFFF"
            $tab.Foreground = ConvertTo-RylBrush "#11151F"
        } else {
            $tab.Background = ConvertTo-RylBrush "#1E2534"
            $tab.Foreground = ConvertTo-RylBrush "#E8EDF6"
        }
    }
    $utilities = @{
        Page = $utilitiesTabs
        Controls = $utilityControls
        QuickTools = $quickTools
        OptionalApps = @()
        OptionalCatalog = @()
    }

    $downloaderGrid = New-Object System.Windows.Controls.Grid
    $downloaderGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $downloaderGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $downloaderGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))
    $downloaderGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
    $downloaderHeader = New-Object System.Windows.Controls.Grid
    $downloaderHeader.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
    $downloaderHeader.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))
    $searchStack = New-Object System.Windows.Controls.StackPanel
    [void]$searchStack.Children.Add((New-RylWpfText -Text "App downloader" -FontSize 21 -Bold))
    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Width = 380
    $searchBox.HorizontalAlignment = "Left"
    $searchBox.Background = ConvertTo-RylBrush "#FFFFFF"
    $searchBox.Foreground = ConvertTo-RylBrush "#11151F"
    $searchBox.Margin = New-Object System.Windows.Thickness(0, 10, 0, 5)
    $searchBox.ToolTip = "Search by app name, category, description, or package ID"
    [System.Windows.Automation.AutomationProperties]::SetName(
        $searchBox,
        "Search apps by name, category, description, or package ID"
    )
    [void]$searchStack.Children.Add($searchBox)
    $wingetStatus = New-RylWpfText -Text "Checking WinGet..." -FontSize 12 -Color "#AAB6CA" -Wrap
    [void]$searchStack.Children.Add($wingetStatus)
    [System.Windows.Controls.Grid]::SetColumn($searchStack, 0)
    [void]$downloaderHeader.Children.Add($searchStack)
    $wingetButtons = New-Object System.Windows.Controls.StackPanel
    $wingetButtons.Orientation = "Horizontal"
    $retryButton = New-RylWpfButton -Text "Retry WinGet setup"
    $storeButton = New-RylWpfButton -Text "Get App Installer"
    $storeButton.Visibility = "Collapsed"
    [void]$wingetButtons.Children.Add($retryButton)
    [void]$wingetButtons.Children.Add($storeButton)
    [System.Windows.Controls.Grid]::SetColumn($wingetButtons, 1)
    [void]$downloaderHeader.Children.Add($wingetButtons)
    [System.Windows.Controls.Grid]::SetRow($downloaderHeader, 0)
    [void]$downloaderGrid.Children.Add($downloaderHeader)
    $categoryScroll = New-Object System.Windows.Controls.ScrollViewer
    $categoryScroll.HorizontalScrollBarVisibility = "Auto"
    $categoryScroll.VerticalScrollBarVisibility = "Disabled"
    $categoryPanel = New-Object System.Windows.Controls.StackPanel
    $categoryPanel.Orientation = "Horizontal"
    $categoryPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 10)
    $categoryScroll.Content = $categoryPanel
    [System.Windows.Controls.Grid]::SetRow($categoryScroll, 1)
    [void]$downloaderGrid.Children.Add($categoryScroll)
    $appScroll = New-Object System.Windows.Controls.ScrollViewer
    $appScroll.VerticalScrollBarVisibility = "Auto"
    $appScroll.HorizontalScrollBarVisibility = "Disabled"
    $appPanel = New-Object System.Windows.Controls.WrapPanel
    $appScroll.Content = $appPanel
    [System.Windows.Controls.Grid]::SetRow($appScroll, 2)
    [void]$downloaderGrid.Children.Add($appScroll)
    $offlineFooter = New-Object System.Windows.Controls.DockPanel
    $offlineFooter.Margin = New-Object System.Windows.Thickness(0, 9, 0, 0)
    $openFolderButton = New-RylWpfButton -Text "Open folder"
    $openFolderButton.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
    [System.Windows.Controls.DockPanel]::SetDock($openFolderButton, "Right")
    [void]$offlineFooter.Children.Add($openFolderButton)
    $offlineLabel = New-RylWpfText -Text "Offline installers: $($Settings.OfflineDirectory)" -FontSize 11 -Color "#9DA9BE" -Wrap
    $offlineLabel.VerticalAlignment = "Center"
    [void]$offlineFooter.Children.Add($offlineLabel)
    [System.Windows.Controls.Grid]::SetRow($offlineFooter, 3)
    [void]$downloaderGrid.Children.Add($offlineFooter)
    $downloader = @{
        Page = $downloaderGrid
        SearchBox = $searchBox
        WingetStatus = $wingetStatus
        RetryButton = $retryButton
        StoreButton = $storeButton
        CategoryPanel = $categoryPanel
        CategoryButtons = @()
        AppPanel = $appPanel
        OpenFolderButton = $openFolderButton
        OfflineDirectory = $Settings.OfflineDirectory
    }

    $quickSetup = New-RylWpfQuickSetupPage -Apps $appCatalog `
        -OfflineDirectory $Settings.OfflineDirectory

    $pages = @{
        Monitor = $monitor.Page
        Utilities = $utilities.Page
        Downloader = $downloader.Page
        QuickSetup = $quickSetup.Page
    }
    $state = @{
        Root = $Root
        Settings = $Settings
        Theme = $theme
        Pages = $pages
        PageTitle = $ui.PageTitle
        PageSubtitle = $ui.PageSubtitle
        HeaderStatus = $ui.HeaderStatus
        UI = $ui
        Window = $window
        Monitor = $monitor
        Utilities = $utilities
        Downloader = $downloader
        QuickSetup = $quickSetup
        Apps = $appCatalog
        SelectedCategory = "All"
        WingetAvailable = $false
        InstalledPackageIds = @{}
        InstalledAppsKnown = $false
        InstalledAppsError = $false
        MonitorRunspace = [runspacefactory]::CreateRunspace()
        MonitorPowerShell = $null
        MonitorAsync = $null
        MonitorNetworkSample = $null
        ActionRunspace = $null
        ActionPowerShell = $null
        ActionAsync = $null
        ActionName = ""
        ActionProgressPath = ""
        ActionProgressPathOwned = $false
        ActionCancelPath = ""
        ActivePlanKind = ""
        ProgressHistory = New-Object 'System.Collections.Generic.List[string]'
        OptionalAppCatalog = @()
        LastProgressRecord = ""
        NavButtons = @()
        LastBackupPath = ""
    }
    $window.Tag = $state
    $state.MonitorRunspace.Open()

    function Add-RylProgressDetail {
        param([string]$Text)

        if ([string]::IsNullOrWhiteSpace($Text)) {
            return
        }
        $line = "{0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $Text
        if ($state.ProgressHistory.Count -eq 0 -or
            $state.ProgressHistory[$state.ProgressHistory.Count - 1] -notlike "*  $Text") {
            $state.ProgressHistory.Add($line)
            while ($state.ProgressHistory.Count -gt 100) {
                $state.ProgressHistory.RemoveAt(0)
            }
            $ui.DetailsText.Text = $state.ProgressHistory -join [Environment]::NewLine
            $ui.DetailsText.CaretIndex = $ui.DetailsText.Text.Length
            $ui.DetailsText.ScrollToEnd()
        }
    }

    function Set-RylDetailsExpanded {
        param([bool]$Expanded)

        if ($Expanded) {
            $ui.DetailsHost.Visibility = "Visible"
            $ui.DetailsGlyph.Text = [char]0xE70E
            $ui.DetailsLabel.Text = "Hide details"
        } else {
            $ui.DetailsHost.Visibility = "Collapsed"
            $ui.DetailsGlyph.Text = [char]0xE70D
            $ui.DetailsLabel.Text = "Show details"
        }
    }

    function Set-RylPage {
        param([string]$Name)

        $state.Pages[$Name] | ForEach-Object { $ui.MainContent.Content = $_ }
        $ui.PageTitle.Text = switch ($Name) {
            "Monitor" { "Monitor" }
            "Utilities" { "System utilities" }
            "Downloader" { "App downloader" }
            "QuickSetup" { "Quick setup" }
        }
        $ui.PageSubtitle.Text = switch ($Name) {
            "Monitor" { "Live system performance" }
            "Utilities" { "Maintenance tools and update settings" }
            "Downloader" { "Browse, install, or save offline installers" }
            "QuickSetup" { "Prepare and run selected offline installers" }
        }
        foreach ($navButton in $state.NavButtons) {
            $navButton.Background = if ($navButton.Tag -eq $Name) {
                $theme.Accent
            } else {
                $theme.Sidebar
            }
        }
    }

    function Get-LatestDnsBackup {
        $directory = Join-Path $state.Root "Backups\Network"
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

    function Refresh-QuickSetupStatuses {
        $readyCount = 0
        foreach ($card in $quickSetup.Cards) {
            $packageId = [string]$card.App.PackageId
            try {
                $installer = Get-RylQuickSetupInstallerPath `
                    -OfflineDirectory $state.Settings.OfflineDirectory `
                    -PackageId $packageId
                if ($packageId -eq "Microsoft.Office") {
                    $sourceDirectory = Join-Path (Join-Path $state.Settings.OfflineDirectory $packageId) `
                        "OfficeSource\Office\Data"
                    $installConfig = Join-Path (Join-Path $state.Settings.OfflineDirectory $packageId) `
                        "office-install.xml"
                    if ([IO.Path]::GetFileName($installer) -ieq "setup.exe" -and
                        (Test-Path -LiteralPath $sourceDirectory -PathType Container) -and
                        (Test-Path -LiteralPath $installConfig -PathType Leaf)) {
                        $card.Status.Text = "Full offline source ready"
                        $card.Status.Foreground = ConvertTo-RylBrush "#8FE0A5"
                        $readyCount++
                    } elseif ([IO.Path]::GetFileName($installer) -ieq "OfficeSetup.exe") {
                        $card.Status.Text = "Ready: OfficeSetup.exe (online installer; Internet required)"
                        $card.Status.Foreground = ConvertTo-RylBrush "#FFB36B"
                        $readyCount++
                    } else {
                        $card.Status.Text = "Setup tool found; offline source not yet downloaded"
                        $card.Status.Foreground = ConvertTo-RylBrush "#FFB36B"
                    }
                } elseif ($packageId -eq "Adobe.Acrobat.Reader.64-bit" -and
                    [IO.Path]::GetFileName($installer) -ieq "Reader_en_install.exe") {
                    $card.Status.Text = "Ready: Reader_en_install.exe (downloader; Internet required)"
                    $card.Status.Foreground = ConvertTo-RylBrush "#FFB36B"
                    $readyCount++
                } elseif (-not $card.App.OfflineDownload) {
                    $card.Status.Text = "Ready: $(Split-Path -Leaf $installer) (online installer; Internet required)"
                    $card.Status.Foreground = ConvertTo-RylBrush "#FFB36B"
                    $readyCount++
                } else {
                    $card.Status.Text = "Ready: $(Split-Path -Leaf $installer)"
                    $card.Status.Foreground = ConvertTo-RylBrush "#8FE0A5"
                    $readyCount++
                }
            } catch {
                $card.Status.Text = "Not downloaded"
                $card.Status.Foreground = ConvertTo-RylBrush "#9DA9BE"
            }
        }
        $quickSetup.Status.Text = "$readyCount of $($quickSetup.Cards.Count) offline installers are ready."
    }

    function Update-AutoUpdateStatus {
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        $value = Get-ItemProperty -Path $path -Name NoAutoUpdate -ErrorAction SilentlyContinue
        if ($null -ne $value -and $value.NoAutoUpdate -eq 1) {
            $utilityControls.UpdateStatus.Text = "Automatic updates are disabled by the local NoAutoUpdate policy."
            $utilityControls.UpdateStatus.Foreground = ConvertTo-RylBrush "#FFB36B"
            $utilityControls.DisableUpdatesButton.IsEnabled = $false
            $utilityControls.EnableUpdatesButton.IsEnabled = $true
        } elseif ($null -ne $value -and $value.NoAutoUpdate -eq 0) {
            $utilityControls.UpdateStatus.Text = "The NoAutoUpdate policy explicitly allows automatic updates."
            $utilityControls.UpdateStatus.Foreground = ConvertTo-RylBrush "#8FE0A5"
            $utilityControls.DisableUpdatesButton.IsEnabled = $true
            $utilityControls.EnableUpdatesButton.IsEnabled = $false
        } else {
            $utilityControls.UpdateStatus.Text = "No local NoAutoUpdate policy is set; Windows Update uses its normal configuration."
            $utilityControls.UpdateStatus.Foreground = ConvertTo-RylBrush "#8FE0A5"
            $utilityControls.DisableUpdatesButton.IsEnabled = $true
            $utilityControls.EnableUpdatesButton.IsEnabled = $true
        }
    }

    function Start-BackgroundAction {
        param(
            [string]$Name,
            [string]$Action,
            [string]$PackageId,
            [string[]]$PackageIds = @(),
            [bool]$DisableAutomaticUpdates = $false,
            [string]$ProgressPath,
            [string]$PlanPath,
            [string]$InstallMode = "Sequence"
        )

        if ($state.ActionPowerShell) {
            $ui.HeaderStatus.Text = "Wait for the current background action to finish."
            $ui.ActionSummary.Text = "Another background action is still running."
            return
        }
        $ownsProgressPath = [string]::IsNullOrWhiteSpace($ProgressPath)
        if ($ownsProgressPath) {
            $ProgressPath = Join-Path $env:TEMP ("RylUtils-progress-{0}-{1}.json" -f $PID, [guid]::NewGuid().ToString("N"))
        }
        $cancelPath = if ($Action -eq "InstallQuickSetupApps") {
            Join-Path $env:TEMP ("RylUtils-cancel-{0}-{1}.flag" -f $PID, [guid]::NewGuid().ToString("N"))
        } else {
            ""
        }
        $state.ProgressHistory.Clear()
        $ui.DetailsText.Clear()
        Add-RylProgressDetail -Text "$Name starting"
        if ($Action -ne "CheckWinget") {
            Set-RylDetailsExpanded -Expanded $true
        }
        Write-RylActionProgress -ProgressPath $ProgressPath -Percent 1 -Detail "$Name starting"

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $script = {
            param($ModulePath, $ActionName, $AppRoot, $Id, $AppPackageIds, $OfflineDirectory, $DisableUpdates, $ActionProgress, $PlanFile, $InstallationMode, $CancellationSignal)
            . $ModulePath
            Invoke-RylBackgroundAction -Action $ActionName -Root $AppRoot `
                -PackageId $Id -PackageIds $AppPackageIds `
                -OfflineDirectory $OfflineDirectory `
                -DisableAutomaticUpdates $DisableUpdates -ProgressPath $ActionProgress `
                -PlanPath $PlanFile -InstallMode $InstallationMode `
                -CancelPath $CancellationSignal
        }
        [void]$powerShell.AddScript($script.ToString())
        [void]$powerShell.AddArgument((Join-Path $state.Root "Modules\BackgroundActions.ps1"))
        [void]$powerShell.AddArgument($Action)
        [void]$powerShell.AddArgument($state.Root)
        [void]$powerShell.AddArgument($PackageId)
        [void]$powerShell.AddArgument($PackageIds)
        [void]$powerShell.AddArgument($state.Settings.OfflineDirectory)
        [void]$powerShell.AddArgument($DisableAutomaticUpdates)
        [void]$powerShell.AddArgument($ProgressPath)
        [void]$powerShell.AddArgument($PlanPath)
        [void]$powerShell.AddArgument($InstallMode)
        [void]$powerShell.AddArgument($cancelPath)
        $state.ActionRunspace = $runspace
        $state.ActionPowerShell = $powerShell
        $state.ActionAsync = $powerShell.BeginInvoke()
        $state.ActionName = $Action
        $state.ActionProgressPath = $ProgressPath
        $state.ActionProgressPathOwned = $ownsProgressPath
        $state.ActionCancelPath = $cancelPath
        $ui.StopAction.Visibility = if ($Action -eq "InstallQuickSetupApps") { "Visible" } else { "Collapsed" }
        $ui.StopAction.IsEnabled = ($Action -eq "InstallQuickSetupApps")
        $ui.Progress.Value = 1
        $ui.ActionSummary.Text = "$Name is running..."
        $ui.HeaderStatus.Text = "$Name in progress"
        if ($Action -in @("DownloadQuickSetupApps", "InstallQuickSetupApps")) {
            $quickSetup.Status.Text = "$Name is running..."
        }
        $downloader.WingetStatus.Text = if ($Action -eq "CheckWinget") {
            "Checking WinGet availability..."
        } else {
            $downloader.WingetStatus.Text
        }
    }

    function Start-MonitorRefresh {
        if ($state.MonitorAsync -and -not $state.MonitorAsync.IsCompleted) {
            return
        }
        if ($state.MonitorPowerShell) {
            $state.MonitorPowerShell.Dispose()
        }
        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $state.MonitorRunspace
        $script = {
            param($ModulePath, $AppRoot, $PreviousNetworkSample)
            . $ModulePath
            Get-RylMonitorSnapshot -Root $AppRoot -PreviousNetworkSample $PreviousNetworkSample
        }
        [void]$powerShell.AddScript($script.ToString())
        [void]$powerShell.AddArgument((Join-Path $state.Root "Modules\SystemMonitor.ps1"))
        [void]$powerShell.AddArgument($state.Root)
        [void]$powerShell.AddArgument($state.MonitorNetworkSample)
        $state.MonitorPowerShell = $powerShell
        $state.MonitorAsync = $powerShell.BeginInvoke()
        if (-not $state.ActionPowerShell) {
            $ui.HeaderStatus.Text = "Updating hardware readings..."
        }
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

        if ($state.ActionPowerShell) {
            $ui.HeaderStatus.Text = "Wait for the current background action to finish."
            return $false
        }
        $group = if ($Kind -eq "ApplyDns" -or $Kind -eq "RestoreDns") {
            "Network"
        } else {
            "Optimization"
        }
        $backupRoot = Join-Path $state.Root "Backups\$group"
        $backupDirectory = Join-Path $backupRoot (Get-Date -Format "yyyyMMdd-HHmmssfff")
        New-Item -ItemType Directory -Path $backupDirectory -Force -ErrorAction Stop | Out-Null
        $planPath = Join-Path $backupDirectory "Plan.json"
        $progressPath = Join-Path $backupDirectory "Progress.json"
        $plan = [PSCustomObject]@{
            Root = $state.Root
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
        $state.ActivePlanKind = $Kind
        Start-BackgroundAction -Name "Applying $group changes" -Action "ApplySystemPlan" `
            -PlanPath $planPath -ProgressPath $progressPath
        $state.LastBackupPath = $backupDirectory
        return $true
    }

    function Initialize-UtilityOptions {
        try {
            $adapters = @(Get-RylNetworkAdapters)
            foreach ($adapterEntry in $adapters) {
                [void]$adapterCombo.Items.Add($adapterEntry)
            }
            if ($adapterCombo.Items.Count -gt 0) {
                $adapterCombo.SelectedIndex = 0
            } else {
                $networkStatus.Text = "No active network adapters were found."
                $applyDnsButton.IsEnabled = $false
            }
        } catch {
            $networkStatus.Text = "Could not enumerate adapters: $($_.Exception.Message)"
            $applyDnsButton.IsEnabled = $false
        }
        try {
            foreach ($profile in @(Get-RylDnsProfiles -Root $state.Root)) {
                [void]$dnsCombo.Items.Add($profile)
            }
            if ($dnsCombo.Items.Count -gt 0) {
                $dnsCombo.SelectedIndex = 0
            }
        } catch {
            $networkStatus.Text = "Could not load DNS profiles: $($_.Exception.Message)"
            $applyDnsButton.IsEnabled = $false
        }
        try {
            $state.OptionalAppCatalog = @(Get-RylOptionalApps -Root $state.Root)
            foreach ($app in $state.OptionalAppCatalog) {
                $appCheck = New-Object System.Windows.Controls.CheckBox
                $appCheck.Content = $app.DisplayName
                $appCheck.Tag = $app.PackageName
                $utilities.OptionalApps += $appCheck
                [void]$optionalList.Children.Add($appCheck)
            }
            if ($state.OptionalAppCatalog.Count -eq 0) {
                $empty = New-RylWpfText -Text "No allow-listed optional apps are installed." -Color "#9DA9BE"
                [void]$optionalList.Children.Add($empty)
                $taskChecks[2].IsEnabled = $false
            }
        } catch {
            $safetyWarning.Text = "Could not load optional-app inventory: $($_.Exception.Message)"
        }
        try {
            $restoreDnsButton.IsEnabled = [bool](Get-LatestDnsBackup)
        } catch {
            $networkStatus.Text = "Could not read DNS backups: $($_.Exception.Message)"
            $restoreDnsButton.IsEnabled = $false
        }
    }

    function New-RylWpfAppTile {
        param([PSCustomObject]$App)

        $tileGrid = New-Object System.Windows.Controls.Grid
        $tileGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
        $tileGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "*" }))
        $tileGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "Auto" }))
        $top = New-Object System.Windows.Controls.DockPanel
        $top.LastChildFill = $true
        $iconBorder = New-Object System.Windows.Controls.Border
        $iconBorder.Width = 44
        $iconBorder.Height = 44
        $iconBorder.CornerRadius = New-Object System.Windows.CornerRadius(8)
        $iconBorder.Background = ConvertTo-RylBrush ([string]$App.Color)
        $iconBorder.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
        [System.Windows.Controls.DockPanel]::SetDock($iconBorder, "Left")
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
        [void]$top.Children.Add($iconBorder)
        $nameStack = New-Object System.Windows.Controls.StackPanel
        $nameStack.VerticalAlignment = "Center"
        [void]$nameStack.Children.Add((New-RylWpfText -Text ([string]$App.Name) -FontSize 13 -Bold -Wrap))
        [void]$nameStack.Children.Add((New-RylWpfText -Text ([string]$App.Category) -FontSize 10 -Color "#9DA9BE"))
        [void]$top.Children.Add($nameStack)
        [System.Windows.Controls.Grid]::SetRow($top, 0)
        [void]$tileGrid.Children.Add($top)
        $description = New-RylWpfText -Text ([string]$App.Description) -FontSize 11 -Color "#AAB6CA" -Wrap
        $description.Margin = New-Object System.Windows.Thickness(0, 10, 0, 8)
        [System.Windows.Controls.Grid]::SetRow($description, 1)
        [void]$tileGrid.Children.Add($description)
        $buttonRow = New-Object System.Windows.Controls.WrapPanel
        $packageId = [string]$App.PackageId
        $installAction = "InstallApp"
        $installText = "Install"
        $installEnabled = $state.WingetAvailable -and $state.InstalledAppsKnown
        if ($state.InstalledAppsError) {
            $installText = "Status unavailable"
            $installEnabled = $false
        } elseif ($state.WingetAvailable -and -not $state.InstalledAppsKnown) {
            $installText = "Checking..."
            $installEnabled = $false
        } elseif ($state.InstalledPackageIds.ContainsKey($packageId)) {
            $installText = "Uninstall"
            $installAction = "UninstallApp"
        }
        $installButton = New-RylWpfButton -Text $installText
        $installButton.Margin = New-Object System.Windows.Thickness(0, 0, 7, 0)
        $installButton.MinHeight = 32
        $installButton.Padding = New-Object System.Windows.Thickness(9, 4, 9, 4)
        $installButton.IsEnabled = $installEnabled
        $installButton.Tag = @{ Action = $installAction; App = $App }
        [void]$buttonRow.Children.Add($installButton)
        $downloadButton = New-RylWpfButton -Text "Download installer"
        $downloadButton.Margin = New-Object System.Windows.Thickness(0)
        $downloadButton.MinHeight = 32
        $downloadButton.Padding = New-Object System.Windows.Thickness(9, 4, 9, 4)
        $downloadButton.IsEnabled = $state.WingetAvailable
        $downloadButton.Tag = @{ Action = "DownloadOfflineApp"; App = $App }
        [void]$buttonRow.Children.Add($downloadButton)
        [System.Windows.Controls.Grid]::SetRow($buttonRow, 2)
        [void]$tileGrid.Children.Add($buttonRow)
        $border = New-RylWpfCard -Content $tileGrid
        $border.Width = 260
        $border.MinHeight = 154
        $border.Padding = New-Object System.Windows.Thickness(13)
        foreach ($button in @($buttonRow.Children)) {
            $button.Add_Click({
                param($sender, $eventArgs)
                $action = $sender.Tag
                $appEntry = $action.App
                if ($action.Action -eq "UninstallApp" -and
                    -not (New-RylWpfConfirm -Owner $window `
                        -Message "Uninstall $($appEntry.Name)?" `
                        -Title "Confirm app uninstall")) {
                    return
                }
                $actionName = switch ($action.Action) {
                    "DownloadOfflineApp" { "Downloading $($appEntry.Name) installer" }
                    "UninstallApp" { "Uninstalling $($appEntry.Name)" }
                    default { "Installing $($appEntry.Name)" }
                }
                Start-BackgroundAction -Name $actionName -Action $action.Action `
                    -PackageId $appEntry.PackageId
            })
        }
        return $border
    }

    function Set-AppCatalog {
        param([string]$Category = "All")

        $appPanel.Children.Clear()
        $apps = @($state.Apps)
        if ($Category -ne "All") {
            $apps = @($apps | Where-Object { $_.Category -eq $Category })
        }
        $query = [string]$searchBox.Text
        if (-not [string]::IsNullOrWhiteSpace($query)) {
            $apps = @($apps | Where-Object {
                $searchText = "{0} {1} {2} {3}" -f $_.Name, $_.PackageId, $_.Category, $_.Description
                $searchText.IndexOf($query.Trim(), [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        }
        foreach ($app in $apps) {
            [void]$appPanel.Children.Add((New-RylWpfAppTile -App $app))
        }
        if ($apps.Count -eq 0) {
            [void]$appPanel.Children.Add((New-RylWpfText -Text "No apps match this search." -Color "#9DA9BE"))
        }
        $state.SelectedCategory = $Category
        foreach ($button in $downloader.CategoryButtons) {
            $button.Background = if ($button.Tag -eq $Category) {
                $theme.Accent
            } else {
                ConvertTo-RylBrush "#293347"
            }
        }
    }

    function Initialize-AppCategories {
        $categories = @("All") + @($state.Apps | ForEach-Object { $_.Category } | Sort-Object -Unique)
        foreach ($category in $categories) {
            $categoryButton = New-RylWpfButton -Text $category -Primary ($category -eq "All")
            $categoryButton.MinHeight = 32
            $categoryButton.Margin = New-Object System.Windows.Thickness(0, 0, 7, 0)
            $categoryButton.Tag = $category
            $categoryButton.Add_Click({
                param($sender, $eventArgs)
                Set-AppCatalog -Category ([string]$sender.Tag)
            })
            $downloader.CategoryButtons += $categoryButton
            [void]$categoryPanel.Children.Add($categoryButton)
        }
    }

    $navSpecs = @(
        @{ Name = "Monitor"; Glyph = "E770" },
        @{ Name = "Utilities"; Glyph = "E713" },
        @{ Name = "Downloader"; Glyph = "E896" },
        @{ Name = "QuickSetup"; Label = "Quick setup"; Glyph = "E8A7" }
    )
    foreach ($navSpec in $navSpecs) {
        $glyphText = [char]::ConvertFromUtf32([Convert]::ToInt32($navSpec.Glyph, 16))
        $navContent = New-Object System.Windows.Controls.StackPanel
        $navContent.Orientation = "Horizontal"
        $navGlyph = New-RylWpfText -Text $glyphText -FontSize 17
        $navGlyph.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $navGlyph.Margin = New-Object System.Windows.Thickness(0, 0, 13, 0)
        [void]$navContent.Children.Add($navGlyph)
        $navLabelText = if ($navSpec.Label) { $navSpec.Label } else { $navSpec.Name }
        $navLabel = New-RylWpfText -Text $navLabelText -FontSize 13
        [void]$navContent.Children.Add($navLabel)
        $navButton = New-Object System.Windows.Controls.Button
        $navButton.Content = $navContent
        $navButton.Tag = $navSpec.Name
        $navButton.HorizontalContentAlignment = "Left"
        $navButton.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
        $navButton.Background = if ($navSpec.Name -eq "Monitor") { $theme.Accent } else { $theme.Sidebar }
        $navButton.BorderThickness = New-Object System.Windows.Thickness(0)
        $navButton.MinHeight = 44
        $navButton.Add_Click({
            param($sender, $eventArgs)
            Set-RylPage -Name ([string]$sender.Tag)
        })
        $state.NavButtons += $navButton
        [void]$ui.NavPanel.Children.Add($navButton)
    }

    $ui.DetailsToggle.Add_Click({
        $expanded = $ui.DetailsHost.Visibility -ne [System.Windows.Visibility]::Visible
        Set-RylDetailsExpanded -Expanded $expanded
    })
    Set-RylDetailsExpanded -Expanded $false
    Set-RylPage -Name "Monitor"

    function Get-SelectedQuickSetupPackageIds {
        return @($quickSetup.Cards | Where-Object {
            $_.CheckBox.IsChecked
        } | ForEach-Object {
            [string]$_.App.PackageId
        })
    }

    $quickSetup.SelectAllButton.Add_Click({
        foreach ($card in $quickSetup.Cards) {
            $card.CheckBox.IsChecked = $true
        }
        $quickSetup.Status.Text = "All quick-setup apps selected. Download before installing."
    })
    $quickSetup.SelectNoneButton.Add_Click({
        foreach ($card in $quickSetup.Cards) {
            $card.CheckBox.IsChecked = $false
        }
        $quickSetup.Status.Text = "Selection cleared."
    })
    $quickSetup.RefreshButton.Add_Click({ Refresh-QuickSetupStatuses })
    $quickSetup.OpenFolderButton.Add_Click({
        try {
            New-Item -ItemType Directory -Path $state.Settings.OfflineDirectory `
                -Force -ErrorAction Stop | Out-Null
            Start-Process -FilePath "explorer.exe" `
                -ArgumentList "`"$($state.Settings.OfflineDirectory)`"" -ErrorAction Stop
        } catch {
            $quickSetup.Status.Text = "Could not open offline folder: $($_.Exception.Message)"
        }
    })
    $quickSetup.DownloadButton.Add_Click({
        $selectedIds = @(Get-SelectedQuickSetupPackageIds)
        if ($selectedIds.Count -eq 0) {
            $quickSetup.Status.Text = "Select at least one app to download."
            return
        }
        if (-not $state.WingetAvailable) {
            $quickSetup.Status.Text = "WinGet is unavailable. Use Retry WinGet setup on the App downloader page."
            return
        }
        Start-BackgroundAction -Name "Downloading selected offline installers" `
            -Action "DownloadQuickSetupApps" -PackageIds $selectedIds
    })
    $quickSetup.InstallButton.Add_Click({
        $selectedIds = @(Get-SelectedQuickSetupPackageIds)
        if ($selectedIds.Count -eq 0) {
            $quickSetup.Status.Text = "Select at least one app to install."
            return
        }
        $notReady = @($quickSetup.Cards | Where-Object {
            $_.CheckBox.IsChecked -and
            ($_.Status.Text -notlike "Ready:*" -and
                $_.Status.Text -ne "Full offline source ready")
        } | ForEach-Object { [string]$_.App.Name })
        if ($notReady.Count -gt 0) {
            $quickSetup.Status.Text = "Download these first: $($notReady -join ', ')."
            return
        }
        $installMode = if ($quickSetup.ParallelMode.IsChecked) { "Parallel" } else { "Sequence" }
        $modeWarning = if ($installMode -eq "Parallel") {
            "Parallel mode starts every selected installer together. Windows Installer conflicts, several UAC prompts, or installer failures are possible. Stop prevents queued installers from starting, but already-running installers will finish. Continue?"
        } else {
            "Install the selected apps one at a time? Each installer opens normally and may request administrator approval. Stop lets the current installer finish and skips the rest."
        }
        if (New-RylWpfConfirm -Owner $window -Message $modeWarning `
            -Title "Confirm quick setup") {
            Start-BackgroundAction -Name "Installing selected apps ($($installMode.ToLowerInvariant()))" `
                -Action "InstallQuickSetupApps" -PackageIds $selectedIds `
                -InstallMode $installMode
        }
    })
    $ui.StopAction.Add_Click({
        if (-not $state.ActionPowerShell -or
            [string]::IsNullOrWhiteSpace($state.ActionCancelPath)) {
            return
        }
        try {
            Set-Content -LiteralPath $state.ActionCancelPath `
                -Value "Stop requested" -Encoding UTF8 -ErrorAction Stop
            $ui.StopAction.IsEnabled = $false
            $message = "Stop requested. Running installers will finish; not-yet-started installers will be skipped."
            $ui.ActionSummary.Text = $message
            $ui.HeaderStatus.Text = $message
            Add-RylProgressDetail -Text $message
        } catch {
            $message = "Could not request stop: $($_.Exception.Message)"
            $ui.ActionSummary.Text = $message
            $ui.HeaderStatus.Text = $message
            Add-RylProgressDetail -Text $message
        }
    })

    $dnsCombo.Add_SelectionChanged({
        $profile = $dnsCombo.SelectedItem
        if ($profile) {
            $servers = @($profile.IPv4) + @($profile.IPv6)
            $serverText = if ($servers.Count -gt 0) {
                "Servers: $($servers -join ', ')"
            } else {
                "Uses servers supplied by DHCP."
            }
            $dnsDescription.Text = "$($profile.Description)`r`n$serverText"
        }
    })
    $applyDnsButton.Add_Click({
        $adapter = $adapterCombo.SelectedItem
        $profile = $dnsCombo.SelectedItem
        if (-not $adapter -or -not $profile) {
            $networkStatus.Text = "Select an active adapter and a DNS profile first."
            return
        }
        if (New-RylWpfConfirm -Owner $window `
            -Message "Apply $($profile.Name) DNS servers to '$($adapter.Name)'? The current settings will be backed up first." `
            -Title "Confirm DNS change") {
            $started = Start-SystemChangePlan -Kind "ApplyDns" -Profile $profile `
                -InterfaceIndex $adapter.InterfaceIndex -AdapterName $adapter.Name
            if ($started) {
                $networkStatus.Text = "Applying DNS profile and saving a backup..."
            }
        }
    })
    $restoreDnsButton.Add_Click({
        try {
            $snapshotPath = Get-LatestDnsBackup
            if (-not $snapshotPath) {
                $networkStatus.Text = "No DNS backup was found."
                return
            }
            $snapshot = Get-Content -LiteralPath $snapshotPath -Raw -ErrorAction Stop |
                ConvertFrom-Json
            if (New-RylWpfConfirm -Owner $window `
                -Message "Restore the saved DNS settings for '$($snapshot.DNS.AdapterName)'?" `
                -Title "Confirm DNS restore") {
                $started = Start-SystemChangePlan -Kind "RestoreDns" `
                    -InterfaceIndex ([int]$snapshot.DNS.InterfaceIndex) `
                    -AdapterName ([string]$snapshot.DNS.AdapterName) -SnapshotPath $snapshotPath
                if ($started) {
                    $networkStatus.Text = "Restoring DNS settings from the saved backup..."
                }
            }
        } catch {
            $networkStatus.Text = "DNS restore could not start: $($_.Exception.Message)"
        }
    })
    $flushDnsButton.Add_Click({
        Start-BackgroundAction -Name "Flushing DNS cache" -Action "FlushDns"
    })

    foreach ($entry in $presetButtons.GetEnumerator()) {
        $entry.Value.Add_Click({
            param($sender, $eventArgs)
            foreach ($task in $taskChecks) {
                $task.IsChecked = $false
            }
            foreach ($appCheck in $utilities.OptionalApps) {
                $appCheck.IsChecked = $false
            }
            switch ([string]$sender.Content) {
                "Minimal" { $taskChecks[0].IsChecked = $true }
                "Standard" {
                    $taskChecks[0].IsChecked = $true
                    $taskChecks[1].IsChecked = $true
                }
                "Full" {
                    $taskChecks[0].IsChecked = $true
                    $taskChecks[1].IsChecked = $true
                    if ($taskChecks[2].IsEnabled) {
                        $taskChecks[2].IsChecked = $true
                        foreach ($appCheck in $utilities.OptionalApps) {
                            $appCheck.IsChecked = $true
                        }
                    }
                    $safetyWarning.Text = "Full preset selected. Review each checked optional app before applying; packages will be removed only from this user profile."
                    return
                }
            }
            $safetyWarning.Text = "Warning: temp cleanup and app removal may not be reversible. A restore point is recommended; removed apps may need reinstalling from Microsoft Store."
        })
    }
    $applyOptimizationButton.Add_Click({
        $selectedTasks = @()
        for ($index = 0; $index -lt $taskChecks.Count; $index++) {
            if ($taskChecks[$index].IsChecked) {
                $selectedTasks += $index
            }
        }
        if ($selectedTasks.Count -eq 0) {
            $ui.HeaderStatus.Text = "Select at least one optimization task."
            return
        }
        $actions = @()
        if (0 -in $selectedTasks) { $actions += "FlushDns" }
        if (1 -in $selectedTasks) { $actions += "CleanTemp" }
        if (2 -in $selectedTasks) { $actions += "RemoveBloatware" }
        $packageNames = @($utilities.OptionalApps | Where-Object { $_.IsChecked } |
            ForEach-Object { [string]$_.Tag })
        if ("RemoveBloatware" -in $actions -and $packageNames.Count -eq 0) {
            $ui.HeaderStatus.Text = "Select one or more installed optional apps to remove."
            return
        }
        if ("RemoveBloatware" -in $actions -and -not $restorePointCheck.IsChecked) {
            $ui.HeaderStatus.Text = "A restore point is required before removing optional apps."
            return
        }
        $warning = "Apply the selected optimization tasks?"
        if ("CleanTemp" -in $actions -or "RemoveBloatware" -in $actions) {
            $warning = "Selected tasks may delete files or remove apps and may not be reversible. The selected apps are current-user packages from a vetted allowlist. Continue?"
        }
        if (New-RylWpfConfirm -Owner $window -Message $warning -Title "Confirm optimization") {
            Start-SystemChangePlan -Kind "Optimize" -Actions $actions `
                -PackageNames $packageNames -CreateRestorePoint ([bool]$restorePointCheck.IsChecked)
        }
    })
    $openRestoreButton.Add_Click({
        try {
            Start-Process -FilePath (Join-Path $env:WINDIR "System32\rstrui.exe") -ErrorAction Stop
        } catch {
            $ui.HeaderStatus.Text = "Could not open System Restore: $($_.Exception.Message)"
        }
    })

    function Request-AutoUpdateChange {
        param([bool]$Enable)

        $message = if ($Enable) {
            "This removes the local NoAutoUpdate policy value so Windows Update can use its normal configuration. Administrator approval is required; organization policy may override it. Continue?"
        } else {
            "This sets a machine-wide policy to disable automatic Windows Updates. The PC may miss security updates. Administrator approval is required. Continue?"
        }
        if (New-RylWpfConfirm -Owner $window -Message $message -Title "Confirm Windows Update change") {
            Start-BackgroundAction -Name $(if ($Enable) { "Enabling automatic updates" } else { "Disabling automatic updates" }) `
                -Action "SetAutomaticUpdates" -DisableAutomaticUpdates (-not $Enable)
        }
    }
    $disableUpdatesButton.Add_Click({ Request-AutoUpdateChange -Enable $false })
    $enableUpdatesButton.Add_Click({ Request-AutoUpdateChange -Enable $true })

    foreach ($button in $quickTools.Values) {
        $button.Add_Click({
            param($sender, $eventArgs)
            $target = [string]$sender.Tag
            try {
                if ($target -match '^Script:') {
                    $scriptName = $target.Substring(7)
                    if ($scriptName -notmatch '^[A-Za-z0-9_-]+\.ps1$') {
                        throw "Invalid quick-tool script name."
                    }
                    $scriptPath = Join-Path (Join-Path $state.Root "Tools") $scriptName
                    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                        throw "Quick-tool script was not found: $scriptPath"
                    }
                    $hostExecutable = Join-Path $PSHOME "powershell.exe"
                    if (-not (Test-Path -LiteralPath $hostExecutable)) {
                        $hostExecutable = Join-Path $PSHOME "pwsh.exe"
                    }
                    $quotedScript = '"' + $scriptPath.Replace('"', '""') + '"'
                    Start-Process -FilePath $hostExecutable `
                        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $quotedScript" `
                        -WorkingDirectory $state.Root -WindowStyle Hidden -ErrorAction Stop
                } elseif ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') {
                    Start-Process -FilePath $target -ErrorAction Stop
                } else {
                    $toolPath = Join-Path (Join-Path $env:WINDIR "System32") $target
                    if (-not (Test-Path -LiteralPath $toolPath)) {
                        throw "Windows tool was not found: $toolPath"
                    }
                    Start-Process -FilePath $toolPath -ErrorAction Stop
                }
                $ui.HeaderStatus.Text = "$($sender.Content) opened."
            } catch {
                $ui.HeaderStatus.Text = "Could not open $($sender.Content): $($_.Exception.Message)"
            }
        })
    }

    $retryButton.Add_Click({ Start-BackgroundAction -Name "WinGet setup" -Action "CheckWinget" })
    $storeButton.Add_Click({
        Start-Process -FilePath "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction Stop
    })
    $openFolderButton.Add_Click({
        try {
            $folder = $state.Settings.OfflineDirectory
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$folder`"" -ErrorAction Stop
        } catch {
            $ui.HeaderStatus.Text = "Could not open offline folder: $($_.Exception.Message)"
        }
    })
    $searchBox.Add_TextChanged({
        Set-AppCatalog -Category $state.SelectedCategory
    })
    $refreshButton.Add_Click({ Start-MonitorRefresh })
    $elevationButton.Add_Click({
        $message = "The CPU exposes temperature sensors but returned no values. Restart RylUtils with administrator approval to read them?"
        if (-not (New-RylWpfConfirm -Owner $window -Message $message -Title "Administrator access required")) {
            return
        }
        try {
            $scriptPath = Join-Path $state.Root "Main.ps1"
            $hostCandidates = @()
            if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
                $hostCandidates += Join-Path $env:WINDIR "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
            }
            $hostCandidates += Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
            $powerShellPath = $hostCandidates | Where-Object { Test-Path -LiteralPath $_ } |
                Select-Object -First 1
            if (-not $powerShellPath) {
                throw "Cannot find 64-bit Windows PowerShell."
            }
            $quotedScript = '"' + $scriptPath.Replace('"', '""') + '"'
            Start-Process -FilePath $powerShellPath `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File $quotedScript -HiddenLaunch" `
                -WorkingDirectory $state.Root -Verb RunAs -WindowStyle Hidden -ErrorAction Stop | Out-Null
            $window.Close()
        } catch {
            $ui.HeaderStatus.Text = "Could not restart elevated: $($_.Exception.Message)"
        }
    })

    $state.WingetAvailable = $false
    $ui.HeaderStatus.Text = $LHMStatus
    Initialize-AppCategories
    Set-AppCatalog -Category "All"
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds([math]::Max(1000, $Settings.RefreshInterval))
    $timer.Add_Tick({
        if ($state.ActionPowerShell -and
            -not [string]::IsNullOrWhiteSpace($state.ActionProgressPath) -and
            (Test-Path -LiteralPath $state.ActionProgressPath)) {
            try {
                $progressInfo = Get-Content -LiteralPath $state.ActionProgressPath -Raw -ErrorAction Stop |
                    ConvertFrom-Json
                $percent = [math]::Min(100, [math]::Max(0, [int]$progressInfo.Percent))
                $ui.Progress.Value = $percent
                $progressLine = "{0}%  {1}" -f $percent, [string]$progressInfo.Detail
                $ui.ActionSummary.Text = $progressLine
                $ui.HeaderStatus.Text = $progressLine
                $detailLine = "{0}%  {1}" -f $percent, [string]$progressInfo.Detail
                if ($progressInfo.State -ne "Running") {
                    $detailLine = "$($progressInfo.State): $($progressInfo.Detail)"
                }
                if ($state.LastProgressRecord -ne $detailLine) {
                    Add-RylProgressDetail -Text $detailLine
                    $state.LastProgressRecord = $detailLine
                }
            } catch {
                $ui.ActionSummary.Text = "Progress update unavailable: $($_.Exception.Message)"
            }
        }

        if ($state.MonitorAsync -and $state.MonitorAsync.IsCompleted) {
            try {
                $result = $state.MonitorPowerShell.EndInvoke($state.MonitorAsync) |
                    Select-Object -Last 1
                if ($result) {
                    $monitor.Cards.CPU.Value.Text = "$($result.CPU)%"
                    $monitor.Cards.CPU.Bar.Value = [math]::Min(100, [math]::Max(0, [int]$result.CPU))
                    $monitor.Cards.RAM.Value.Text = "$($result.RAMUsed) GB"
                    $monitor.Cards.RAM.Bar.Value = [math]::Min(100, [math]::Max(0, [int]$result.RAMPercent))
                    if ($result.DiskTotalGB -gt 0) {
                        $monitor.Cards.Disk.Value.Text = "$($result.DiskUsedPercent)% used"
                        $monitor.Cards.Disk.Bar.Value = [math]::Min(100, [math]::Max(0, [int]$result.DiskUsedPercent))
                    } else {
                        $monitor.Cards.Disk.Value.Text = "N/A"
                        $monitor.Cards.Disk.Bar.Value = 0
                    }
                    if ($result.NetworkError) {
                        $monitor.Cards.Network.Value.Text = "Unavailable"
                        $monitor.Cards.Network.Bar.Value = 0
                    } elseif (@($result.NetworkAdapters).Count -eq 0) {
                        $monitor.Cards.Network.Value.Text = "No active adapter"
                        $monitor.Cards.Network.Bar.Value = 0
                    } elseif ($result.NetworkHasRate) {
                        $monitor.Cards.Network.Value.Text = "RX {0:N1} / TX {1:N1} Mb/s" -f `
                            $result.NetworkDownloadMbps, $result.NetworkUploadMbps
                        $totalNetworkMbps = [double]$result.NetworkDownloadMbps + [double]$result.NetworkUploadMbps
                        $monitor.Cards.Network.Bar.Value = [math]::Min(100, [math]::Max(0, [int][math]::Round($totalNetworkMbps)))
                    } else {
                        $monitor.Cards.Network.Value.Text = "Sampling network..."
                        $monitor.Cards.Network.Bar.Value = 0
                    }
                    if ($result.Uptime) {
                        $uptimeDays = [int][math]::Floor($result.Uptime.TotalDays)
                        $monitor.Cards.Uptime.Value.Text = if ($uptimeDays -gt 0) {
                            "{0}d {1}h" -f $uptimeDays, $result.Uptime.Hours
                        } else {
                            "{0}h {1}m" -f $result.Uptime.Hours, $result.Uptime.Minutes
                        }
                    } else {
                        $monitor.Cards.Uptime.Value.Text = "N/A"
                    }
                    if ($null -ne $result.Temperature) {
                        $monitor.Cards.Temp.Value.Text = "{0} {1}C" -f $result.Temperature, [char]0x00B0
                        $monitor.Cards.Temp.Bar.Value = [math]::Min(100, [math]::Max(0, [int]($result.Temperature * 2)))
                    } else {
                        $monitor.Cards.Temp.Value.Text = "N/A"
                        $monitor.Cards.Temp.Bar.Value = 0
                    }
                    $diskDetails = if ($result.DiskTotalGB -gt 0) {
                        "$([Environment]::GetEnvironmentVariable('SystemDrive')) $($result.DiskFreeGB) GB free / $($result.DiskTotalGB) GB"
                    } else {
                        "Unavailable: $($result.DiskError)"
                    }
                    $networkRateDetails = if ($result.NetworkHasRate) {
                        "RX $($result.NetworkDownloadMbps) / TX $($result.NetworkUploadMbps) Mb/s"
                    } else {
                        [string]$result.NetworkError
                    }
                    $monitor.Details.Text = @"
DISK: $diskDetails
NETWORK: $(@($result.NetworkAdapters) -join ', ') $networkRateDetails
UPTIME: $($result.Uptime)
TEMPERATURE SENSOR: $($result.Sensor)
LAST UPDATE: $($result.Time)
"@
                    $monitor.ElevationButton.Visibility = if ($result.TemperatureRequiresElevation) {
                        "Visible"
                    } else {
                        "Collapsed"
                    }
                    $state.MonitorNetworkSample = $result.NetworkSample
                    if (-not $state.ActionPowerShell) {
                        $ui.HeaderStatus.Text = if ($result.TemperatureRequiresElevation) {
                            "Administrator approval needed for CPU temperature"
                        } else {
                            "Monitoring active"
                        }
                    }
                }
            } catch {
                if (-not $state.ActionPowerShell) {
                    $ui.HeaderStatus.Text = "Monitoring error: $($_.Exception.Message)"
                }
            } finally {
                $state.MonitorPowerShell.Dispose()
                $state.MonitorPowerShell = $null
                $state.MonitorAsync = $null
            }
        }

        if ($state.ActionPowerShell -and $state.ActionAsync.IsCompleted) {
            $actionName = $state.ActionName
            $refreshInstalledApps = $actionName -in @("InstallApp", "UninstallApp")
            try {
                $result = @($state.ActionPowerShell.EndInvoke($state.ActionAsync))
                if ($state.ActionPowerShell.Streams.Error.Count -gt 0) {
                    $lastError = $state.ActionPowerShell.Streams.Error[
                        $state.ActionPowerShell.Streams.Error.Count - 1
                    ]
                    throw $lastError.Exception.Message
                }
                if ($actionName -eq "CheckWinget" -and $result.Count -gt 0) {
                    $state.WingetAvailable = [bool]$result[-1].Available
                    $state.InstalledPackageIds = @{}
                    $state.InstalledAppsKnown = $false
                    $state.InstalledAppsError = $false
                    $refreshInstalledApps = $state.WingetAvailable
                    $quickSetup.DownloadButton.IsEnabled = $state.WingetAvailable
                    $storeButton.Visibility = if ($result[-1].StoreRequired) { "Visible" } else { "Collapsed" }
                    if ($state.WingetAvailable) {
                        $wingetStatus.Text = "WinGet is ready."
                        $wingetStatus.Foreground = ConvertTo-RylBrush "#8FE0A5"
                    } else {
                        $wingetStatus.Text = "App Installer is not available. Install it from Microsoft Store."
                        $wingetStatus.Foreground = ConvertTo-RylBrush "#FFB36B"
                    }
                    Set-AppCatalog -Category $state.SelectedCategory
                    $message = [string]$wingetStatus.Text
                } elseif ($actionName -eq "CheckInstalledApps" -and $result.Count -gt 0) {
                    $state.InstalledPackageIds = @{}
                    foreach ($packageId in @($result[-1].PackageIds)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$packageId)) {
                            $state.InstalledPackageIds[[string]$packageId] = $true
                        }
                    }
                    $state.InstalledAppsKnown = $true
                    $state.InstalledAppsError = $false
                    Set-AppCatalog -Category $state.SelectedCategory
                    $message = "Installed app status loaded ($($state.InstalledPackageIds.Count) WinGet apps)."
                } else {
                    $message = if ($result.Count -gt 0) { [string]$result[-1] } else { "$actionName completed." }
                    if ($actionName -eq "ApplySystemPlan" -and
                        $state.ActivePlanKind -in @("ApplyDns", "RestoreDns")) {
                        $networkStatus.Text = $message
                        $restoreDnsButton.IsEnabled = [bool](Get-LatestDnsBackup)
                    }
                }
                if ($actionName -in @("DownloadQuickSetupApps", "InstallQuickSetupApps")) {
                    Refresh-QuickSetupStatuses
                }
                $ui.ActionSummary.Text = $message
                $ui.HeaderStatus.Text = $message
                Add-RylProgressDetail -Text $message
            } catch {
                $refreshInstalledApps = $actionName -in @("InstallApp", "UninstallApp")
                $failureDetail = $_.Exception.Message
                if ($actionName -eq "ApplySystemPlan" -and
                    (Test-Path -LiteralPath $state.ActionProgressPath)) {
                    try {
                        $helperProgress = Get-Content -LiteralPath $state.ActionProgressPath -Raw -ErrorAction Stop |
                            ConvertFrom-Json
                        if ($helperProgress.State -eq "Failed" -and
                            -not [string]::IsNullOrWhiteSpace([string]$helperProgress.Detail)) {
                            $failureDetail = [string]$helperProgress.Detail
                        }
                    } catch {
                        $failureDetail += " (Could not read elevated-action details: $($_.Exception.Message))"
                    }
                }
                $message = "$actionName failed: $failureDetail"
                $ui.ActionSummary.Text = $message
                $ui.HeaderStatus.Text = $message
                Add-RylProgressDetail -Text $message
                if ($actionName -eq "ApplySystemPlan" -and
                    $state.ActivePlanKind -in @("ApplyDns", "RestoreDns")) {
                    $networkStatus.Text = $message
                }
                if ($actionName -eq "CheckWinget") {
                    $state.WingetAvailable = $false
                    $state.InstalledPackageIds = @{}
                    $state.InstalledAppsKnown = $false
                    $state.InstalledAppsError = $false
                    $quickSetup.DownloadButton.IsEnabled = $false
                    $wingetStatus.Text = $message
                    $wingetStatus.Foreground = ConvertTo-RylBrush "#FF8888"
                    $storeButton.Visibility = "Visible"
                }
                if ($actionName -eq "CheckInstalledApps") {
                    $state.InstalledAppsKnown = $false
                    $state.InstalledAppsError = $true
                    Set-AppCatalog -Category $state.SelectedCategory
                    $wingetStatus.Text = "WinGet is ready, but installed app status is unavailable."
                    $wingetStatus.Foreground = ConvertTo-RylBrush "#FFB36B"
                }
                if ($actionName -in @("DownloadQuickSetupApps", "InstallQuickSetupApps")) {
                    Refresh-QuickSetupStatuses
                    $quickSetup.Status.Text = $message
                }
            } finally {
                if ($actionName -in @("InstallApp", "UninstallApp")) {
                    $refreshInstalledApps = $true
                }
                $state.ActionPowerShell.Dispose()
                $state.ActionRunspace.Close()
                $state.ActionRunspace.Dispose()
                $state.ActionPowerShell = $null
                $state.ActionRunspace = $null
                $state.ActionAsync = $null
                $state.ActionName = ""
                $state.ActivePlanKind = ""
                if (-not [string]::IsNullOrWhiteSpace($state.ActionCancelPath) -and
                    (Test-Path -LiteralPath $state.ActionCancelPath)) {
                    Remove-Item -LiteralPath $state.ActionCancelPath -Force -ErrorAction SilentlyContinue
                }
                $state.ActionCancelPath = ""
                $ui.StopAction.IsEnabled = $false
                $ui.StopAction.Visibility = "Collapsed"
                if ($state.ActionProgressPathOwned -and
                    (Test-Path -LiteralPath $state.ActionProgressPath)) {
                    Remove-Item -LiteralPath $state.ActionProgressPath -Force -ErrorAction SilentlyContinue
                }
                $state.ActionProgressPath = ""
                $state.ActionProgressPathOwned = $false
                if ($actionName -eq "SetAutomaticUpdates") {
                    Update-AutoUpdateStatus
                }
                if ($refreshInstalledApps -and $state.WingetAvailable) {
                    $state.InstalledAppsKnown = $false
                    $state.InstalledAppsError = $false
                    Set-AppCatalog -Category $state.SelectedCategory
                    Start-BackgroundAction -Name "Refreshing installed app status" `
                        -Action "CheckInstalledApps"
                }
            }
        }
        if (-not $state.MonitorAsync) {
            Start-MonitorRefresh
        }
    })

    $window.Add_ContentRendered({
        $timer.Start()
        Start-MonitorRefresh
        Update-AutoUpdateStatus
        Initialize-UtilityOptions
        Refresh-QuickSetupStatuses
        Set-AppCatalog -Category "All"
        Start-BackgroundAction -Name "WinGet setup" -Action "CheckWinget"
    })
    $window.Add_Closed({
        $timer.Stop()
        if ($state.MonitorPowerShell) {
            if ($state.MonitorAsync -and -not $state.MonitorAsync.IsCompleted) {
                $state.MonitorPowerShell.Stop()
            }
            $state.MonitorPowerShell.Dispose()
        }
        $state.MonitorRunspace.Close()
        $state.MonitorRunspace.Dispose()
        if ($state.ActionPowerShell) {
            if ($state.ActionAsync -and -not $state.ActionAsync.IsCompleted) {
                $state.ActionPowerShell.Stop()
            }
            $state.ActionPowerShell.Dispose()
        }
        if ($state.ActionRunspace) {
            $state.ActionRunspace.Close()
            $state.ActionRunspace.Dispose()
        }
        $timer.Stop()
    })
    [void]$window.ShowDialog()
}
