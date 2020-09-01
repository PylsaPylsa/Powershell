$Server = '172.0.0.1'           # IP Address or DNS-valid hostname of Synology
$ServerHostname = 'syn01'       # Hostname as set in Synology system (how the Synology knows itself)
$Share = "\\$Server\Data"       # Share path 

$Cred = $Null
$Cred = Get-Credential -Message "Enter credentials to connect to RAW-Data"
$Username = $Cred.Username
$Password = $Cred.GetNetworkCredential().Password

cmdkey /delete:$Server *> $Null
cmdkey /add:$Server /user:"$ServerHostname\$Username" /pass:$Password *> $Null

Remove-PSDrive -Name "R" *> $Null
New-PSDrive -Name "R" -Root $Share -Persist -PSProvider "FileSystem"  *> $Null
exit