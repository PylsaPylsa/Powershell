$OverlayType = "disk"                   # Overlay type, value disk or ram
$OverlaySize = 5120                     # Max size of overlay, value in MiB
$OverlayPassThrough = "on"              # Free space pass-through for disk type, value on or off
$OverlayWarning = $OverlaySize - 1024   # Overlay fill at warning stage, value in MiB.
$OverlayCritical = $OverlaySize         # Overlay fill at critical stage, value in MiB.


# ----
cls

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if($False -eq $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    Write-Host "[!] Not running in elevated PowerShell environment. Please run as Administrator and try again." -BackgroundColor Red
}else{

    $WindowsEdition = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID").EditionID
    if($WindowsEdition -ne "Enterprise"){
        Write-Host "[!] This is not Windows 10 Enterprise. This edition is not compatible with UWF." -BackgroundColor Red
    }else{
        Write-Host "[!] This is Windows 10 $WindowsEdition. Ready to set up UWF." -ForegroundColor Green

        $UWFOptionalFeature = Get-WindowsOptionalFeature -Online -FeatureName "Client-UnifiedWriteFilter"
        if($UWFOptionalFeature.State -ne "Enabled"){
            Write-Host "[*] UWF has not yet been installed on this system. Installing now." -ForegroundColor Green
            Enable-WindowsOptionalFeature -Online -FeatureName "Client-UnifiedWriteFilter" -All | Out-Null
            Write-Host "[!] UWF has been installed on this system. Proceeding to set up UWF." -ForegroundColor Green
        }else{
            Write-Host "[!] UWF has already been installed on this system. Proceeding to set up UWF." -ForegroundColor Green
        }

        Write-Host "`n[*] Setting up Exclusions" -ForegroundColor Green

        Write-Host "    [*] Windows Defender" -ForegroundColor Green
        uwfmgr.exe file add-exclusion "C:\Program Files\Windows Defender" | Out-Null
        uwfmgr.exe file add-exclusion "C:\ProgramData\Microsoft\Windows Defender" | Out-Null
        uwfmgr.exe file add-exclusion "C:\Windows\WindowsUpdate.log" | Out-Null
        uwfmgr.exe file add-exclusion "C:\Windows\Temp\MpCmdRun.log" | Out-Null
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender" | Out-Null

        Write-Host "    [*] Client GPO" -ForegroundColor Green
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Wireless\GPTWirelessPolicy" | Out-Null
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WiredL2\GP_Policy" | Out-Null

        Write-Host "    [*] GPO policy files" -ForegroundColor Green
        uwfmgr.exe file add-exclusion "C:\Windows\wlansvc\Policies" | Out-Null
        uwfmgr.exe file add-exclusion "C:\Windows\dot2svc\Policies" | Out-Null

        Write-Host "    [*] Time settings" -ForegroundColor Green
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones" | Out-Null
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" | Out-Null

        Write-Host "    [*] Network interface profiles" -ForegroundColor Green
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\wlansvc" | Out-Null
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\dot3svc" | Out-Null

        Write-Host "    [*] Services" -ForegroundColor Green
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Wlansvc" | Out-Null
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\WwanSvc" | Out-Null
        uwfmgr.exe registry add-exclusion "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\dot3svc" | Out-Null


        Write-Host "`n[*] Configuring overlay" -ForegroundColor Green

        Write-Host "    [*] Overlay type is " -ForegroundColor Green -NoNewline
        Write-Host "$OverlayType" -ForegroundColor Yellow
        uwfmgr.exe overlay set-type $OverlayType | Out-Null

        Write-Host "    [*] Overlay size is " -ForegroundColor Green -NoNewline
        Write-Host "$OverlaySize" -ForegroundColor Yellow
        uwfmgr.exe overlay set-size $OverlaySize | Out-Null

        if($OverlayPassThrough -ne "disk"){
            Write-Host "    [*] Free space pass-through set to " -ForegroundColor Green -NoNewline
            Write-Host "$OverlayPassThrough" -ForegroundColor Yellow
            uwfmgr.exe overlay set-passthrough $OverlayPassThrough | Out-Null
        }else{
            Write-Host "    [*] Using ram type overlay. Ignoring free space pass-through setting." -ForegroundColor Green
        }

        Write-Host "    [*] Warning threshold is " -ForegroundColor Green -NoNewline
        Write-Host "$OverlayWarning" -ForegroundColor Yellow
        uwfmgr.exe overlay set-warningthreshold $OverlayWarning | Out-Null

        Write-Host "    [*] Critical threshold is " -ForegroundColor Green -NoNewline
        Write-Host "$OverlayCritical" -ForegroundColor Yellow
        uwfmgr.exe overlay set-criticalthreshold $OverlayCritical | Out-Null


        Write-Host "`n[*] Disabling hibernation" -ForegroundColor Green
        powercfg.exe /h off | Out-Null

        Write-Host "`n[*] Enabling UWF filter" -ForegroundColor Green
        uwfmgr.exe filter enable | Out-Null

        Write-Host "`n[*] Protecting volume C:" -ForegroundColor Green
        uwfmgr.exe volume protect c: | Out-Null

        Write-Host "`n[!] UWF set up complete. Please reboot machine to enable protection." -BackgroundColor Red
    }
}