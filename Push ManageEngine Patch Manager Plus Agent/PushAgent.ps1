cls

# ----- Do not modify above -----

$SysvolPath = "\\contoso.local\SYSVOL\contoso.local"

$Organisatie = "Contoso"

# ----- Do not modify below -----

Set-Location -Path $(split-path -parent $MyInvocation.MyCommand.Definition)
Add-Type -AssemblyName PresentationCore,PresentationFramework

$InstallFile = @"
@echo off

$($SysvolPath)\ManageEnginePMA\$($Organisatie)_Agent.exe

if %ERRORLEVEL% EQU 0 (
    echo Installed! :-^)
) else (
    echo Nu-uh, nope...
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
    Output2Con "Installation files not found in SYSVOL, now creating." "Cyan"
    InstallFiles
}else{
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageIcon = [System.Windows.MessageBoxImage]::Question
    $MessageBody = "Use pre-existing installation files in SYSVOL (Yes) or purge and re-install (No)?"
    $MessageTitle = "Confirm"
 
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

    switch($Result){
        "Yes" {Output2Con "Using pre-existing installation files in SYSVOL." "Cyan"; break}
        "No" {Remove-Item -Path "filesystem::$SysvolPath\ManageEnginePMA" -Recurse; Output2Con "Purging pre-existing installation files from SYSVOL." "Cyan"; Output2Con "Creating new installation files in SYSVOL." "Cyan"; InstallFiles; break}
    }
}

Output2Con "Searching for domain-joined active Windows-based servers in Active Directory" "Cyan"

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
$MessageBody = "These hosts appear to be offline and will be skipped:`n$($OfflineServerList.Substring(0,$OfflineServerList.Length-2))`n`nThese hosts are online but will also be skipped:`n$($SkippedServerList.Substring(0,$SkippedServerList.Length-2))`n`nDo you want to push the agent to these hosts?$($OnlineServerList)"
$MessageTitle = "Confirm"
 
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

switch($Result){
    "Yes" {Output2Con "Start pushing agents" "Cyan"; break}
    "No" {Output2Con "Run terminated" "Red"; exit}
}

foreach($Server in $ServersToProcess){
    Output2Con "Pushing agent to $($Server.Name)"
    Invoke-Expression ".\PsExec64.exe \\$($Server.Name) -accepteula -nobanner -s -h '$SysvolPath\ManageEnginePMA\install.bat'" -ErrorAction SilentlyContinue 2> $null
}

$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageIcon = [System.Windows.MessageBoxImage]::Question
$MessageBody = "Do you want to purge the installation files from SYSVOL?"
$MessageTitle = "Confirm"
 
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

switch($Result){
    "Yes" {Remove-Item -Path "filesystem::$SysvolPath\ManageEnginePMA" -Recurse; Output2Con "Purging pre-existing installation files from SYSVOL." "Cyan"; break}
    "No" {break}
}

Output2Con "Run Completed" "Green"