# Set up UWF for Windows 10 Enterprise

This PowerShell script will set up Microsoft Unified Write Filter (UWF) for you on Windows 10 Enterprise with the [recommended common exclusions](https://docs.microsoft.com/en-us/windows-hardware/customize/enterprise/uwfexclusions). It then also installs an 

[^edited version]: Removed some user interaction on first run: Will always create configuration keys in registry; Will not ask to run on startup; Will set default password to "uwfadmin".

 some great tools developed by [Daniel Mushailov](https://github.com/dmushail) that adds a status indicator to the systray as well as adds a GUI element when double clicked to turn UWF on or off on demand.

## Prerequisites

* Windows 10 Enterprise (activated). UWF is not licensed for use with any other edition of Windows 10.
* No pending reboots.
* Run as administrator.

## Performed actions

1. Checks if prerequisites are satisified.
2. 

