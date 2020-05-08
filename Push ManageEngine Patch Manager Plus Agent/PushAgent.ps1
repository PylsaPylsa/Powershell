cls

# ----- Hierboven niets aanpassen -----

# De waarde van $Sysvolpath moet de SYSVOL van het domein zijn. Bijvoorbeeld: \\contoso.local\SYSVOL\contoso.local
$SysvolPath = "\\oosterpoort.local\SYSVOL\oosterpoort.local"

#De waarde van $Organisatie is het eerste deel van de titel van de installer (Voor Contoso_Agent.exe dus "Contoso").
$Organisatie = "Oosterpoort"

# ----- Hieronder niets aanpassen -----

Set-Location -Path $(split-path -parent $MyInvocation.MyCommand.Definition)
Add-Type -AssemblyName PresentationCore,PresentationFramework

$InstallFile = @"
@echo off

$($SysvolPath)\ManageEnginePMA\$($Organisatie)_Agent.exe

if %ERRORLEVEL% EQU 0 (
    echo Installed! :-^)
) else (
    echo Nu-uh, helaas...
    echo Failure Reason Given is %errorlevel%
)
"@

Function Output2Con([string]$Message, [string]$Colour = "Green"){
    Write-Host "[*] $($Message)" -ForegroundColor $Colour
}

Function InstallFiles(){
    Copy-Item ".\ManageEnginePMA" -Destination "filesystem::$($SysvolPath)\ManageEnginePMA" -Recurse
    $InstallFile | Out-File -FilePath "filesystem::$($SysvolPath)\ManageEnginePMA\install.bat" -NoClobber -Encoding ASCII 
}



if($(Test-Path -Path "filesystem::$SysvolPath\ManageEnginePMA") -eq $False){
    Output2Con "Installatiebestanden niet gevonden in SYSVOL, worden aangemaakt." "Cyan"
    InstallFiles
}else{
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageIcon = [System.Windows.MessageBoxImage]::Question
    $MessageBody = "Installatiebestanden uit SYSVOL gebruiken (Yes) of opschonen en opnieuw plaatsen (No)?"
    $MessageTitle = "Bevestig actie"
 
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

    switch($Result){
        "Yes" {Output2Con "Installatiebestanden reeds gevonden in SYSVOL, we gaan door met de bestaande bestanden." "Cyan"; break}
        "No" {Remove-Item -Path "filesystem::$SysvolPath\ManageEnginePMA" -Recurse; Output2Con "Installatiebestanden opgeschoond uit SYSVOL." "Cyan"; Output2Con "Installatiebestanden aangemaakt in SYSVOL." "Cyan"; InstallFiles; break}
    }
}

Output2Con "Zoeken naar actieve servers in Active Directory" "Cyan"

$Servers = Get-ADComputer -Filter 'operatingsystem -like "*server*" -and enabled -eq "true"' `
-Properties Name,Operatingsystem,OperatingSystemVersion,IPv4Address |
Sort-Object -Property Name |
Select-Object -Property Name,Operatingsystem,OperatingSystemVersion,IPv4Address

$OnlineServerList = ""
$SkippedServerList = ""
$OfflineServerList = ""
$ServersToProcess = @()

foreach($Server in $Servers){
    if($Server.Name -like "*xa*"){
        $SkippedServerList = $SkippedServerList + "$($Server.Name), "
    }elseif(Test-Connection -ComputerName $Server.Name -Count 1 -Quiet){
        $OnlineServerList = $OnlineServerList + "`n  - $($Server.Name)"
        $ServersToProcess += $Server
    }else{
        $OfflineServerList = $OfflineServerList + "$($Server.Name), "
    }
}

if($SkippedServerList -eq ""){ $SkippedServerList = "Geen.." }
if($OfflineServerList -eq ""){ $OfflineServerList = "Geen.." }

$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageIcon = [System.Windows.MessageBoxImage]::Question
$MessageBody = "Onderstaande agents zijn offline en worden overgeslagen:`n$($OfflineServerList.Substring(0,$OfflineServerList.Length-2))`n`nOnderstaande agents zijn online maar worden overgeslagen:`n$($SkippedServerList.Substring(0,$SkippedServerList.Length-2))`n`nAgent pushen naar onderstaande hosts?$($OnlineServerList)"
$MessageTitle = "Bevestig actie"
 
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

switch($Result){
    "Yes" {Output2Con "Start met pushen van Agents" "Cyan"; break}
    "No" {Output2Con "Script afgebroken" "Red"; exit}
}

foreach($Server in $ServersToProcess){
    Output2Con "Agent wordt gepusht naar $($Server.Name)"
    Invoke-Expression ".\PsExec64.exe \\$($Server.Name) -accepteula -nobanner -s -h '$SysvolPath\ManageEnginePMA\install.bat'" -ErrorAction SilentlyContinue 2> $null
}

$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageIcon = [System.Windows.MessageBoxImage]::Question
$MessageBody = "Installatiebestanden uit SYSVOL opschonen?"
$MessageTitle = "Bevestig actie"
 
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

switch($Result){
    "Yes" {Remove-Item -Path "filesystem::$SysvolPath\ManageEnginePMA" -Recurse; Output2Con "Installatiebestanden opgeschoond uit SYSVOL." "Cyan"; Output2Con "Installatiescript voltooid." "Green"; exit}
    "No" {Output2Con "Installatiescript voltooid." "Green"; exit}
}