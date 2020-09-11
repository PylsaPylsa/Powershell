Start-Transcript -Append -Path ~\Desktop\Transcript.log
$Users = Get-ADUser -Filter * -SearchBase "DC=Contoso,DC=local" -Properties proxyAddresses

foreach($User in $Users){
    Write-Host "[*] Processing user $($User.UserPrincipalName)" -ForegroundColor Cyan
    $User.proxyAddresses | ?{ $_ -like '*.local'} | %{
        Set-ADuser -identity $User.samAccountName -remove @{proxyAddresses=$($_)}
        Write-Host "  - Removing $($_)" 
    }
}
Stop-Transcript