$Computer = 'Some Host'
$Attempts = 20

$Credential = Get-Credential -Message 'Enter an account with incorrect password.'

1..$Attempts | ForEach-Object {
    try {
        Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer -Credential $Credential -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        Write-Warning -Message "Access is denied."
    } catch {
        Write-Warning -Message "Unknown Error." 
    }
}

If((Get-ADUser -id $User -Properties LockedOut).LockedOut -eq $true){
    Write-Verbose -Message 'Account is locked.' -Verbose
}ElseIf((Get-ADUser -id $User -Properties LockedOut).LockedOut -eq $false){
    Write-Verbose -Message 'Account is unlocked.' -Verbose
}