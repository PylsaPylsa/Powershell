[int]$samples = 3
[bool]$test = $true

$parent = Get-Process -Id (Get-CimInstance -ClassName Win32_Process -Filter "processid = $pid" | select -ExpandProperty ParentProcessId) -EA SilentlyContinue

[console]::Title = "Process id $pid started at $(Get-Date -Format G)"

## Only display for logon shell or if we can't find the parent
if(!$parent -or $parent.Name -eq 'userinit' -or $test){
	$ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem | Select Name,Domain,@{n='TotalPhysicalMemory';e={[math]::round($_.TotalPhysicalMemory/1GB,2)}}
	$OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem | Select @{n='FreePhysicalMemory';e={[math]::round( $_.FreePhysicalMemory / 1MB,2)}},@{n='FreeSpaceInPagingFiles';e={[math]::round($_.FreeSpaceInPagingFiles/1MB,2)}},LastBootUpTime,InstallDate,LocalDateTime
	$Disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "drivetype = 3" | Select DeviceID,@{n='Size';e={[math]::round($_.size/1GB)}},@{n='Free';e={[math]::round($_.freespace/1GB)}}
    $Processor = Get-CimInstance CIM_Processor | Select-Object Name,NumberofCores
    
    $OSVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName").ProductName

    if($samples){
        [decimal]$CPUUsage = [math]::Round((Get-Counter -Counter '\Processor(*)\% Processor Time' -SampleInterval 1 -MaxSamples $samples | Select -ExpandProperty CounterSamples| Where-Object {$_.InstanceName -eq '_total'} | Select -ExpandProperty CookedValue | Measure-Object -Average).Average,1)
    }

    cls 
    Write-Host "`n`n    Welcome back, $($env:username). It is now $(Get-Date -Format G)." -ForegroundColor Cyan
    Write-Host '    ------------------------------------------------------------------------' -ForegroundColor Cyan
    Write-Host '        '
    Write-Host '                     oooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    Host:        ' -ForegroundColor Cyan -NoNewline; Write-Host "$($env:COMPUTERNAME)" -ForegroundColor White
    Write-Host '           ooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    OS:          ' -ForegroundColor Cyan -NoNewline; Write-Host "$OSVersion" -ForegroundColor White
    Write-Host '        oooooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    Up since:    ' -ForegroundColor Cyan -NoNewline; Write-Host "$($OperatingSystem.LastBootUpTime | Get-Date -Format G)" -ForegroundColor White
    Write-Host '        oooooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '                 ' -ForegroundColor Cyan -NoNewline; Write-Host '' -ForegroundColor White
    Write-Host '        oooooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    Domain:      ' -ForegroundColor Cyan -NoNewline; Write-Host "$($ComputerSystem.Domain)" -ForegroundColor White
    Write-Host '                           ' -ForegroundColor DarkCyan -NoNewline; Write-Host '                 ' -ForegroundColor Cyan -NoNewline; Write-Host '' -ForegroundColor White
    Write-Host '        oooooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    Memory:      ' -ForegroundColor Cyan -NoNewline; Write-Host "$($OperatingSystem.FreePhysicalMemory) GiB / $($ComputerSystem.TotalPhysicalMemory) GiB" -ForegroundColor White
    Write-Host '        oooooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    CPU:         ' -ForegroundColor Cyan -NoNewline; Write-Host "$($Processor.Name) ($($Processor.NumberofCores) cores)" -ForegroundColor White
    Write-Host '        oooooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    CPU Usage:   ' -ForegroundColor Cyan -NoNewline; Write-Host "Avg over $samples seconds: $CPUUsage%" -ForegroundColor White
    Write-Host '           ooooo oooooooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '                 ' -ForegroundColor Cyan -NoNewline; Write-Host '' -ForegroundColor White
    Write-Host '                     oooooo' -ForegroundColor DarkCyan -NoNewline; Write-Host '    Disks:       ' -ForegroundColor Cyan -NoNewline; Write-Host '' -ForegroundColor White

    $Disk | %{ Write-Host "                                  - " -ForegroundColor White -NoNewline; Write-Host "$($_.DeviceID)      " -ForegroundColor Cyan -NoNewline; Write-Host "$($_.Free) GiB / $($_.Size) GiB" -ForegroundColor White }
}

## For safety, let us not sit in system folders
if((Get-Location).Path -match "^$windir"){
	Set-Location $env:userprofile
}