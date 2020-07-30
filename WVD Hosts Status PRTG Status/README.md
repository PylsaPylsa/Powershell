# WVD Hosts Status PRTG Sensor

This PowerShell script can be used as  PRTG Advanced XML/EXE sensor and will read if it is accepting sessions from the WVD broker, whether the WVD agent is available to the WVD broker and how many users are currently logged onto the host.

![Screenshot](https://github.com/PylsaPylsa/Powershell/raw/master/WVD%20Hosts%20Status%20PRTG%20Status/screenshot.png)

## Prerequisites

* The `Microsoft.RDInfra.RDPowerShell` PowerShell module has to be installed on the probe machine.

  * ```powershell
    Install-Module -Name Microsoft.RDInfra.RDPowerShell
    ```

    

## Setup

1. 