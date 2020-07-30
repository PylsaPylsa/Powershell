# WVD Hosts Status PRTG Sensor

This PowerShell script can be used as  PRTG Advanced XML/EXE sensor and will read if it is accepting sessions from the WVD broker, whether the WVD agent is available to the WVD broker and how many users are currently logged onto the host.

![Screenshot](https://github.com/PylsaPylsa/Powershell/raw/master/WVD%20Hosts%20Status%20PRTG%20Status/screenshot.png)

## Prerequisites

* The `Microsoft.RDInfra.RDPowerShell` PowerShell module has to be installed on the probe machine.

  * ```powershell
    Install-Module -Name Microsoft.RDInfra.RDPowerShell
    ```

    

## Performed actions

1. Checks if prerequisites are satisified.
2. Install UWF as optional windows feature if not yet installed.
3. Set up common exclusions.
4. Configure overlay settings. *You can specify custom settings at the top of the script.*
5. Disable hibernation.
6. Installs [Daniel Mushailov](https://github.com/dmushail)'s UWF manager and UWF monitor.
7. Enables UWF filter.
8. Protects your `C:\` drive.