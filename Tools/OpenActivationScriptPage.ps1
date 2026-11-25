$ErrorActionPreference = "Stop"

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-Command",
    "irm https://get.activated.win | iex"
)