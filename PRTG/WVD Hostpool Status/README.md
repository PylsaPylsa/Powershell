# WVD Hosts Status PRTG Sensor

This PowerShell script can be used as PRTG Advanced XML/EXE sensor and will read how many hosts in your hostpool are both available and accepting sessions from the WVD broker and how many users are currently logged on in the entire pool.

## Prerequisites

* The `Microsoft.RDInfra.RDPowerShell` PowerShell module has to be installed on the probe machine.

  * ```powershell
    Install-Module -Name Microsoft.RDInfra.RDPowerShell
    ```

* An AD (service) account synced to AAD that has the *RDS Reader* role assigned on your WVD RDS tenant.

## Setup

1. Place the file in the PRTG program directory on the probe machine under `Custom Sensors\EXEXML`.

2. Create the credential object for the AD (service) account that has the  *RDS Reader* role assigned by running the commands below. This is used to save the credentials safely. Run a PowerShell prompt under the same user context your PRTG service/sensor runs under.

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
   -SessionHost CON-AZU-WVD-01
   ```

   

