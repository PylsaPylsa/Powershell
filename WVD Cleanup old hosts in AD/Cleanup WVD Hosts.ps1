$DNSServer = "LV5-AZU-DC-01.levvel5.local"
$ZoneName = "levvel5.local"

$PrefixCNAME = "LV5-AZU-WVD-"
$PrefixA = "LV5-AZU-WVD-"
$ComputerOU = "OU=WVD,OU=Computers,OU=Levvel5,DC=levvel5,DC=local"

# Do not edit below

Clear

$ComputerFilter = "Name -like ""$PrefixA*"""
$Iteration = $null
$NewHostsNumber = $null
$Confirm = $null

While($null -eq $Iteration -or $Iteration -notmatch "^\d+$"){
    Write-Host "Which iteration are you deploying? [number]: " -NoNewline -ForegroundColor Yellow
    $Iteration = Read-Host
}

While($null -eq $NewHostsNumber -or $NewHostsNumber -notmatch "^\d+$"){
    Write-Host "How many hosts are you deploying? [number]: " -NoNewline -ForegroundColor Yellow
    $NewHostsNumber = Read-Host
}

Write-Host @"

This operation will remove all CNAME records, A records and Active Directory Computer accounts for all iterations except iteration $iteration. 
You will not be prompted for additional confirmation.

1. Delete all CNAME records where name is like "$($PrefixCNAME)*" from $($ZoneName).
2. Delete all A records where name is like "$($PrefixA)*" but where name is not like "$($PrefixA)$($Iteration)-*" from $($ZoneName).
3. Create $NewHostsNumber new CNAME records as "$($PrefixCNAME)XX" -> "$($PrefixA)$($Iteration)-XX.$($ZoneName)".
4. Delete all Active Directory Computer accounts where name is like "$($PrefixA)*" but where name is not like "$($PrefixA)$($Iteration)-*".

"@ -ForegroundColor Cyan

While($Confirm -cnotlike "YES"){
    Write-Host "Confirm to proceed [Type YES or NO]: " -NoNewline -ForegroundColor Yellow
    $Confirm = Read-Host
    if($Confirm -like "no"){ Write-Host "Script terminated by user request" -ForegroundColor Red; exit }
}

Write-Host "`n[*] Cleaning up CNAME records" -ForegroundColor Green
Get-DnsServerResourceRecord -RRType CNAME -ZoneName $ZoneName -ComputerName $DNSServer | Where {$_.HostName -like "$PrefixCNAME*"} | %{ Write-Host "   [*] Removing obsolete CNAME-record $($_.HostName) -> $($_.RecordData.HostNameAlias)" -ForegroundColor Green; Remove-DnsServerResourceRecord -RRType CNAME -Name $_.HostName -ZoneName $ZoneName -ComputerName $DNSServer -Force }

Write-Host "`n[*] Cleaning up A records" -ForegroundColor Green
Get-DnsServerResourceRecord -RRType A -ZoneName $ZoneName -ComputerName $DNSServer | Where {$_.HostName -like "$PrefixA*" -and $_.HostName -notlike "$PrefixA$Iteration-*"} | %{ Write-Host "   [*] Removing obsolete A-record for $($_.HostName).$ZoneName" -ForegroundColor Green; Remove-DnsServerResourceRecord -RRType A -Name $_.HostName -ZoneName $ZoneName -ComputerName $DNSServer -Force }

Write-Host "`n[*] Creating new CNAME records" -ForegroundColor Green
For($i=0; $i -lt $NewHostsNumber; $i++){
    Write-Host "   [*] Adding new CNAME-record for $PrefixCNAME$("{0:00}" -f $i) -> $PrefixA$Iteration-$i.$ZoneName" -ForegroundColor Green
    Add-DnsServerResourceRecordCName -Name "$PrefixCNAME$("{0:00}" -f $i)" -HostNameAlias "$PrefixA$Iteration-$i.$ZoneName" -ZoneName $ZoneName -ComputerName $DNSServer
}

Write-Host "`n[*] Cleaning up computer accounts" -ForegroundColor Green
Get-ADComputer -Filter $ComputerFilter -SearchBase $ComputerOU | Where {$_.Name -notlike "$PrefixA$Iteration-*"} | %{ Write-Host "   [*] Removing obsolete computer account $($_.Name)" -ForegroundColor Green; Remove-ADObject -Identity $_ -Recursive -Confirm:$False }

Write-Host "`nScript terminated at end of script. [Press Enter to exit]" -ForegroundColor Cyan
Read-Host