Clear-Host
$Length = 12
$Password = $Null
$User = $Null
$Username = $Null
$LiftLockOut = $Null


While($Null -eq $User){
    Write-Host '[?] Enter username of account to reset: ' -NoNewline -ForegroundColor "Cyan"
    $UserName = Read-Host
    $User = Get-ADUser -LDAPFilter "(sAMAccountName=$UserName)" -Properties DisplayName,SAMAccountname,LockedOut

    #Check if user exists in Active Directory. If not, loop and ask again.
    If($Null -eq $User){ Write-Host '[!] User does not exist, check and enter username again.' -ForegroundColor "Yellow" }
}

If($User.LockedOut){ 
    Write-Host '[?] Account is locked out, also unlock account? [Y/N Defaults to Y] ' -NoNewLine -ForegroundColor "Cyan"
    $LiftLockOut = Read-Host
    If($LiftLockOut -ne "N"){
        Unlock-ADAccount -Identity $User
        Write-Host "[*] Account has been unlocked" -ForegroundColor "Green"
    }else{
        Write-Host "[!] Leaving account locked" -ForegroundColor "Yellow"
    }
}

Write-Host "[*] Changing password for $($User.DisplayName)." -ForegroundColor "Green"

While(!$($Password -cmatch '[A-Z]') -or !$($Password -cmatch '[a-z]') -or !$($Password -cmatch '[0-9]')){
    $Password =  ([char[]]('A'[0]..'Z'[0]) + [char[]]('a'[0]..'z'[0]) + 0..9 | sort {Get-Random})[0..$Length] -join ''
}

Set-ADAccountPassword -Identity $User -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force) -Reset

Write-Host "`n    Password set to: $Password" -ForegroundColor "Green"