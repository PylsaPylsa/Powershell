cls

$Mailbox = $Null
$FetchedMailbox = $Null
$Proceed = $Null
$HideFromAddressLists = $Null

While($Null -eq $Mailbox -or $Null -eq $FetchedMailbox){
    Write-Host "[?] What is mail address for the mailbox? " -NoNewline -ForegroundColor Green
    $Mailbox = Read-Host
    $FetchedMailbox = Get-ADUser -Filter 'mail -like $Mailbox' -properties mail,displayname,msExchHideFromAddressLists,mailnickname,samaccountname
}

Switch($FetchedMailbox.msExchHideFromAddressLists){
    "TRUE" { $CurrentSettings = "TRUE"; break }
    "FALSE" { $CurrentSettings = "FALSE"; break }
    default { $CurrentSettings = "FALSE"; break }
}

While($Null -eq $HideFromAddressLists -or ($HideFromAddressLists -ne 'TRUE' -and $HideFromAddressLists -ne 'FALSE')){
    Write-Host "[?] Hide from address lists? This is currently set to $CurrentSettings. (TRUE/FALSE) " -NoNewline -ForegroundColor Green
    $HideFromAddressLists = Read-Host
}

Write-Host @"
[!] The script will modify an existing mailbox with these properties:
    Display name:                            $($FetchedMailbox.displayname)
    Mail:                                    $($FetchedMailbox.mail)
    
    Mailnickname:                            $(&{If($FetchedMailbox.mailnickname) {"$($FetchedMailbox.mailnickname)"} Else {"Will be set to $($FetchedMailbox.samaccountname)"}})
    Hide from address lists:                 $HideFromAddressLists (was $($CurrentSettings))


"@ -ForegroundColor Cyan -NoNewline

While($Proceed -ne "Y"){
    Write-Host "[?] Proceed? (Y) " -NoNewline -ForegroundColor Green
    $Proceed = Read-Host
}

Write-Host "[*] Modifying mailbox $($FetchedMailbox.displayname)" -ForegroundColor "Green"
Set-ADUser -Identity $FetchedMailbox -Replace @{'msExchHideFromAddressLists'="$HideFromAddressLists"}

If(!$FetchedMailbox.mailnickname){ Set-ADUser -Identity $FetchedMailbox -Replace @{'mailnickname'="$($FetchedMailbox.samaccountname)"} }

Write-Host "`nScript terminated at end of script. [Press Enter to exit]" -ForegroundColor Cyan
Read-Host