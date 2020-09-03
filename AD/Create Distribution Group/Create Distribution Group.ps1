cls
$DisplayName = $Null
$Proceed = $Null
$RequireAuthToSendTo = $Null
$HideFromAddressLists = $Null

While($Null -eq $DisplayName){
    Write-Host "[?] What is the display name for the new group? " -NoNewline -ForegroundColor Green
    $DisplayName = Read-Host
}

While($Null -eq $RequireAuthToSendTo -or ($RequireAuthToSendTo -ne 'TRUE' -and $RequireAuthToSendTo -ne 'FALSE')){
    Write-Host "[?] Block senders from outside organization? (TRUE/FALSE) " -NoNewline -ForegroundColor Green
    $RequireAuthToSendTo = Read-Host
}

While($Null -eq $HideFromAddressLists -or ($HideFromAddressLists -ne 'TRUE' -and $HideFromAddressLists -ne 'FALSE')){
    Write-Host "[?] Hide from address lists? (TRUE/FALSE) " -NoNewline -ForegroundColor Green
    $HideFromAddressLists = Read-Host
}

$Alias = $DisplayName.Replace(" ", "_")

Write-Host @"
[!] The script will create a new distribution list with these properties:
    Display name:                            $DisplayName
    Alias:                                   DL_$Alias
    Name:                                    DL_$DisplayName
    Mail:                                    DL_$($Alias)@levvel5.nl

    Block senders from outside organization: $RequireAuthToSendTo
    Hide from address lists:                 $HideFromAddressLists


"@ -ForegroundColor Cyan -NoNewline

While($Proceed -ne "Y"){
    Write-Host "[?] Proceed? (Y) " -NoNewline -ForegroundColor Green
    $Proceed = Read-Host
}


Write-Host "[*] Creating group $Displayname" -ForegroundColor "Green"
New-ADGroup -GroupCategory Distribution -GroupScope Universal -DisplayName $DisplayName -Name "DL_$DisplayName" -Path "OU=Distribution,OU=Groups,OU=Levvel5,DC=levvel5,DC=local" -OtherAttributes @{'Mail'="DL_$($Alias)@levvel5.nl";'ProxyAddresses'="SMTP:DL_$($Alias)@levvel5.nl"; 'msExchRequireAuthToSendTo'="$RequireAuthToSendTo"; 'msExchHideFromAddressLists'="$HideFromAddressLists"}

Write-Host "`nScript terminated at end of script. [Press Enter to exit]" -ForegroundColor Cyan
Read-Host