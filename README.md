# RylUtils

RylUtils is a Windows desktop utility built with PowerShell and WPF. It combines system monitoring, network configuration, Windows optimization tasks, app discovery and installation, and quick access to common Windows tools in one interface.

![Windows](https://img.shields.io/badge/Platform-Windows-0078D4)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-blue)
![License](https://img.shields.io/badge/License-Not%20specified-lightgrey)

## Features

- Live CPU, RAM, disk, network, uptime, and temperature monitoring
- CPU temperature readings through LibreHardwareMonitor
- Network adapter selection and DNS profile switching
- DNS cache flushing and automatic backup/restore of network settings
- Windows optimization presets and optional app removal
- WinGet app search, installation, and status checking
- Downloaded and offline installer management
- Quick links for Windows settings, System Restore, activation, and utilities
- Administrator elevation prompts for actions that require them

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7
- WinGet/App Installer for online app installation
- Administrator privileges for network changes and selected system tasks

## Getting Started

To download the latest public version and open the GUI directly from PowerShell (Git is not required), run:

```powershell
irm https://raw.githubusercontent.com/apellidoryl/rylUtil/main/Run-RylUtils.ps1 | iex
```

The launcher downloads the source and runtime bundle under `%LOCALAPPDATA%\RylUtils`, extracts the LibreHardwareMonitor dependency, deletes the downloaded ZIP archives, and prompts for UAC before opening the entire GUI as administrator. The extracted application and its local data (including logs, backups, and user-downloaded installers) remain on the computer after exit. This command executes code from the repository, so review and trust the source before running it.

To run from a local clone instead:

1. Clone the repository:

   ```powershell
   git clone https://github.com/apellidoryl/rylUtil.git
   cd rylUtil
   ```

2. From Windows PowerShell, run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Main.ps1
   ```

The launcher starts RylUtils in a hidden PowerShell host and opens the WPF interface.

## Runtime Bundle and Offline Installers

The public runtime bundle includes LibreHardwareMonitor and its license notices. Optional third-party app icons and offline installers are not redistributed; the GUI uses text glyphs when icons are unavailable. Use WinGet or obtain installers directly from their publishers and place them in `offline_apps`.

To rebuild the maximum-compression runtime ZIP, install 7-Zip and run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-RuntimeResources.ps1`. The build uses the local `Assets\LibreHardwareMonitor.zip` and fetches the matching upstream license notices.

## Configuration

- `Config.xml` - application name, version, monitor refresh rate, enabled sensors, theme colors, and offline directory
- `Apps.xml` - app catalog and WinGet package IDs
- `Bloatware.xml` - optional Microsoft Store app removal allowlist
- `DnsProfiles.xml` - DNS providers and server addresses
- `Assets\` - LibreHardwareMonitor runtime package; optional app icons are not included in the public bundle
- `Tools\LICENSES\` - LibreHardwareMonitor MPL-2.0 license and third-party notices
- `Tools\LibreHardwareMonitor\` - extracted at launch from the runtime bundle
- `offline_apps\` - locally supplied installers; not included in the public release
- `Logs\` - application and startup logs
- `Backups\` - local DNS and system configuration backups; not included in the public release

## Safety

Some actions change system-wide settings or remove applications. RylUtils asks for confirmation before most disruptive operations, but users should still review selections before applying them.

Before applying optimization tasks, a Windows System Restore point is strongly recommended. Disabling Windows Update or removing applications may leave the device outside your preferred update or support configuration.

The activation shortcut downloads and executes a third-party PowerShell script. RylUtils does not host or bundle that script. Only run it if you understand the script's source and licensing implications, and prefer an official Microsoft activation method for your licensed Windows or Office products.

## Credits and Acknowledgements

- Project by [@apellidoryl](https://github.com/apellidoryl)
- Hardware monitoring powered by [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor)
- Application discovery and installation use [Microsoft WinGet](https://learn.microsoft.com/windows/package-manager/winget/)
- Activation script credit: [Microsoft Activation Scripts](https://github.com/massgravel/microsoft-activation-scripts) by [massgravel](https://github.com/massgravel)
- Icons and bundled assets remain the property of their respective owners

## Contributing

Contributions are welcome. Please open an issue before proposing a large change and test PowerShell/WPF changes on Windows where administrator elevation may affect behavior.

## License

No license is currently specified in this repository. Before reuse or redistribution, contact the project owner or add an appropriate open-source license.
