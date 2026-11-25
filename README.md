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

## Offline Installers

Offline installers can be placed in `offline_apps`. The app catalog identifies which entries support offline installation.

The repository also includes bundled installers and an offline copy of selected tools. Downloading or running third-party software is subject to the original publisher's terms.

## Configuration

- `Config.xml` - application name, version, monitor refresh rate, enabled sensors, theme colors, and offline directory
- `Apps.xml` - app catalog and WinGet package IDs
- `Bloatware.xml` - optional Microsoft Store app removal allowlist
- `DnsProfiles.xml` - DNS providers and server addresses
- `Assets\` - app icons and bundled assets
- `Logs\` - application and startup logs
- `Backups\` - DNS and system configuration backups

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
