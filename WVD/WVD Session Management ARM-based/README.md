# WVD Session Management tool (ARM version)

This PowerShell script uses a form to provide a GUI to some of the AZ PowerShell modules for Windows Virtual Desktop Hostpools. It is not perfect by any stretch of the word and should be considered an messy, unoptimized Alpha release. The code comes as-is as a stub to get your own things working (that being said, it should work fine). I cannot provide support but will happily take any bug reports.

## Pre-requisites

- The [Az.DesktopVirtualization](https://docs.microsoft.com/en-us/powershell/module/az.desktopvirtualization/?view=azps-5.1.0) module for PowerShell.

  - ```powershell
    Install-Module -Name Az.DesktopVirtualization
    ```

## Pre-configuration

The script will ask for your Tenant ID and Resource group on start but you may save these to the registry to prevent it from asking each time:

```
[HKEY_LOCAL_MACHINE\SOFTWARE\Pylsa]
"WVDResourceGroupName"=""
"TenantId"=""
```

If you want to get the remote shadowing part working, check out Robin Hobo's blog [here](https://www.robinhobo.com/how-to-shadow-an-active-user-session-in-windows-virtual-desktop-via-remote-desktop-connection-mstc/)! He has a great explanation

## Screenshots

![Session overview](https://raw.githubusercontent.com/PylsaPylsa/Powershell/master/WVD/WVD%20Session%20Management%20ARM-based/Screenshots%20Sessions.png)

![Hosts overview](https://raw.githubusercontent.com/PylsaPylsa/Powershell/master/WVD/WVD%20Session%20Management%20ARM-based/Screenshot%20Hosts.png)