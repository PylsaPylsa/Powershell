param (
    [string]$CredFile = "cred.txt",
    [string]$UserName = "srv-prtg-azure@contoso.local",
    [string]$Tenant = "Contoso",
    [string]$HostPool = "Contoso Desktop",
    [Parameter(Mandatory=$true)]
    [string]$SessionHost
)
$CredFile = $(Join-Path -Path $PSScriptRoot -ChildPath $CredFile )

if(!(Get-module Microsoft.RDInfra.RDPowerShell)){
    Import-Module -Name Microsoft.RDInfra.RDPowerShell | Out-Null
}

# Run the commented lines below to (re)create the credential object. Run this code as the same user you are 
# saving the credentials for and on the computer you will be running this script from. The user must have
# RDS Reader permissions on your Hostpool.

#$credential = Get-Credential -UserName $UserName -Message "Enter Credentials"
#$credential.Password | ConvertFrom-SecureString | Out-File $CredFile

$PwdTxt = Get-Content $CredFile
$SecurePwd = $PwdTxt | ConvertTo-SecureString 
$CredObject = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePwd

$RdsAccount = Add-RdsAccount -DeploymentUrl https://rdbroker.wvd.microsoft.com -Credential $CredObject

$DNSRecord = Resolve-DnsName -Name $SessionHost -Type CNAME

$SessionHostObj = Get-RdsSessionHost -TenantName $Tenant -HostPoolName $HostPool -Name $DNSRecord.NameHost

$ErrorStatus = 0
$StatusMessage = ""

If($SessionHostObj.AllowNewSession -ne "TRUE") { $ErrorStatus = 1; $StatusMessage = $StatusMessage + "Host is not accepting new sessions (drain mode is ON). "; $HostAllowNewSession = 0 } Else { $HostAllowNewSession = 1 }
If($SessionHostObj.Status -ne "Available") { $ErrorStatus = 1; $StatusMessage = $StatusMessage + "Host is not available to broker. (Status: $($SessionHostObj.Status))"; $HostStatus = 0 } Else { $HostStatus = 1 }

$XMLResult = @"
<prtg>
   <result>
       <channel>User Sessions</channel>
       <value>$($SessionHostObj.Sessions)</value>
   </result>

   <result>
       <channel>Host Status</channel>
       <value>$HostStatus</value>
   </result>

   <result>
       <channel>Host Accepting Sessions</channel>
       <value>$HostAllowNewSession</value>
   </result>

   <error>$ErrorStatus</error>
   <text>$(&{If($StatusMessage -eq "") {"Host status OK"} Else {"$($StatusMessage.Trim())"}})</text>
</prtg>
"@

$XMLResult