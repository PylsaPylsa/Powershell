# Set up UWF for Windows 10 Enterprise

This PowerShell script will set up a base configuration of Microsoft Unified Write Filter (UWF) for you on Windows 10 Enterprise with the [recommended common exclusions](https://docs.microsoft.com/en-us/windows-hardware/customize/enterprise/uwfexclusions). It then also installs an edited version *(removed some user interaction on first run: Will always create configuration keys in registry; Will not ask to run on startup; Will set default password to "uwfadmin" instead of "admin")* of some great tools developed by [Daniel Mushailov](https://github.com/dmushail) that add a status indicator to the systray as well as add a GUI element when double clicked to turn UWF on or off on demand.

Please note that this is a stub to help you get on your way. This is by no means a solution fitting for everyone and for each situation. Please consult the [official documentation](https://docs.microsoft.com/en-us/windows-hardware/customize/enterprise/unified-write-filter) first.

![Screenshot](https://github.com/PylsaPylsa/Powershell/raw/master/Windows/Enable%20UWF/Screenshot.png)

## Prerequisites

* Windows 10 Enterprise (activated). UWF is not licensed for use with any other edition of Windows 10.
* No pending reboots.
* Run as administrator.

## Performed actions

1. Checks if prerequisites are satisified.
2. Install UWF as optional windows feature if not yet installed.
3. Set up common exclusions.
4. Configure overlay settings. *You can specify custom settings at the top of the script.*
5. Disable hibernation.
6. Installs [Daniel Mushailov](https://github.com/dmushail)'s UWF manager and UWF monitor.
7. Enables UWF filter.
8. Protects your `C:\` drive.