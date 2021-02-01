Add-PSSnapin citrix*

$DeliveryController = "AAA-BBB-DDC-01.contoso.local"

$retXml = ""
$retXml += "<prtg>`n"

$Machines = Get-BrokerMachine -AdminAddress $DeliveryController
$DeliveryGroups = Get-BrokerDesktopGroup -AdminAddress $DeliveryController

foreach($DeliveryGroup in $DeliveryGroups){

    $MachinesInMaintenance = $Machines | Where-Object {$_.InMaintenanceMode -eq $True -and $_.PowerState -ne "Off" -and $_.DesktopGroupName -eq $DeliveryGroup.Name}
    $MachinesPoweredOff = $Machines | Where-Object {$_.PowerState -eq "Off" -and $_.DesktopGroupName -eq $DeliveryGroup.Name}
    $MachinesPowerUnknown = $Machines | Where-Object {$_.PowerState -eq "Unknown" -and $_.DesktopGroupName -eq $DeliveryGroup.Name}
    $MachinesUnregistered = $Machines | Where-Object {$_.RegistrationState -eq "Unregistered" -eq $True -and $_.PowerState -ne "Unknown" -and $_.DesktopGroupName -eq $DeliveryGroup.Name}


    $retXml += "  <result>`n"
    $retXml += "    <channel>[$($DeliveryGroup.Name)] Machines in maintenance</channel>`n"
    $retXml += "    <value>$($MachinesInMaintenance.Count)</value>`n"
    $retXml += "  </result>`n"

    $retXml += "  <result>`n"
    $retXml += "    <channel>[$($DeliveryGroup.Name)] Machines powered off</channel>`n"
    $retXml += "    <value>$($MachinesPoweredOff.Count)</value>`n"
    $retXml += "  </result>`n"

    $retXml += "  <result>`n"
    $retXml += "    <channel>[$($DeliveryGroup.Name)] Machines unregistered</channel>`n"
    $retXml += "    <value>$($MachinesUnregistered.Count)</value>`n"
    $retXml += "  </result>`n"

    $retXml += "  <result>`n"
    $retXml += "    <channel>[$($DeliveryGroup.Name)] Machines with unknown power status</channel>`n"
    $retXml += "    <value>$($MachinesPowerUnknown.Count)</value>`n"
    $retXml += "  </result>`n"

}

$retXml += "</prtg>"

write-host $retXml
exit 0