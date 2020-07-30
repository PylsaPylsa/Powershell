# WVD Hosts Status PRTG Sensor

This PowerShell script can be used as  PRTG Advanced XML/EXE sensor and will read if it is accepting sessions from the WVD broker, whether the WVD agent is available to the WVD broker and how many users are currently logged onto the host.

![Screenshot](https://github.com/PylsaPylsa/Powershell/raw/master/PRTG/WVD%20Host%20Status/Screenshot.png)

## Prerequisites

* The `Microsoft.RDInfra.RDPowerShell` PowerShell module has to be installed on the probe machine.

  * ```powershell
    Install-Module -Name Microsoft.RDInfra.RDPowerShell
    ```

* An AD (service) account synced to AAD that has the *RDS Reader* role assigned on your WVD RDS tenant.

## Setup

1. Place the file in the PRTG program directory on the probe machine under `Custom Sensors\EXEXML`.

2. Create the credential object for the AD (service) account that has the  *RDS Reader* role assigned by running the commands below. This is used to save the credentials safely. Run a PowerShell prompt under the same user context your PRTG service runs under.

   ```powershell
   [string]$CredFile = "cred.txt"
   [string]$UserName = "srv-prtg-azure@contoso.local"
   ```

   ```powershell
   $credential = Get-Credential -UserName $UserName -Message "Enter Credentials"
   ```

   ```powershell
   $credential.Password | ConvertFrom-SecureString | Out-File $CredFile
   ```

3. In PRTG, create the sensor using the parameter below.

   ```
   -SessionHost LV5-AZU-WVD-12
   ```

   

