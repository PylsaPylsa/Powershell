cls
$DisplayName = $Null
$Proceed = $Null
$Purpose = $Null
$Perms = $Null

While($Null -eq $DisplayName){
    Write-Host "[?] What is the display name for the new group? " -NoNewline -ForegroundColor Green
    $DisplayName = Read-Host
}

While($Null -eq $Perms -or ($Perms -cne 'SendTo' -and $Perms -cne 'FA' -and $Perms -cne 'SA')){
    Write-Host "[?] What permissions will members of the group have? (Case-sensitive: SendTo/FA/SA) " -NoNewline -ForegroundColor Green
    $Perms = Read-Host
}

While($Null -eq $Purpose -or ($Purpose -cne 'DL' -and $Purpose -cne 'MB')){
    Write-Host "[?] What will this group be applied to? (Case-sensitive: DL/MB) " -NoNewline -ForegroundColor Green
    $Purpose = Read-Host
}

$Alias = $DisplayName.Replace(" ", "_")

Write-Host @"
[!] The script will create a new mail-enabled security group with these properties:
    Display name:                            $($Purpose)_$($DisplayName)_$($Perms)
    Alias:                                   $($Purpose)_$($Alias)_$($Perms)
    Name:                                    $($Purpose)_$($DisplayName)_$($Perms)
    Mail:                                    $($Purpose)_$($Alias)_$($Perms)@levvel5.nl

    Block senders from outside organization: TRUE
    Hide from address lists:                 TRUE


"@ -ForegroundColor Cyan -NoNewline

While($Proceed -ne "Y"){
    Write-Host "[?] Proceed? (Y) " -NoNewline -ForegroundColor Green
    $Proceed = Read-Host
}


Write-Host "[*] Creating group $Displayname" -ForegroundColor "Green"
New-ADGroup -GroupCategory Security -GroupScope Global -DisplayName "$($Purpose)_$($DisplayName)_$($Perms)" -Name "$($Purpose)_$($DisplayName)_$($Perms)" -Path "OU=Mailbox,OU=Security,OU=Groups,OU=Levvel5,DC=levvel5,DC=local" -OtherAttributes @{'Mail'="$($Purpose)_$($Alias)_$($Perms)@levvel5.nl";'ProxyAddresses'="SMTP:$($Purpose)_$($Alias)_$($Perms)@levvel5.nl"; 'msExchRequireAuthToSendTo'='TRUE'; 'msExchHideFromAddressLists'='TRUE'}

Write-Host "`nScript terminated at end of script. [Press Enter to exit]" -ForegroundColor Cyan
Read-Host