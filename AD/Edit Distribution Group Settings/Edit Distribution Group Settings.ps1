cls

$Group = $Null
$FetchedGroup = $Null
$Proceed = $Null
$RequireAuthToSendTo = $Null
$HideFromAddressLists = $Null
$LimitToGroup = $Null
$FetchedLimitGroup = $Null
$LimitGroupDN = $Null

While($Null -eq $Group -or $Null -eq $FetchedGroup){
    Write-Host "[?] What is mail address for the existing group? " -NoNewline -ForegroundColor Green
    $Group = Read-Host
    $FetchedGroup = Get-ADGroup -Filter 'mail -like $Group' -properties mail,displayname,msExchRequireAuthToSendTo,msExchHideFromAddressLists,dLMemSubmitPerms
}

While($Null -eq $RequireAuthToSendTo -or ($RequireAuthToSendTo -ne 'TRUE' -and $RequireAuthToSendTo -ne 'FALSE')){
    Write-Host "[?] Block senders from outside organization? (TRUE/FALSE) " -NoNewline -ForegroundColor Green
    $RequireAuthToSendTo = Read-Host
}

While($Null -eq $LimitToGroup -or ($LimitToGroup -ne 'TRUE' -and $LimitToGroup -ne 'FALSE')){
    Write-Host "[?] Limit senders to Security Group? (TRUE/FALSE) " -NoNewline -ForegroundColor Green
    $LimitToGroup = Read-Host
}

If($LimitToGroup -eq "TRUE"){
    While($Null -eq $LimitGroup -or $Null -eq $FetchedLimitGroup){
        Write-Host "    [?] What is mail address for the (mail-enabled) security group? " -NoNewline -ForegroundColor Green
        $LimitGroup = Read-Host
        $FetchedLimitGroup = Get-ADGroup -Filter 'mail -like $LimitGroup' -properties displayname,distinguishedname,mail
    }
    $LimitGroupDN = $($FetchedLimitGroup.distinguishedname)
}else{
    $LimitGroupDN = ""
}


While($Null -eq $HideFromAddressLists -or ($HideFromAddressLists -ne 'TRUE' -and $HideFromAddressLists -ne 'FALSE')){
    Write-Host "[?] Hide from address lists? (TRUE/FALSE) " -NoNewline -ForegroundColor Green
    $HideFromAddressLists = Read-Host
}

Write-Host @"
[!] The script will modify an existing distribution list with these properties:
    Display name:                            $($FetchedGroup.displayname)
    Mail:                                    $($FetchedGroup.mail)

    Limit senders to Security Group:         $LimitToGroup
        Limit to this group:                 $($FetchedLimitGroup.mail)
                                             $($FetchedLimitGroup.distinguishedname)
    Block senders from outside organization: $RequireAuthToSendTo (was $($FetchedGroup.msExchRequireAuthToSendTo))
    Hide from address lists:                 $HideFromAddressLists (was $($FetchedGroup.msExchHideFromAddressLists))


"@ -ForegroundColor Cyan -NoNewline

While($Proceed -ne "Y"){
    Write-Host "[?] Proceed? (Y) " -NoNewline -ForegroundColor Green
    $Proceed = Read-Host
}

Write-Host "[*] Modifying group $($FetchedGroup.displayname)" -ForegroundColor "Green"
If($LimitToGroup -eq "TRUE"){
    Set-ADGroup -Identity $FetchedGroup -Replace @{'msExchRequireAuthToSendTo'="$RequireAuthToSendTo"; 'msExchHideFromAddressLists'="$HideFromAddressLists"; 'dLMemSubmitPerms'="$LimitGroupDN"}
}else{
    Set-ADGroup -Identity $FetchedGroup -Replace @{'msExchRequireAuthToSendTo'="$RequireAuthToSendTo"; 'msExchHideFromAddressLists'="$HideFromAddressLists"} -Clear dLMemSubmitPerms
}

Write-Host "`nScript terminated at end of script. [Press Enter to exit]" -ForegroundColor Cyan
Read-Host