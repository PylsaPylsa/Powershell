param (
    [string]$CredFile = "cred.txt",
    [string]$UserName = "srv-prtg-azure@contoso.local",
    [string]$Tenant = "Contoso",
    [string]$HostPool = "Contoso Desktop"
)
$CredFile = $(Join-Path -Path $PSScriptRoot -ChildPath $CredFile )

if(!(Get-module Microsoft.RDInfra.RDPowerShell)){
    Import-Module -Name Microsoft.RDInfra.RDPowerShell | Out-Null
}

# Uncomment below to (re)create the credential object. Run this code as the same user you are 
# saving the credentials for and on the computer you will be running this script from.

#$credential = Get-Credential -UserName $UserName -Message "Enter Credentials"
#$credential.Password | ConvertFrom-SecureString | Out-File $CredFile

$PwdTxt = Get-Content $CredFile
$SecurePwd = $PwdTxt | ConvertTo-SecureString 
$CredObject = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePwd

$RdsAccount = Add-RdsAccount -DeploymentUrl https://rdbroker.wvd.microsoft.com -Credential $CredObject

$SessionHosts = Get-RdsSessionHost -TenantName $Tenant -HostPoolName $HostPool
$UserSessions = Get-RdsUserSession -TenantName $Tenant -HostPoolName $HostPool

$ErrorStatus = 0
$StatusMessage = ""

$SessionHostsAvailable = ($SessionHosts | Where {$_.Status -eq 'Available' -and $_.AllowNewSession -eq 'True'}).Count
$SessionTotal = $UserSessions.Count

$XMLResult = @"
<prtg>
   <result>
       <channel>User Sessions</channel>
       <value>$SessionTotal</value>
   </result>

   <result>
       <channel>Hosts available for logon</channel>
       <value>$SessionHostsAvailable</value>
   </result>
</prtg>
"@

$XMLResult