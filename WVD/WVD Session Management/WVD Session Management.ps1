Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName PresentationFramework | Out-Null
Add-Type -AssemblyName System.Drawing | Out-Null
Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null

While($Null -eq $Tenant){
    $Tenant = [Microsoft.VisualBasic.Interaction]::InputBox("Enter RDS Tenant Name", "Tenant Selection")
}

if(!(Get-Module "Microsoft.RDInfra.RDPowerShell")) {
    Install-Module -Name Microsoft.RDInfra.RDPowerShell | Out-Null
}

if(!(Get-module Microsoft.RDInfra.RDPowerShell)){
    Import-Module -Name Microsoft.RDInfra.RDPowerShell | Out-Null
}

if($null -eq $RdsAccount){
    $RdsAccount = Add-RdsAccount -DeploymentUrl https://rdbroker.wvd.microsoft.com
}

$strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
$objTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)

function Update-AppStatus($text){
    $lbAppStatus.Text = $text
    $lbAppStatus.Refresh()
}

function Fill-SessionHosts($HostPool)
{
    $dgvHosts.Rows.Clear()
    $UserSessions = Get-RdsUserSession -TenantName $Tenant -HostPoolName $HostPool 
    $SessionHosts = Get-RdsSessionHost -TenantName $Tenant -HostPoolName $HostPool
    $HostpoolProperties = Get-RdsHostpool -TenantName $Tenant -HostPoolName $HostPool
    if($HostpoolProperties.MaxSessionLimit -ne 999999){
        $MaxSessionLimit = " / $($HostpoolProperties.MaxSessionLimit)"
    }
    $SessionHosts | foreach{
        $SessionHostInternalIP = $(Resolve-DnsName -Name $_.SessionHostName -Type A)[0].IPAddress
        if($Null -eq $SessionHostInternalIP){
            $SessionHostInternalIP = "N/A"
            $SessionHostInternalPingable = "False"
        }else{
            if(Test-Connection -ComputerName $SessionHostInternalIP -Count 1 -Quiet){
                $SessionHostInternalPingable = "True"
            }else{
                $SessionHostInternalPingable = "False"
            }
        }
        $SessionHostName = $_.SessionHostName
        $rowIndex = $dgvHosts.Rows.Add($SessionHostName,$SessionHostInternalIP,[System.TimeZoneInfo]::ConvertTimeFromUtc($_.LastHeartBeat, $objTimeZone),$SessionHostInternalPingable,$_.Status,$_.AllowNewSession,"$($($UserSessions | Where-Object {$_.SessionHostName -eq $SessionHostName}).Count)$MaxSessionLimit")

        if(-not $_.AllowNewSession){
            $dgvHosts.Rows[$rowIndex].Cells[5].Style.ForeColor=[System.Drawing.Color]::FromArgb(255,204,0,0)
        }

        if($_.Status -ne "Available"){
            $dgvHosts.Rows[$rowIndex].Cells[4].Style.ForeColor=[System.Drawing.Color]::FromArgb(255,204,0,0)
        }

        if($SessionHostInternalPingable -ne "True"){
            $dgvHosts.Rows[$rowIndex].Cells[3].Style.ForeColor=[System.Drawing.Color]::FromArgb(255,255,128,0)
        }

        if($rowIndex -eq 0){
            if($_.AllowNewSession -eq "True"){
                $btDrainOn.Enabled = $true
                $btDrainOff.Enabled = $false
            }else{
                $btDrainOn.Enabled = $false
                $btDrainOff.Enabled = $true
            }
        }
    }

    $HostTotal = $SessionHosts.Count
    $lbHostCount.Text = "Host count: $HostTotal (In drain: $($($SessionHosts | Where-Object {$_.AllowNewSession -ne "True"}).Count))"
    $lbHostCount.Refresh()

    return $SessionHosts
}

function Fill-Sessions($HostPool)
{
    $dgvSessions.Rows.Clear()
    $UserSessions = Get-RdsUserSession -TenantName $Tenant -HostPoolName $HostPool 
    $UserSessions | foreach{
        $dgvSessions.Rows.Add($_.AdUserName,$_.SessionId,$_.HostPoolName,$_.SessionHostName,[System.TimeZoneInfo]::ConvertTimeFromUtc($_.CreateTime, $objTimeZone),$_.SessionState) | Out-Null
    }

    $SessionTotal = $UserSessions.Count
    $lbSessionCount.Text = "Session count: $SessionTotal (Inactive: $($($UserSessions | Where-Object {$_.SessionState -ne "Active"}).Count))"
    $lbSessionCount.Refresh()

    return $UserSessions
}

function Fill-HostPoolProperties($Hostpool){
    $HostpoolProperties = Get-RdsHostpool -TenantName $Tenant -HostPoolName $HostPool
    
    $dgvHostPoolProperties.Rows.Clear()
    $dgvHostPoolProperties.Rows.Add("Tenant Name",$HostpoolProperties.TenantName) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Tenant Group Name",$HostpoolProperties.TenantGroupName) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Host Pool Name",$HostpoolProperties.HostPoolName) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Friendly Name",$HostpoolProperties.FriendlyName) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Description",$HostpoolProperties.Description) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Max Session Limit",$HostpoolProperties.MaxSessionLimit) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Load Balancing Mode",$HostpoolProperties.LoadBalancerType) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Development/Validation Environment",$HostpoolProperties.ValidationEnv) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Persistent",$HostpoolProperties.Persistent) | Out-Null
    $dgvHostPoolProperties.Rows.Add("Assignment Type",$HostpoolProperties.AssignmentType) | Out-Null
}

$Main = New-Object System.Windows.Forms.Form

$components = New-Object System.ComponentModel.Container
$dgvSessions = New-Object System.Windows.Forms.DataGridView
$tvPools = New-Object System.Windows.Forms.TreeView
$btShadow = New-Object System.Windows.Forms.Button
$btLogoff = New-Object System.Windows.Forms.Button
$btSendMessage = New-Object System.Windows.Forms.Button
$lbSessionCount = New-Object System.Windows.Forms.Label
$btRefreshSessions = New-Object System.Windows.Forms.Button
$tabControl = New-Object System.Windows.Forms.TabControl
$tabSessions = New-Object System.Windows.Forms.TabPage
$btExportCSVSessions = New-Object System.Windows.Forms.Button
$tabHosts = New-Object System.Windows.Forms.TabPage
$btExportCSVHosts = New-Object System.Windows.Forms.Button
$btDirectRDP = New-Object System.Windows.Forms.Button
$btRestartHost = New-Object System.Windows.Forms.Button
$lbHostCount = New-Object System.Windows.Forms.Label
$btRefreshHosts = New-Object System.Windows.Forms.Button
$btDrainOff = New-Object System.Windows.Forms.Button
$btDrainOn = New-Object System.Windows.Forms.Button
$dgvHosts = New-Object System.Windows.Forms.DataGridView
$tabHostpool = New-Object System.Windows.Forms.TabPage
$dgvHostPoolProperties = New-Object System.Windows.Forms.DataGridView
$tabAbout = New-Object System.Windows.Forms.TabPage
$lbAbout = New-Object System.Windows.Forms.Label
$lbAppStatus = New-Object System.Windows.Forms.Label
$btOpenShare = New-Object System.Windows.Forms.Button
$cmsOpenShare = New-Object System.Windows.Forms.ContextMenuStrip($components)
$tsmiOpenShareC = New-Object System.Windows.Forms.ToolStripMenuItem
$tsmiOpenShareCUsers = New-Object System.Windows.Forms.ToolStripMenuItem
$tsmiOpenFSLogixLogs = New-Object System.Windows.Forms.ToolStripMenuItem

#
# dgvSessions
#
$dgvSessions.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$dgvSessions.Location = New-Object System.Drawing.Point(6, 6)
$dgvSessions.Name = "dgvSessions"
$dgvSessions.Size = New-Object System.Drawing.Size(1030, 608)
$dgvSessions.TabIndex = 0
$dgvSessions.RowHeadersVisible = $false
$dgvSessions.AutoSizeColumnsMode = 'Fill'
$dgvSessions.AllowUserToResizeRows = $false
$dgvSessions.selectionmode = 'FullRowSelect'
$dgvSessions.MultiSelect = $false
$dgvSessions.AllowUserToAddRows = $false
$dgvSessions.ReadOnly = $true

$dgvSessions.ColumnCount = 6
$dgvSessions.ColumnHeadersVisible = $true
$dgvSessions.Columns[0].Name = "Username"
$dgvSessions.Columns[1].Name = "Session ID"
$dgvSessions.Columns[2].Name = "Hostpool"
$dgvSessions.Columns[3].Name = "Session host"
$dgvSessions.Columns[4].Name = "Logon time"
$dgvSessions.Columns[5].Name = "Status"

#
# dgvHosts
#
$dgvHosts.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$dgvHosts.Location = New-Object System.Drawing.Point(6, 6)
$dgvHosts.Name = "dgvHosts"
$dgvHosts.Size = New-Object System.Drawing.Size(1030, 608)
$dgvHosts.TabIndex = 0
$dgvHosts.RowHeadersVisible = $false
$dgvHosts.AutoSizeColumnsMode = 'Fill'
$dgvHosts.AllowUserToResizeRows = $false
$dgvHosts.selectionmode = 'FullRowSelect'
$dgvHosts.MultiSelect = $false
$dgvHosts.AllowUserToAddRows = $false
$dgvHosts.ReadOnly = $true

$dgvHosts.ColumnCount = 7
$dgvHosts.ColumnHeadersVisible = $true
$dgvHosts.Columns[0].Name = "Hostname"
$dgvHosts.Columns[1].Name = "Internal IP"
$dgvHosts.Columns[2].Name = "Last heartbeat"
$dgvHosts.Columns[3].Name = "Pingable internal"
$dgvHosts.Columns[4].Name = "Status"
$dgvHosts.Columns[5].Name = "Allow new sessions"
$dgvHosts.Columns[6].Name = "Session count"

$dgvHosts.Add_CellMouseClick({
    if($dgvHosts.SelectedRows[0].Cells[5].Value -eq "True"){
        $btDrainOn.Enabled = $true
        $btDrainOff.Enabled = $false
    }else{
        $btDrainOn.Enabled = $false
        $btDrainOff.Enabled = $true
    }
})

#
# dgvHostPoolProperties
#
$dgvHostPoolProperties.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$dgvHostPoolProperties.Location = New-Object System.Drawing.Point(6, 6)
$dgvHostPoolProperties.Name = "dgvHostPoolProperties"
$dgvHostPoolProperties.Size = New-Object System.Drawing.Size(515, 637)
$dgvHostPoolProperties.TabIndex = 0
$dgvHostPoolProperties.RowHeadersVisible = $false
$dgvHostPoolProperties.AutoSizeColumnsMode = 'Fill'
$dgvHostPoolProperties.AllowUserToResizeRows = $false
$dgvHostPoolProperties.selectionmode = 'FullRowSelect'
$dgvHostPoolProperties.MultiSelect = $false
$dgvHostPoolProperties.AllowUserToAddRows = $false
$dgvHostPoolProperties.ReadOnly = $true

$dgvHostPoolProperties.ColumnCount = 2
$dgvHostPoolProperties.ColumnHeadersVisible = $true
$dgvHostPoolProperties.Columns[0].Name = "Property"
$dgvHostPoolProperties.Columns[1].Name = "Value"

#
# tvPools
#
$tvPools.Location = New-Object System.Drawing.Point(12, 12)
$tvPools.Name = "tvPools"
$tvPools.Size = New-Object System.Drawing.Size(234, 636)
$tvPools.TabIndex = 1

$TenantNode = $tvPools.Nodes.Add($Tenant)

$Hostpools = Get-RdsHostpool -TenantName $Tenant | foreach{
    $newNode = New-Object System.Windows.Forms.TreeNode             
    $newNode.Name = $_.HostPoolName
    $newNode.Text = $_.HostPoolName
    $newNode.Tag = $Tenant
    $TenantNode.Nodes.Add($newNode)
}
$tvPools.ExpandAll();

$tvPools.add_AfterSelect({
    if($this.SelectedNode.Text -ne $Tenant){
        Update-AppStatus("Fetching sessions from $($this.SelectedNode.Text)")
        $global:UserSessionsRet = Fill-Sessions($this.SelectedNode.Text)
        $btRefreshSessions.Enabled = $true
        $btShadow.Enabled = $true
        $btLogoff.Enabled = $true
        $btSendMessage.Enabled = $true
        $btExportCSVSessions.Enabled = $true

        Update-AppStatus("Fetching hosts from $($this.SelectedNode.Text)")
        $global:SessionHostsRet = Fill-SessionHosts($this.SelectedNode.Text)
        $btRefreshHosts.Enabled = $true
        $btExportCSVHosts.Enabled = $true
        $btDirectRDP.Enabled = $true
        $btRestartHost.Enabled = $true
        $btOpenshare.Enabled = $true


        Update-AppStatus("Fetching host pool properties from $($this.SelectedNode.Text)")
        Fill-HostPoolProperties($this.SelectedNode.Text)

        Update-AppStatus("Connected to $($this.SelectedNode.Text)")
    }
})

#
# btShadow
#
$btShadow.Location = New-Object System.Drawing.Point(961, 620)
$btShadow.Name = "btShadow"
$btShadow.Size = New-Object System.Drawing.Size(75, 23)
$btShadow.TabIndex = 2
$btShadow.Text = "Shadow"
$btShadow.UseVisualStyleBackColor = $true
$btShadow.Enabled = $false

$btShadow.Add_Click({
    $ShadowSessionID = $dgvSessions.SelectedRows[0].Cells[1].Value
    $ShadowSessionHost = $dgvSessions.SelectedRows[0].Cells[3].Value
    $ShadowSessionHostIP = $(Resolve-DnsName -Name $ShadowSessionHost -Type A)[0].IPAddress
    Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/shadow:$ShadowSessionID /v:$ShadowSessionHostIP /control"
})

#
# btLogoff
#
$btLogoff.Location = New-Object System.Drawing.Point(879, 620)
$btLogoff.Name = "btLogoff"
$btLogoff.Size = New-Object System.Drawing.Size(75, 23)
$btLogoff.TabIndex = 3
$btLogoff.Text = "Log off"
$btLogoff.UseVisualStyleBackColor = $true
$btLogoff.Enabled = $false

$btLogoff.Add_Click({
    $LogoffSessionID = $dgvSessions.SelectedRows[0].Cells[1].Value
    $LogoffSessionUser = $dgvSessions.SelectedRows[0].Cells[0].Value
    $LogoffSessionHost = $dgvSessions.SelectedRows[0].Cells[3].Value
    $Confirm = [System.Windows.MessageBox]::Show("Log off $($LogoffSessionUser)?",'Log off','YesNo','Warning')
    if($Confirm -eq "Yes"){
        Update-AppStatus("Logging off $LogoffSessionUser")
        Invoke-RdsUserSessionLogoff -TenantName $Tenant -HostPoolName $tvPools.SelectedNode.Text -SessionHostName $LogoffSessionHost -SessionId $LogoffSessionID -NoUserPrompt
        #Start-Process "$env:windir\system32\logoff.exe" -ArgumentList "$LogoffSessionID /server:$LogoffSessionHost"

        Start-Sleep -Seconds 1.5

        Update-AppStatus("Fetching sessions from $($tvPools.SelectedNode.Text)")
        $global:UserSessionsRet = Fill-Sessions($tvPools.SelectedNode.Text)

        Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
    }
})

#
# btSendMessage
#
$btSendMessage.Location = New-Object System.Drawing.Point(762, 620)
$btSendMessage.Name = "btSendMessage"
$btSendMessage.Size = New-Object System.Drawing.Size(111, 23)
$btSendMessage.TabIndex = 4
$btSendMessage.Text = "Send message"
$btSendMessage.UseVisualStyleBackColor = $true
$btSendMessage.Enabled = $false

$btSendMessage.Add_Click({
    $SendMessageSessionID = $dgvSessions.SelectedRows[0].Cells[1].Value
    $SendMessageHost = $dgvSessions.SelectedRows[0].Cells[3].Value
    $SendMessageUser = $dgvSessions.SelectedRows[0].Cells[0].Value

    $MessageTitle = [Microsoft.VisualBasic.Interaction]::InputBox("Enter message title", "Send Message")
    $MessageBody = [Microsoft.VisualBasic.Interaction]::InputBox("Enter message body", "Send Message")
    $Confirm = [System.Windows.MessageBox]::Show("Send message below to $($SendMessageUser)?`n`n`n---- $MessageTitle ----`n`n$MessageBody",'Confirm message','YesNo','Information')
    if($Confirm -eq "Yes"){
        Update-AppStatus("Sending message to $SendMessageUser")
        Send-RdsUserSessionMessage -TenantName $Tenant -HostPoolName $tvPools.SelectedNode.Text -SessionHostName $SendMessageHost -SessionId $SendMessageSessionID -MessageTitle $MessageTitle -MessageBody $MessageBody
        Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
    }
})

#
# btRestartHost
#
$btRestartHost.Location = New-Object System.Drawing.Point(734, 620)
$btRestartHost.Name = "btRestartHost"
$btRestartHost.Size = New-Object System.Drawing.Size(93, 23)
$btRestartHost.TabIndex = 9
$btRestartHost.Text = "Restart host"
$btRestartHost.UseVisualStyleBackColor = $true
$btRestartHost.Enabled = $false

$btRestartHost.Add_Click({

    $RestartHost = $dgvHosts.SelectedRows[0].Cells[0].Value
    $RestartHostSessions = $dgvHosts.SelectedRows[0].Cells[6].Value
    $Confirm = [System.Windows.MessageBox]::Show("Restart $($RestartHost)? There are currently $RestartHostSessions users logged onto this host.",'Log off','YesNo','Warning')
    if($Confirm -eq "Yes"){
        Update-AppStatus("Restarting $RestartHost")
        
        Restart-Computer -ComputerName $RestartHost -Force

        Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
    }
})

#
# btDirectRDP
#
$btDirectRDP.Location = New-Object System.Drawing.Point(641, 620)
$btDirectRDP.Name = "btDirectRDP"
$btDirectRDP.Size = New-Object System.Drawing.Size(87, 23)
$btDirectRDP.TabIndex = 10
$btDirectRDP.Text = "Direct RDP"
$btDirectRDP.UseVisualStyleBackColor = $true
$btDirectRDP.Enabled = $false

$btDirectRDP.Add_Click({
    $DirectRDPHost = $dgvHosts.SelectedRows[0].Cells[0].Value
    Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$DirectRDPHost /admin"
})

#
# btExportCSVHosts
#
$btExportCSVHosts.Location = New-Object System.Drawing.Point(535, 620)
$btExportCSVHosts.Name = "btExportCSVHosts"
$btExportCSVHosts.Size = New-Object System.Drawing.Size(100, 23)
$btExportCSVHosts.TabIndex = 11
$btExportCSVHosts.Text = "Export to CSV"
$btExportCSVHosts.UseVisualStyleBackColor = $true
$btExportCSVHosts.Enabled = $false

$btExportCSVHosts.Add_Click({
    $saveAs = New-Object System.Windows.Forms.SaveFileDialog
    $saveAs.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"

    if($saveAs.ShowDialog() -eq 'Ok'){
        $global:SessionHostsRet | Export-Csv -Path $($saveAs.filename) -NoTypeInformation
    }
})

#
# btExportCSVSessions
#
$btExportCSVSessions.Location = New-Object System.Drawing.Point(656, 620)
$btExportCSVSessions.Name = "btExportCSVSessions"
$btExportCSVSessions.Size = New-Object System.Drawing.Size(100, 23)
$btExportCSVSessions.TabIndex = 8
$btExportCSVSessions.Text = "Export to CSV"
$btExportCSVSessions.UseVisualStyleBackColor = $true
$btExportCSVSessions.Enabled = $false

$btExportCSVSessions.Add_Click({
    $saveAs = New-Object System.Windows.Forms.SaveFileDialog
    $saveAs.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"

    if($saveAs.ShowDialog() -eq 'Ok'){
        $global:UserSessionsRet | Export-Csv -Path $($saveAs.filename) -NoTypeInformation
    }
})

#
# btRefreshSessions
#
$btRefreshSessions.Location = New-Object System.Drawing.Point(575, 620)
$btRefreshSessions.Name = "btRefreshSessions"
$btRefreshSessions.Size = New-Object System.Drawing.Size(75, 23)
$btRefreshSessions.TabIndex = 7
$btRefreshSessions.Text = "Refresh"
$btRefreshSessions.UseVisualStyleBackColor = $true
$btRefreshSessions.Enabled = $false

$btRefreshSessions.Add_Click({
   Update-AppStatus("Fetching sessions from $($tvPools.SelectedNode.Text)")
   $global:UserSessionsRet = Fill-Sessions($tvPools.SelectedNode.Text)
   $SessionTotal = $global:UserSessionsRet.Count
   $lbSessionCount.Text = "Session count: $SessionTotal (Active: $($($global:UserSessionsRet | Where-Object {$_.SessionState -eq "Active"}).Count))"
   $lbSessionCount.Refresh()

   Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
})

#
# btDrainOn
#
$btDrainOn.Location = New-Object System.Drawing.Point(948, 620)
$btDrainOn.Name = "btDrainOn"
$btDrainOn.Size = New-Object System.Drawing.Size(88, 23)
$btDrainOn.TabIndex = 1
$btDrainOn.Text = "Put in drain"
$btDrainOn.UseVisualStyleBackColor = $true
$btDrainOn.Enabled = $false

$btDrainOn.Add_Click({
   $SessionHostDrainOn = $dgvHosts.SelectedRows[0].Cells[0].Value
   Update-AppStatus("Putting $SessionHostDrainOn in drain")
   Set-RdsSessionHost -TenantName $Tenant -HostPoolName $tvPools.SelectedNode.Text -Name $SessionHostDrainOn -AllowNewSession $False

   Update-AppStatus("Fetching hosts from $($tvPools.SelectedNode.Text)")
   Fill-SessionHosts($tvPools.SelectedNode.Text)

   Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
})

#
# btDrainOff
#
$btDrainOff.Location = New-Object System.Drawing.Point(833, 620)
$btDrainOff.Name = "btDrainOff"
$btDrainOff.Size = New-Object System.Drawing.Size(109, 23)
$btDrainOff.TabIndex = 2
$btDrainOff.Text = "Take out of drain"
$btDrainOff.UseVisualStyleBackColor = $true
$btDrainOff.Enabled = $false

$btDrainOff.Add_Click({
   $SessionHostDrainOff = $dgvHosts.SelectedRows[0].Cells[0].Value
   Update-AppStatus("Taking $SessionHostDrainOff out of drain")
   Set-RdsSessionHost -TenantName $Tenant -HostPoolName $tvPools.SelectedNode.Text -Name $SessionHostDrainOff -AllowNewSession $True

   Update-AppStatus("Fetching hosts from $($tvPools.SelectedNode.Text)")
   Fill-SessionHosts($tvPools.SelectedNode.Text)

   Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
})

#
# btRefreshHosts
#
$btRefreshHosts.Location = New-Object System.Drawing.Point(360, 620)
$btRefreshHosts.Name = "btRefreshHosts"
$btRefreshHosts.Size = New-Object System.Drawing.Size(75, 23)
$btRefreshHosts.TabIndex = 3
$btRefreshHosts.Text = "Refresh"
$btRefreshHosts.UseVisualStyleBackColor = $true
$btRefreshHosts.Enabled = $false

$btRefreshHosts.Add_Click({
   Update-AppStatus("Fetching hosts from $($tvPools.SelectedNode.Text)")
   $global:SessionHostsRet = Fill-SessionHosts($tvPools.SelectedNode.Text)
   Update-AppStatus("Connected to $($tvPools.SelectedNode.Text)")
})

#
# btOpenShare
#
$btOpenShare.Location = New-Object System.Drawing.Point(441, 620)
$btOpenShare.Name = "btOpenShare"
$btOpenShare.Size = New-Object System.Drawing.Size(88, 23)
$btOpenShare.TabIndex = 12
$btOpenShare.Text = "Open share"
$btOpenShare.UseVisualStyleBackColor = $true
$btOpenshare.Enabled = $false


$btOpenShare.Add_Click({
    $cmsOpenShare.Show($btOpenShare, $(New-Object System.Drawing.Point(0, -50)))
})

#
# tabControl
#
$tabControl.Controls.Add($tabSessions)
$tabControl.Controls.Add($tabHosts)
$tabControl.Controls.Add($tabHostpool)
$tabControl.Controls.Add($tabAbout)
$tabControl.Location = New-Object System.Drawing.Point(252, 12)
$tabControl.Name = "tabControl"
$tabControl.SelectedIndex = 0
$tabControl.Size = New-Object System.Drawing.Size(1050, 675)
$tabControl.TabIndex = 9

#
# tabSessions
#
$tabSessions.Controls.Add($btExportCSVSessions)
$tabSessions.Controls.Add($btRefreshSessions)
$tabSessions.Controls.Add($lbSessionCount)
$tabSessions.Controls.Add($btSendMessage)
$tabSessions.Controls.Add($btLogoff)
$tabSessions.Controls.Add($btShadow)
$tabSessions.Controls.Add($dgvSessions)
$tabSessions.Location = New-Object System.Drawing.Point(4, 22)
$tabSessions.Name = "tabSessions"
$tabSessions.Padding = New-Object System.Windows.Forms.Padding(3)
$tabSessions.Size = New-Object System.Drawing.Size(1042, 649)
$tabSessions.TabIndex = 0
$tabSessions.Text = "Sessions"
$tabSessions.UseVisualStyleBackColor = $true

#
# tabHosts
#
$tabHosts.Controls.Add($btOpenShare)
$tabHosts.Controls.Add($btExportCSVHosts)
$tabHosts.Controls.Add($btDirectRDP)
$tabHosts.Controls.Add($btRestartHost)
$tabHosts.Controls.Add($lbHostCount)
$tabHosts.Controls.Add($btRefreshHosts)
$tabHosts.Controls.Add($btDrainOff)
$tabHosts.Controls.Add($btDrainOn)
$tabHosts.Controls.Add($dgvHosts)
$tabHosts.Location = New-Object System.Drawing.Point(4, 22)
$tabHosts.Name = "tabHosts"
$tabHosts.Padding = New-Object System.Windows.Forms.Padding(3)
$tabHosts.Size = New-Object System.Drawing.Size(1042, 649)
$tabHosts.TabIndex = 1
$tabHosts.Text = "Hosts"
$tabHosts.UseVisualStyleBackColor = $true

#
# tabHostpool
#
$tabHostpool.Controls.Add($dgvHostPoolProperties)
$tabHostpool.Location = New-Object System.Drawing.Point(4, 22)
$tabHostpool.Name = "tabHostpool"
$tabHostpool.Padding = New-Object System.Windows.Forms.Padding(3)
$tabHostpool.Size = New-Object System.Drawing.Size(1042, 649)
$tabHostpool.TabIndex = 3
$tabHostpool.Text = "Host Pool Information"
$tabHostpool.UseVisualStyleBackColor = $true

#
# tabAbout
#
$tabAbout.Controls.Add($lbabout)
$tabAbout.Location = New-Object System.Drawing.Point(4, 22)
$tabAbout.Name = "tabAbout"
$tabAbout.Padding = New-Object System.Windows.Forms.Padding(3)
$tabAbout.Size = New-Object System.Drawing.Size(1042, 649)
$tabAbout.TabIndex = 2
$tabAbout.Text = "About"
$tabAbout.UseVisualStyleBackColor = $true

#
# lbHostCount
#
$lbHostCount.AutoSize = $true
$lbHostCount.Location = New-Object System.Drawing.Point(6, 625)
$lbHostCount.Name = "lbHostCount"
$lbHostCount.Size = New-Object System.Drawing.Size(71, 13)
$lbHostCount.TabIndex = 8
$lbHostCount.Text = "Host count: 0"

#
# lbAppStatus
#
$lbAppStatus.AutoSize = $true
$lbAppStatus.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8.25,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Point, 0)
$lbAppStatus.Location = New-Object System.Drawing.Point(12, 654)
$lbAppStatus.Name = "lbAppStatus"
$lbAppStatus.Size = New-Object System.Drawing.Size(230, 0)
$lbAppStatus.MaximumSize = New-Object System.Drawing.Size(230, 0)
$lbAppStatus.AutoSize = $true;
$lbAppStatus.TabIndex = 10
$lbAppStatus.Text = "Not connected to a host pool. Select one from treeview above."

#
# lbabout
#
$lbabout.AutoSize = $true
$lbabout.Location = New-Object System.Drawing.Point(34, 28)
$lbabout.Name = "lbabout"
$lbabout.Size = New-Object System.Drawing.Size(35, 13)
$lbabout.TabIndex = 0
$lbabout.Text = "By Tom Schoen`nVersion 0.4"

#
# lbSessionCount
#
$lbSessionCount.AutoSize = $true
$lbSessionCount.Location = New-Object System.Drawing.Point(6, 625)
$lbSessionCount.Name = "lbSessionCount"
$lbSessionCount.Size = New-Object System.Drawing.Size(86, 13)
$lbSessionCount.TabIndex = 6
$lbSessionCount.Text = "Session count: 0"

#
# cmsOpenShare
#
$cmsOpenShare.Items.AddRange(@(
$tsmiOpenShareC,
$tsmiOpenFSLogixLogs))
$cmsOpenShare.Name = "cmsOpenShare"
$cmsOpenShare.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::Professional
$cmsOpenShare.Size = New-Object System.Drawing.Size(91, 26)

#
# tsmiOpenShareC
#
$tsmiOpenShareC.DropDownItems.AddRange(@(
$tsmiOpenShareCUsers))
$tsmiOpenShareC.Name = "tsmiOpenShareC"
$tsmiOpenShareC.Size = New-Object System.Drawing.Size(90, 22)
$tsmiOpenShareC.Text = "C:/"

$tsmiOpenShareC.Add_Click({
    $SessionHost = $dgvHosts.SelectedRows[0].Cells[0].Value
    Start-Process "explorer.exe" -ArgumentList "\\$SessionHost\c$"
})

#
# tsmiOpenShareCUsers
#

$tsmiOpenShareCUsers.Name = "tsmiOpenShareCUsers"
$tsmiOpenShareCUsers.Size = New-Object System.Drawing.Size(180, 22)
$tsmiOpenShareCUsers.Text = "Users"

$tsmiOpenShareCUsers.Add_Click({
    $SessionHost = $dgvHosts.SelectedRows[0].Cells[0].Value
    Start-Process "explorer.exe" -ArgumentList "\\$SessionHost\c$\Users"
})

#
# tsmiOpenFSLogixLogs
#
$tsmiOpenFSLogixLogs.Name = "tsmiOpenFSLogixLogs"
$tsmiOpenFSLogixLogs.Size = New-Object System.Drawing.Size(140, 22)
$tsmiOpenFSLogixLogs.Text = "FSLogix logs"

$tsmiOpenFSLogixLogs.Add_Click({
    $SessionHost = $dgvHosts.SelectedRows[0].Cells[0].Value
    Start-Process "explorer.exe" -ArgumentList "\\$SessionHost\c$\ProgramData\FSLogix\Logs\"
})


#
# Main
#
$Main.ClientSize = New-Object System.Drawing.Size(1314, 699)
$Main.Controls.Add($lbAppStatus)
$Main.Controls.Add($tabControl)
$Main.Controls.Add($tvPools)
$Main.Name = "Main"
$Main.Text = "WVD Session Management [$($RdsAccount.UserName) is connected to RDS Tenant $Tenant]"
$Main.FormBorderStyle = "FixedDialog"

$iconBase64      = 'AAABAAIAZGQAAAEAGACYewAAJgAAAGRkAAABABgAmHsAAL57AAAoAAAAZAAAAMgAAAABABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+///9//77//76//76//75//75//75//76//77//78///+//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////34/fjg/PTM+/C4+uym+eeR+OSC9+F2999u995p9t5o999r9+Bz9+N9+OaN+eqe+++0/PPF/ffb/vzw//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////78/vzz/vnl+++2+OWG9txj9NhQ89RE8tE38c8x8M8w8M4w784w784w784w780v780v780v784v8M4w8M8w8tE189RA9NdN9dtc9+J6+u2o/ffZ/vzw//75//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////30/PPH+eiX9t1i89I58c8w8M4v780v7swv7csv7Mou7Mou7Mov7Mov68kv68ku68ku68ku68ku68ku68ku68ku7Mou7csv7csv7swv780w8M4w8M8w8dAy9NlV+OSE+/G8/vrn//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////33/vnk+eqc9txf89RB8dAy784w7swv7csv7Mku68gu6sgt6cct6cYt6cYt6MYt6MUt6MUt58Ut58Ut58Qs58Qs58Qs58Ut6MUt6MYt6cct6scu6sgu68ku7Mou7csv7csv7swv8M4w8tI89NhO+eaN/fXR/vzz///+//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////75/PTN9+N+9NVF8c8w8M4w7swv7csv7Mku6sgu6cct6MUs58Qs5sMs5sMr5cIr5cIs5MEr5MEr5MEr48Ar48Ar48Ar48Ar48Ar48Ar5MEr5MIs5cIs5sMs5sQs58Ut6MUt6cYt6sct68gt7Mou7csu7swv8M8w89M4999v+++z/vzy/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v30/PPJ9+By89RA8M4w7swv7csv68ku6sgu6cYt6MUt58Qt5cIs5MEr48Ar4r8r4r4q4b4q4b4r4L0q4L0q4L0q4Lwq4Lwq37wq37wq37wq4Lwq4L0q4L0q4b4r4r8r4r8r48Er5MEs5cIs5sMs58Qs6MUt6cct68gu7Mou7swv8M4w8tI69txe++6w/vvt///+///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/ffb+ON+89Q/8M4w7swv7Mou68gu6cct6MYt5sQs5cIs5MEr48Ar4b4q4L0q37wp3rsp3rop3bko3bkp3bkp3Lgp3Lgo27co2rUn2bQn2rUo27go3Lgo3Lgo3Lko3rop3rop37sp37wq4b0q4b4q4r8q48Ar5MEr5sMs58Qs6cYt68gu7Mov7swv8M4w8tE29t5m/PLB//77///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/vrp+umZ9NVC8c8y7swv7Mou6sgu6MYt58Qs5cIs5MEs4r8r4b4r4L0q37wq3rop3Lco17Ak0achy58ewY4WuoMRsnYMrW4IqGcFpmQEpmMDpmMDpmMEqGYFq2sHsXQLt34Pv4wWyJob0KUg1a0k27Yo3bop3rsp37wq4L0q4r8r48Ar5cIs58Qt6MYt6sgu7Mou7swv8M4w8tM89+B0/ffb//77/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////PXO9t1g8tE1780w7csv6sgu6cYt58Qs5cIr5MEr4r8q4b0q37wq3rop3bkp17AlyJkbuYIRsHIKqGYFol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApmMErW4Itn0Pw5IY0qoi27go3bko3rsp37wp4b4r5MEr5cIs58Qt6MYt68gu7Mou7swv8M4w9dhR+uym///+/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////vzv+eeR89RB784w7csv68ku6cYu58Qs5MIr48Ar4b4q4Lwq3rop3bgp06sjxpYas3gMpWEDol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwBo14BrnAJwI0V0KYh2bUm3bop37wq4b4q4r8r5cIs5sQt6MYt6sgt7Mou7s0v8dAz9+J5/ffX/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////vrn9+J78dAz780w7Mou6sgu6MUt5sMs48Ar4r4q4Lwq3rop3Lgo1KwjvooUrGwHol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqWgGtn0Oz6Qg27co3rop4Lwq4b4r5MEr5cIr58Qs6cYt68ku7swv8M8x9dpU/fbS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////77/PXP9NhP8M4w7csv68ku6cYt58Qt5MIs4r8r4L0q3rop27gozqIfuYIRo14BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwBr3IKypwc2bQn3rop37wq4r4r48Ar5cMs6MUt6sgt7csu780v89RA+uul//33///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9+/C49NdN780v7cou6sgt6cYt5sMs5MEr4b4r37wq3Lgo1a0kvYgTqGYFoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWEDtHsO0KYg3Lco3rsp4L0q48Ar5cIr58Qs6sct7Mou780w89M9+eiX/vzy//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////75+u2r8tI4780v7Mou6cct58Qt5cIs4r8r4L0q3rsp2bUnw5IYqWgGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWEDu4QS1a4k3bkp37wp4b4q48Er58Qs6cct7Mku7swv8dAw+ON//vzv//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////77+uyp89M+780v7Mou6cct58Qs5MEr4r8r37wq3bkp0qkitn4PpGACoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0BrnEJy54d27Yn3rsp4b4q5MEr5sQs6cYt68ku7swv8dA1+OSC/vzu//////////////////////////////////////////////////////////////////////////////////////////////////////////////76++2r89M7780v7Mou6cct5sQs5MEr4b4r37wq3LgoypwcqWgGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWECv4sV2bQn3rop4b4q48Ar5sMs6cYt68ku7swv8dAx+OSB/vzx//////////////////////////////////////////////////////////////////////////////////////////////////////78+++389Q+780w7Mou6cct5sQs48Er4b4q3rsp2bMnv4sVp2QEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo14Bt34P06oi3rop4L0q48Ar5sMs6cYt68ku7swv8dE1+OWJ/v31///////////////////////////////////////////////////////////////////////////////////////////////+/PTM9NZK780w7Mou6cct5sQs5MEr4L0q3rsp17AluoMRoVwAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArW4I0qki3bop4L0q48Ar5sMs6cYt68ku7swv8dE0+uym//78/////////////////////////////////////////////////////////////////////////////////////////vnj9dtZ8M4x7csv6scu5sQs48Er4b4q3bop17AltHkNol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArW4IzaEf3rop4L0q48Ar5sMs6MYt68ku7swv89VF+/C7///+/////////////////////////////////////////////////////////////////////////////////vzv+OJ38c8w7csv6sgu58Us5MEr4b4q3rsp1q8ktn0PoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqmkG0ach3rop4b0q48Ar5sMs6cYt7Mou780w9NdK/fje///////////////////////////////////////////////////////////////////////////////9+eiT8dE27swv68gu6MUt5MEs4b4q3rop2LEls3gNolwBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArGwIzqIf3rop4b4q48Ar5sQs6cct7Mou8M4v9t5r/vvr/////////////////////////////////////////////////////////////////////////fXS89M+780w7Mku6MYt5cIs4r8q37sp2LMmuoQRoVwAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArW8J1a0k3rsp4b4q5MEr58Qs6sgt7csu8dE3+eqb/////////////////////////////////////////////////////////////////////vrn9dtd780w7Mou6cYt5sMs4r8r37wq27covYgTolwBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqGgWtoNAuIZFq20doVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsXUM1q8l3rsp4b4q5MEr6MUs68gt7swv8tI2/fXR////////////////////////////////////////////////////////////////+emb8dE27csv6sgu58Qt5MEr4L0q3bkpy54dpmMDoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXIm28as7urm8O7r4NG9tH44oVsBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0BvokU3Lgo37wp4r8r5sMs6cYt7Mou8M4w9+Bz/vzv/////////////////////////////////////////////////////////fjd8tI47swv68ku6MUt5MEs4b4r3rop0KYgqWkGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAtH455drL8vLy8vLy8vLy8vLy6uTbvI5RoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApF8CxZQZ3Lgo4Lwq48Ar5sMs6sct7csv8tE0+uyl//////////////////////////////////////////////////////31+OOA8M4w7Mou6cct5sMs4r8r37wp27cotXwOoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAq20e4tTB8vLy8vLy8vLy8vLy8vLy8vLy6N/Ut4RColwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqmoH1Kwj3bop4b4q5MEr6MUs68ku784w9NhN/vvr/////////////////////////////////////////////////PLE89RA7swv6sgu58Ut5MEs4b0q3Lgpw5EYo18CoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo18G0LON8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy6uPau4tMoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAtXwO2bQm37wq4r8r5sMs6scu7cwv8dAz+emX//76//////////////////////////////////////////789+By8M4w7Mou6cYt5cIs4r8r3rsq1Kwjq2sHoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAp2cT3Mmw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy597RuYdHolwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWEDyJkb3bkp4L0q5MEr6MUt7Mku780w9dlS/fjf/////////////////////////////////////////fTM8tI57swv6sgu58Qs5MAr4L0q3LkpuoQSoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo18Gzq6F8fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6uPZuYhHoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArW4I2LIm37sp4r8r5sMs6scu7csv8dAx+emY/////////////////////////////////////v32+ON/8M4x7Mou6MYt5cIr4b4r3rspz6MgqGYFoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEj4tTC8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy593RuolKolwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwAw5EY3Lko4b0q5MEs6MYt7Mkv780w9dhP/vvq/////////////////////////////////ffc9NZH7swv68gu58Qs48Ar4L0q27couIAQoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsHgu4tPB8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6uPZt4RCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArG0I1a0j37sp478r5sQs6scu7swv8tE3++6u////////////////////////////////+emb8c8x7cov6cct5cIs4r8q3rsp0qkipGADoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwBrXIm49bF8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy597Ru4tNoVsBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo10BwpAX3Lko4b0q5cIs6MUt7Mou8M4w999t/vzx//////////////////////////329dpZ780v68gu58Us48Ar4L0q3bkpvIYToVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsXox4tXD8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6uPatYE8oVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArG0I2rUn3rsp48Ar5sQs6sgu7swv89M8/fbW/////////////////////////PPH8tI97csu6cct5sMs4r8q3rsp06oiq2oHoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwBrG8h5NjI8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6N/Tu4xOoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwAyp0c3bop4r8q5cIs6cYt7Mov8M8w+eiW//////////////////////78+eiU8M8y7Mou6MYt5MEr4b0q3bkoxZQZo14BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsnsz49fG8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eHXtH86oVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAtn0P27co4L0q5MEr6MUt68ku780w9dxe//32/////////////////vvu9txi780v68gt58Qs48Ar37wp27cosXYLoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArG8h49bF8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eHXu4tOoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqWkG0ach37wp4r8r5sQs6scu7swv89VD/fXO/////////////////fjf89M87csv6sct5sMs4r8q3rsp1rAlpF8CoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsBsnsz5NjI8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy597StYA7oVsBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0BxpYa3rop4b4r5cMs6cYt7csu8dA0+uyp////////////////++6v8dAw7Mou6cYt5cIs4b4q3bkpxpYaoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEk4tXD8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6uLZuopKoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApmQPuYhHuolKrXEkoVwBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAtHoO3bkp4L0q5MEr6MUt7Mku784v9+F5//33////////////+eWD8M8w7Mku6MUt5MEr4L0q3LgouIAQoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwBsnoy49fH8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy5tzPtoM/olwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAq20d07mX7erk7uvm49bGuYdHolwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAp2UE27co37wq48Ar58Ut68ku7s0v9dlV/vzw//////////759dta780w68gu58Qs48Ar37wp1a4krW8JoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAr3Uq4tXD8vLx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eLYuIdGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArnMm4tPB8vLy8vLy8vLy8vLy7OfguolLol0EoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwA0KUh37sq478r5sMs6sgt7swv8tE1/fjg/////////vnh9NdL78wv6sgu5sMs4r8r37spz6Qfp2UEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwCsXgv49fG8fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy5NfHsHYroVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAr3Yr3s648vHx8vLy8vLy8vLy8vLy8vLy6eHYuIZGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwAxJIY3rop4r4r5sMs6sct7csu8dAw/PG+/////////PPH89RB7ssv6cct5sMs4r4q3ropyJkbol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArnQo3s228vLx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8fHwxJxpoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArnMn4dPB8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy4dPApmQOoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAuYAQ3bgp4b4q5cIs6cYt7Mou8M4w+uma////////+++y8tE47csv6cYt5cIr4b0q3bopv4sVoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsXkx49fG8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8fDvw5ploVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAr3Yr38+68fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eLYrnMnoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsXUL2bMm4L0q5MEs6MUt68ku784w+OJ7///////++uqe8c8x7Mou6MUt5MEr4L0q3Lkotn0PoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAr3Up4tPB8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy5dvMrXEkoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArnMm4NC78vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy4tTBp2YSoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArG4I1K0j4Lwq48Ar58Us68ku780v9t1j//78//77+OaL8M4w7Mou6MUs5MEr37wq3Lgor3EKoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsXgv4tTB8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eDWt4RDoVwBoVsAoVsAoVsAoVsAoVsAoVsAoVsAr3Uq4dK+8fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eLYuYdHoVwBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqGcF0ach37sp48Ar58Qs6sgt7swv9dpZ/vzv//74+OJ98M4w68ku58Us48Ar37wq27goqWgGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArnQo4NG88vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6uTbuYdHol0DoVsAoVsAoVsAoVsAoVsAoVsAoVsArXIl3s238vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7OfguopLol0EoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWIDzqMf37sp478r5sQs6sct7swv9NhS/vnk//319+Bx780w68ku58Qs48Aq37sp27copWECoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsHct49bG8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6N/Ut4VEolwCoVsAoVsAoVsAoVsAoVsAoVsAoVsArnMn4tXD8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eHWuolKolwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo10BzJ8e3rsp4r8r5sMs6sct7swv9NdN/fjb/v309t5p780w68gu58Qs48Aq37sp2rYool0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArnMm38648vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7OfguYdHol0DoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEj3cuz8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7urluolLol4EoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAyp0d3rop4r8r5sMs6cct7swv9NZJ/fbV/v3z9t1k780w68gu58Qs478q3rsp2bQmol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwCtYA86+Tc8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLx5drKt4RCoVsBoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEj5NjJ8vLx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6ODVuYlJoVsBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAyJob3rop4r8r5sMs6cct7csv89VH/fbR/vzz9t1j780w68gu58Qs48Ar37sp2LMmol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAtX865dnK8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6ODUsXkxol0DoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEk3Mqx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7+zouYhIol4EoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAyJkb3rsp4r8r5sMs6cct7csv89VH/fXR/v3z9t5m780w68ku58Qs48Ar37sq2bUnol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwCtH447Ofg8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy4tTBsXguoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEj5NfH8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6ODWuolKoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAyZsc3rsp4r8r5sMs6cct7swv9NZI/fbT/v309t9r784w68ku58Qs48Ar37sq27coo14BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsBtoE95dnK8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vHx6N/TsXguoVwBoVsAoVsAoVsAoVsAoVsAoVsAoVsArnMm3cuz8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7enjuopLol4EoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwAy54d3rsp4r8r5sMs6sct7swv9NdL/ffX//32+OF18M4w68ku58Ut48Ar37wq27gopmMEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwCtH866uPZ8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy49XDsnoxoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXIk4dPA8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6eLYuopMoVwBoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsA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oVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAvIYT3bkp4b4r5cIs6MYt7Mou8M4w+OaM//77/////////////vnk9NZG7swv6sgt5sMs48Ar37sp2bMmp2UEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEk3Mqy8vLx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7OfhvY5SolwCoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApGACypwc3rsp4r8r5sMs6ccu7csv8dI4+++0//////////////////30+OF1780v7Mku58Ut5MEr4Lwq3LgouYIRoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAp2YR3Mqy8fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7ejixJtnoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArW8J1q8k37wq48Ar58Qt68gu780v9NdL/vng///////////////////++uuk8dA17cou6MYt5cMr4b4q3ropyZwcpWEDoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEk28iu8vLx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7ejivI5Sol0EoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAvIcT3Lgo4b4q5MEs6MYt7Mov8M4w999t//77/////////////////////fjc89VD7swv6sgu58Qs478r37wq2LImsHMKoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAp2cT3cy18fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7OfgwplkoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo18C0qoi3rop4r8r5sMs6sct7csv8tAx++6x//////////////////////////789t9t784v68ku6MYs5MEr4L0q3bopxJMYoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsArXEj28et8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7OfgvpFWo14FoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAs3gN27co4Lwq5MEr58Qt68ku780w9NdK/vni////////////////////////////+++48dAz7csu6cct5sMs4r8q37sq17ElqmkGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqWsZ3cu08fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7ObfwZZfoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWEDypwc3bop4b4q5cIs6MYt7Mou8M4x+OSD//74/////////////////////////////vrm9dpZ7swv68ku58Qt5MEr4L0q3bgpwI0Wo10BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsBrG8h28et8vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy6+bev5Nao14FoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAs3cM2bMm37wp48Ar58Qs6sgu7swv8tM9/PPF//////////////////////////////////78+emY8M8z7Mou6cYt5cMs4r8r37sq1a4krG0IoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAq24f3cu08vHx8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy7ObfuolKoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo14BzaEe3bop4b0q5cIs6MYt7Mou8M4w9txi//33/////////////////////////////////////vnk89VG7swv6sgu58Us5MEs4b0q3bkpxZQZo14BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsBq20d28iu8fHw8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy3cu0oVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwAt30P2rUn37sp48Ar5sMs6sgu7swv8tI3+++2////////////////////////////////////////////+OaM8c8w7Mou6cYt5sMs48Ar37wq2LImsXQLoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAq24f2MGj8fDv8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy4dK/oVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAp2UEz6Qg3rop4b4q5MEr6MYt7Mou8M4w9t1j/vvr/////////////////////////////////////////////fje9NlT780v68ku6MUt5cIs4b4r3ropz6MfqGYFoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWIM1LuZ8O/t8vLy8vLy8vLy8vLy8vLy8vLy8O7sxp9toVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0Bw5EX3Lgo4L0p48Ar58Qs6sgu7swv8tE3/PG8///+//////////////////////////////////////////////77+uqb8dAx7csv6scu58Qt48Ar4L0q3bkpvokUoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqWkX1r6f8fHw8vLy8vLy8vLy8vLy8fDv1LqYpmQPoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAsHQL2LIl3rsp4r8r5cIs6MYt7Mov8M4w9t1j//33//////////////////////////////////////////////////////749dlV8M4w7Mov6cct5cMs4r8r37wq2LImtnwPolwAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo18H1byb8O/t8vLy8vLy8O7s0bWQo18HoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAq2sH0qgi3rop4b4q5MEr6MUt68gu7s0v9NVD/PTM////////////////////////////////////////////////////////////+/C389M+7swv68ku6MUt5cIs4b4r3rop06ojqmkGoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqWoYza2D6+Tc597RyKN0p2YSoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApGACx5gb3bkp4L0q48Ar5sQs6cct7csu8c8x+eeO//34//////////////////////////////////////////////////////////////33+OWG8dAw7csv6sgu58Qt5MEs4b0q3bopy54dp2UEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0BwIwW27Yo4Lwq4r8r5cMs6cYt7Mku8M4w9dlQ/vzw/////////////////////////////////////////////////////////////////////vvp9dlS8M4w7Mou6ccu5sMs48Ar37wp27coxZUZpF8CoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0BuH8Q2bQn37sq4r8r5cIs6MUs68ku7swv89RC+/G8///////////////////////////////////////////////////////////////////////////+/PG+89VB780v7Mku6MYt5cMs4r8q37wp3Lkowo8XpWEDoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVwAuIAQ2LEl37sp4b4q5MEr58Qs6sgt7csv8c8w+eiW//75//////////////////////////////////////////////////////////////////////////////75+uqf8dE17swv68gu6MUt5MIr4b4q37wp2rUnw5EYpF8CoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0BtXsO2LIm3rsp4b4q5MEr5sQs6cct7Mou8M8y9t5r/vzx//////////////////////////////////////////////////////////////////////////////////////34+ON/8dA07csv6sgt58Qs5MEr4r4q3rsp27gowpAXpWIDoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAuoIR17Al3rsp4b4q5MEr58Qs6cct7Mou780v9dtc/fjg/////////////////////////////////////////////////////////////////////////////////////////////vrn9t5p8M8w7csv6sct58Qs5MEr4b4q37wp2rYnyJobp2UEoVwAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApWEDuoQS2bMm3rsp4b4q5MEr5sQs6cct7Mou780v89VF/PTN///+/////////////////////////////////////////////////////////////////////////////////////////////////ffb9dpW8M4v7Mou6sct58Qs5MEr4r8q37wq3bkpzaEfr3EKoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAp2QExpYZ2bQn37sp4b4q5MEr58Qs6cct7Mou780v89Q/+++2//79///////////////////////////////////////////////////////////////////////////////////////////////////////+/ffX9dpY784w7Mou6sct58Us5cIr4r8q4L0q3bop1q8kuH8QpGACoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAol0Br3IKzqMf3Lgo37sp4r4q5MEr58Qt6cct7Mov780w89RA+++0//78/////////////////////////////////////////////////////////////////////////////////////////////////////////////////PXP9dlT8M4v7csu6sgt6MUt5cIs48As4b0q37sq2rQnxpYZqGcFoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsApF8CvIcT1a4k3bop4Lwq4r8q5cIs58Ut6sgu7Mov780w89M8++6u//76///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/fje9dtc8M8x7csv68ku6MYt58Qt5MEs4r8r4Lwq3bkp1KwjuYIRpmMEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo18CsncMzaEf27go3rsp4b4q48Ar5cIs6MUt6sgu7csv8M4w9NZH/PC5///9/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////ffa9t5r8M8w7swv68ku6ccu58Qt5cIs478r4L0q3rsp2rUnzKAesHIKolwAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAqmkGxJMZ17Em3bop4Lwq4b4r48Er5sMs6MYt68ku7csv8M8w9NdK/PLC//77//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////75+OaL8tM7780v7csv6sgu6MYt5sMs5MEr4b4q4Lwp3rop27cozaIfs3cNpmMEoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAo14BsHIKxJIY27Yo3rop37wq4r4r48Ar5cIs58Qs6cct68ku7swv8dAx9+Bx/fnh/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v30+u2p89M78M8x7csv68ku6cct58Qt5cIs4r8r4b4q37sq3rop2LMnzqIfuH8QpmMEol0BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwBo14Bs3gMxpca1q8l3bkp37wq4L0q48Ar5MIs5sQs6MYt6sgt7cou780v8tE3+OJ6/vvq/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////fbS9+Bt8dAx780w7csv68gu6MYt5sQs5MIr48Ar4b4q37wp3rsp3Lkp2LImxpcatn0Pq2sHo14BoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAoVsAolwBqGcFsnYMwo8X06oi3Lgo3bkp37wq4b4q48Ar5cIs5sMs6MYt6sct7Mku7swv8M8w9NdM+/G7//75/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////vvp+eiS9NVF8M8x7swv68ku6cct6MUs5sMs5MEr48Ar4r8r4L0q37wq3bop2rYn06sjy58dvosVsnYLqGYFpWEDpGACo14Bol0BoVsAoVsAoVsAoVsAoVsAoVsAolwAo10Bo18CpWEDpmMEr3EKuoQSyJoc0agh2LIm3Lko3rop37wp4L0q4r8q5MEs5sMs6MUt6cct68ku7csv780v8tE39+F5/fXS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////fXR9+Fz8tI3780v7csv68ku6sct6MYt58Qs5cMs5MEr478r4b4q4L0q37wp3bop3bko3Lgo2rYn0qkhy58dxZQZwI0WvYcTuoMSuYERuYEQuYIRu4UTv4oVxJIYyZsb0ach2LIm3Lgo3bkp3rop37sp37wp4L0q4b4q48Ar5cIr5sMs6MUt6sct68ku7csv780w8c8w9dte+++z//77/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////vzy+/C39ttf8dE4780v7csv68ku6sgt6cYt58Ut5sMs5cIs5MEr478q4b4q4L0q4Lwq37sp3rsp3rsp3rop3bop3bop3Lkp3Lgo27go3Lgo3bko3bkp3bop3bop3rsp37wq4Lwq4b4q4b4r478r48Ar5MEr5cIs58Qs6MUt6sct68ku7csv780w8dA19NhN+uqd/vrm///+/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////vzx++6v9t1l8dAy8M4v7swu7csu68ku6sgt6cYt6MUt5sQs5cIr5MEr48Ar48Aq4r8q4r8q4b4q4b4q4b4q4b0q4L0q4L0q4L0p4L0p4L0q4b4q4r8q4r8q48Ar5MEr5MIr5cIs5sMs58Qs6MYs6cct6sgt7Mku7ssv780w8dAw9dhQ+umZ/vnh///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9/vzw+/G99+B089VF8dAz780w7cwv7csv68ku6sgu6cYt6MYt58Us58Qs5sMs5sMs5sMs5cIs5cIs5cIs5cIs5MEr5MEr5MEr5cIr5cIr5cMs5sQs58Qs6MUt6MYt6cct6sgu68gt68ku7csu7swv8M4w89NA9ttd+u2r/vnk//77///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/fXQ+uqc9txe8tI38c8w8M4w7swv7csv7Mou68ku68gu6sgu6sgu6scu6ccu6ccu6ccu6cYu6MYt6MYt6cYt6cYt6cct6cct6sgu68gu7Mkv7Mov7csv7swv780v8M4w8dAw9NhS+OSE/PPG/v30///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9/vzz/ffZ+uqf999r9NhQ8tM98c8y8M4v780v7swv7swv7swv7csv7csv7csv7cov7Mou7Mou7cou7csu7csv7ssv7s0v780w8M4w8c8x8tI59NdL9ttf+eeQ/PPH/vzv//76//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////77/fjf/PLC+uuk+ON+9txh89VC89Ez8tEx8tAx8dAx8c8x8c8x8c8w8c8w8c8w8c8w8tAx8tAx89Q99dpW9+F2+eiX+/C6/ffX/v31///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+//77//75//32/vvt/ffY/PPH+/C6+++x++2s++2r++6v+/C3/PLC/fbU/vrm/v32//34//77///9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAAABkAAAAyAAAAAEAGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD78Lj67Kb555H45IL34Xb332733mn23mj332v34HP343345o356p7777T888UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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wCvivirgvCreuincuCjUrCO+ihSsbAeiXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCpaAa2fQ7PpCDbtyjeuingvCrhvivkwSvlwivnxCzpxi3ryS7uzC/wzzH12lQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD02E/wzjDtyy/ryS7pxi3nxC3kwizivyvgvSreuinbuCjOoh+5ghGjXgGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXAGvcgrKnBzZtCfeuinfvCrivivjwCvlwyzoxS3qyC3tyy7vzS/z1ED666UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD78Lj0103vzS/tyi7qyC3pxi3mwyzkwSvhvivfvCrcuCjVrSS9iBOoZgWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYQO0ew7QpiDctyjeuyngvSrjwCvlwivnxCzqxy3syi7vzTDz0z356JcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD67avy0jjvzS/syi7pxy3nxC3lwizivyvgvSreuynZtSfDkhipaAahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYQO7hBLVriTduSnfvCnhvirjwSvnxCzpxy3syS7uzC/x0DD4438AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD67Knz0z7vzS/syi7pxy3nxCzkwSvivyvfvCrduSnSqSK2fg+kYAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQGucQnLnh3btifeuynhvirkwSvmxCzpxi3ryS7uzC/x0DX45IIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD77avz0zvvzS/syi7pxy3mxCzkwSvhvivfvCrcuCjKnBypaAahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYQK/ixXZtCfeuinhvirjwCvmwyzpxi3ryS7uzC/x0DH45IEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777fz1D7vzTDsyi7pxy3mxCzjwSvhvireuynZsye/ixWnZAShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXgG3fg/TqiLeuingvSrjwCvmwyzpxi3ryS7uzC/x0TX45YkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD01krvzTDsyi7pxy3mxCzkwSvgvSreuynXsCW6gxGhXAChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtbgjSqSLduingvSrjwCvmwyzpxi3ryS7uzC/x0TT67KYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD121nwzjHtyy/qxy7mxCzjwSvhvirduinXsCW0eQ2iXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtbgjNoR/euingvSrjwCvmwyzoxi3ryS7uzC/z1UX78LsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD44nfxzzDtyy/qyC7nxSzkwSvhvireuynWryS2fQ+hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCqaQbRpyHeuinhvSrjwCvmwyzpxi3syi7vzTD010oAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD56JPx0TbuzC/ryC7oxS3kwSzhvireuinYsSWzeA2iXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCsbAjOoh/euinhvirjwCvmxCzpxy3syi7wzi/23msAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADz0z7vzTDsyS7oxi3lwizivyrfuynYsya6hBGhXAChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtbwnVrSTeuynhvirkwSvnxCzqyC3tyy7x0Tf56psAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD1213vzTDsyi7pxi3mwyzivyvfvCrbtyi9iBOiXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCoaBa2g0C4hkWrbR2hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCxdQzWryXeuynhvirkwSvoxSzryC3uzC/y0jYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD56Zvx0Tbtyy/qyC7nxC3kwSvgvSrduSnLnh2mYwOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtcibbxqzu6ubw7uvg0b20fjihWwGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQG+iRTcuCjfvCnivyvmwyzpxi3syi7wzjD34HMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADy0jjuzC/ryS7oxS3kwSzhviveuinQpiCpaQahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC0fjnl2svy8vLy8vLy8vLy8vLq5Nu8jlGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCkXwLFlBncuCjgvCrjwCvmwyzqxy3tyy/y0TT67KUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD444DwzjDsyi7pxy3mwyzivyvfvCnbtyi1fA6hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCrbR7i1MHy8vLy8vLy8vLy8vLy8vLy8vLo39S3hEKiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCqagfUrCPduinhvirkwSvoxSzryS7vzjD02E0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD88sTz1EDuzC/qyC7nxS3kwSzhvSrcuCnDkRijXwKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwbQs43y8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLq49q7i0yhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC1fA7ZtCbfvCrivyvmwyzqxy7tzC/x0DP56ZcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD34HLwzjDsyi7pxi3lwizivyveuyrUrCOrawehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZxPcybDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLn3tG5h0eiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYQPImRvduSngvSrkwSvoxS3syS7vzTD12VIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADy0jnuzC/qyC7nxCzkwCvgvSrcuSm6hBKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwbOroXx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq49m5iEehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtbgjYsibfuynivyvmwyzqxy7tyy/x0DH56ZgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD443/wzjHsyi7oxi3lwivhviveuynPoyCoZgWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtcSPi1MLy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLn3dG6iUqiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXADDkRjcuSjhvSrkwSzoxi3syS/vzTD12E8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD01kfuzC/ryC7nxCzjwCvgvSrbtyi4gBChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCweC7i08Hy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq49m3hEKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCsbQjVrSPfuynjvyvmxCzqxy7uzC/y0Tf77q4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD56ZvxzzHtyi/pxy3lwizivyreuynSqSKkYAOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXAGtcibj1sXy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLn3tG7i02hWwGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXQHCkBfcuSjhvSrlwizoxS3syi7wzjD3320AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12lnvzS/ryC7nxSzjwCvgvSrduSm8hhOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCxejHi1cPy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq49q1gTyhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCsbQjatSfeuynjwCvmxCzqyC7uzC/z0zwAAAAAAAAAAAAAAAAAAAAAAAAAAAD888fy0j3tyy7pxy3mwyzivyreuynTqiKragehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXAGsbyHk2Mjy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLo39O7jE6hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXADKnRzduinivyrlwizpxi3syi/wzzD56JYAAAAAAAAAAAAAAAAAAAAAAAD56JTwzzLsyi7oxi3kwSvhvSrduSjFlBmjXgGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCyezPj18by8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4de0fzqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC2fQ/btyjgvSrkwSvoxS3ryS7vzTD13F4AAAAAAAAAAAAAAAAAAAAAAAD23GLvzS/ryC3nxCzjwCvfvCnbtyixdguhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCsbyHj1sXy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4de7i06hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCpaQbRpyHfvCnivyvmxCzqxy7uzC/z1UMAAAAAAAAAAAAAAAAAAAAAAADz0zztyy/qxy3mwyzivyreuynWsCWkXwKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwGyezPk2Mjy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLn3tK1gDuhWwGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQHGlhreuinhvivlwyzpxi3tyy7x0DT67KkAAAAAAAAAAAAAAAD77q/x0DDsyi7pxi3lwizhvirduSnGlhqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtcSTi1cPy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq4tm6ikqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCmZA+5iEe6iUqtcSShXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC0eg7duSngvSrkwSvoxS3syS7vzi/34XkAAAAAAAAAAAAAAAD55YPwzzDsyS7oxS3kwSvgvSrcuCi4gBChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXAGyejLj18fy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLm3M+2gz+iXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCrbR3TuZft6uTu6+bj1sa5h0eiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZQTbtyjfvCrjwCvnxS3ryS7uzS/12VUAAAAAAAAAAAAAAAD121rvzTDryC7nxCzjwCvfvCnVriStbwmhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCvdSri1cPy8vHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4ti4h0ahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCucybi08Hy8vLy8vLy8vLy8vLs5+C6iUuiXQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXADQpSHfuyrjvyvmwyzqyC3uzC/y0TUAAAAAAAAAAAAAAAD010vvzC/qyC7mwyzivyvfuynPpB+nZQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXAKxeC/j18bx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLk18ewdiuhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCvdivezrjy8fHy8vLy8vLy8vLy8vLy8vLp4di4hkahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXADEkhjeuinivivmwyzqxy3tyy7x0DD88b4AAAAAAAD888fz1EHuyy/pxy3mwyzivireuinImRuiXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCudCjezbby8vHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLx8fDEnGmhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCucyfh08Hy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLh08CmZA6hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC5gBDduCnhvirlwizpxi3syi7wzjD66ZoAAAAAAAD777Ly0Tjtyy/pxi3lwivhvSrduim/ixWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCxeTHj18by8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLx8O/DmmWhWwChWwChWwChWwChWwChWwChWwChWwChWwCvdivfz7rx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4tiucyehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCxdQvZsybgvSrkwSzoxS3ryS7vzjD44nsAAAAAAAD66p7xzzHsyi7oxS3kwSvgvSrcuSi2fQ+hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCvdSni08Hy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLl28ytcSShWwChWwChWwChWwChWwChWwChWwChWwCucybg0Lvy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLi1MGnZhKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCsbgjUrSPgvCrjwCvnxSzryS7vzS/23WMAAAAAAAD45ovwzjDsyi7oxSzkwSvfvCrcuCivcQqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCxeC/i1MHy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4Na3hEOhXAGhWwChWwChWwChWwChWwChWwChWwCvdSrh0r7x8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4ti5h0ehXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCoZwXRpyHfuynjwCvnxCzqyC3uzC/12lkAAAAAAAD44n3wzjDryS7nxSzjwCvfvCrbuCipaAahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCudCjg0bzy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq5Nu5h0eiXQOhWwChWwChWwChWwChWwChWwChWwCtciXezbfy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+C6ikuiXQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYgPOox/fuynjvyvmxCzqxy3uzC/02FIAAAAAAAD34HHvzTDryS7nxCzjwCrfuynbtyilYQKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCwdy3j1sby8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLo39S3hUSiXAKhWwChWwChWwChWwChWwChWwChWwCucyfi1cPy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4da6iUqiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXQHMnx7euynivyvmwyzqxy3uzC/0100AAAAAAAD23mnvzTDryC7nxCzjwCrfuynatiiiXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCucybfzrjy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+C5h0eiXQOhWwChWwChWwChWwChWwChWwChWwCtcSPdy7Py8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLu6uW6iUuiXgShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDKnR3euinivyvmwyzpxy3uzC/01kkAAAAAAAD23WTvzTDryC7nxCzjvyreuynZtCaiXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXAK1gDzr5Nzy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vHl2sq3hEKhWwGhWwChWwChWwChWwChWwChWwChWwCtcSPk2Mny8vHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLo4NW5iUmhWwGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDImhveuinivyvmwyzpxy3tyy/z1UcAAAAAAAD23WPvzTDryC7nxCzjwCvfuynYsyaiXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC1fzrl2cry8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLo4NSxeTGiXQOhWwChWwChWwChWwChWwChWwChWwCtcSTcyrHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLv7Oi5iEiiXgShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDImRveuynivyvmwyzpxy3tyy/z1UcAAAAAAAD23mbvzTDryS7nxCzjwCvfuyrZtSeiXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXAK0fjjs5+Dy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLi1MGxeC6hWwChWwChWwChWwChWwChWwChWwChWwCtcSPk18fy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLo4Na6iUqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDJmxzeuynivyvmwyzpxy3uzC/01kgAAAAAAAD232vvzjDryS7nxCzjwCvfuyrbtyijXgGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwG2gT3l2cry8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8fHo39OxeC6hXAGhWwChWwChWwChWwChWwChWwChWwCucybdy7Py8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLt6eO6ikuiXgShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXADLnh3euynivyvmwyzqxy3uzC/010sAAAAAAAD44XXwzjDryS7nxS3jwCvfvCrbuCimYwShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXAK0fzrq49ny8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLj1cOyejGhWwChWwChWwChWwChWwChWwChWwChWwCtciTh08Dy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLp4ti6ikyhXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwLNoB7fuynjwCvmxCzqxy3uzC/02E8AAAAAAAD45IHwzjDsyi7oxS3kwCvfvCrcuCirawehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC2gT7l2szy8vHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8fHm282yejGhXAGhWwChWwChWwChWwChWwChWwChWwCucyfezLXx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLr5t67i02iXQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCmYwTPpCDfuynjwCvnxCzqyC7uzC/12VQAAAAAAAD555LxzzDsyi7oxS3kwSvgvSrcuSixdQuhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCsbx/m3M7y8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLk18ayezOhWwGhWwChWwChWwChWwChWwChWwChWwCtciTfz7ry8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq5Nu7i06iXQOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCqaQbSqSLgvCrjwCvnxCzryC7vzTD121wAAAAAAAD67KXx0DPtyi7oxi3kwSvgvSrduSi5ghGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDFn23x7+7y8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8fHl2cqyezOhXAGhWwChWwChWwChWwChWwChWwChWwCmZRDZxKjx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLq5Nu7jE+iXQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCucAnWriXgvCrkwSvnxSzryC7vzS/23moAAAAAAAD78Lny0jrtyy7pxi3lwivhvSrduSjCkBehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDKp3nx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLl2suzezShXAGhWwChWwChWwChWwChWwChWwChWwChWwCwdy3x8O/y8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLt6eS7jE6iXQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCzeA3atSfgvSrkwSzoxS3ryS7wzjD45IUAAAAAAAAAAADz1UTuzC/pxy3lwyvhvireuinKnR2kYAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC0fjjr5Nzy8vLy8vLy8vLy8vLy8vLy8vLy8fHk18eyezShXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwCtcSTw7uvy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLv6+jCmWSjXwahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC8hxPduSnhvirlwizpxi3syi7wzzD67KcAAAAAAAAAAAD02E7uzC/qxy3mxCzivyveuynQpyGpaAahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwDGoG/u6+fy8vLy8vLy8vLy8vLy8vLn3dCyezShXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCmYw7YwaPy8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+DAlFuhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXADHmBreuinivyrlwizpxy3tyy7xzzD888kAAAAAAAAAAAD23mfvzjDryS7nxCzjwCvfvCnYsyaxdAuhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwbCmGHt6OLy8vLy8vLy8vHj1sSyezOhWwGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCpaRfaxarx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+DDmmSjXgWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXQHVriTeuyriwCvmxCzqyC3uzC/z1D4AAAAAAAAAAAAAAAD555DwzzDsyS7oxSzkwSvgvSrcuSi8hROhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQO/k1rg0Lvs5t7axqywdy2hXAGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCscCLdy7Py8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+C+kFWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCqagfcuCjfvCrjwSvnxC3ryS7vzS/2218AAAAAAAAAAAAAAAD888Xy0DHtyy/pxy3lwizivireuinNoh+hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwGiXQOiXQSiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZhPbx63x8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLt6OLEm2eiXQOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC8hhPduSnhvivlwizoxi3syi7wzjD45owAAAAAAAAAAAAAAAAAAAD01kbuzC/qyC3mwyzjwCvfuynZsyanZQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtcSTcyrLy8vHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+G9jlKiXAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCkYALKnBzeuynivyvmwyzpxy7tyy/x0jj777QAAAAAAAAAAAAAAAAAAAD44XXvzS/syS7nxS3kwSvgvCrcuCi5ghGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZhHcyrLx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLt6OLEm2ehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtbwnWryTfvCrjwCvnxC3ryC7vzS/010sAAAAAAAAAAAAAAAAAAAAAAAD666Tx0DXtyi7oxi3lwyvhvireuinJnBylYQOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtcSTbyK7y8vHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLt6OK8jlKiXQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC8hxPcuCjhvirkwSzoxi3syi/wzjD3320AAAAAAAAAAAAAAAAAAAAAAAAAAADz1UPuzC/qyC7nxCzjvyvfvCrYsiawcwqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZxPdzLXx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+DCmWShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwLSqiLeuinivyvmwyzqxy3tyy/y0DH77rEAAAAAAAAAAAAAAAAAAAAAAAAAAAD2323vzi/ryS7oxizkwSvgvSrduinEkxihWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCtcSPbx63y8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5+C+kVajXgWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCzeA3btyjgvCrkwSvnxC3ryS7vzTD010oAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777jx0DPtyy7pxy3mwyzivyrfuyrXsSWqaQahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCpaxndy7Tx8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5t/Bll+hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYQPKnBzduinhvirlwizoxi3syi7wzjH45IMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12lnuzC/ryS7nxC3kwSvgvSrduCnAjRajXQGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwGsbyHbx63y8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLr5t6/k1qjXgWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCzdwzZsybfvCnjwCvnxCzqyC7uzC/y0z3888UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD56ZjwzzPsyi7pxi3lwyzivyvfuyrVriSsbQihWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCrbh/dy7Ty8fHy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLs5t+6iUqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXgHNoR7duinhvSrlwizoxi3syi7wzjD23GIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADz1UbuzC/qyC7nxSzkwSzhvSrduSnFlBmjXgGhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwGrbR3byK7x8fDy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLdy7ShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXAC3fQ/atSffuynjwCvmwyzqyC7uzC/y0jf777YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD45ozxzzDsyi7pxi3mwyzjwCvfvCrYsiaxdAuhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCrbh/YwaPx8O/y8vLy8vLy8vLy8vLy8vLy8vLy8vLy8vLh0r+hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZQTPpCDeuinhvirkwSvoxi3syi7wzjD23WMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD02VPvzS/ryS7oxS3lwizhviveuinPox+oZgWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYgzUu5nw7+3y8vLy8vLy8vLy8vLy8vLy8vLw7uzGn22hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQHDkRfcuCjgvSnjwCvnxCzqyC7uzC/y0Tf88bwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD66pvx0DHtyy/qxy7nxC3jwCvgvSrduSm+iRShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCpaRfWvp/x8fDy8vLy8vLy8vLy8vLx8O/UupimZA+hWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCwdAvYsiXeuynivyvlwizoxi3syi/wzjD23WMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12VXwzjDsyi/pxy3lwyzivyvfvCrYsia2fA+iXAChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwfVvJvw7+3y8vLy8vLw7uzRtZCjXwehWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCrawfSqCLeuinhvirkwSvoxS3ryC7uzS/01UMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD78Lfz0z7uzC/ryS7oxS3lwizhviveuinTqiOqaQahWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCpahjNrYPr5Nzn3tHIo3SnZhKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCkYALHmBvduSngvSrjwCvmxCzpxy3tyy7xzzH5544AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD45Ybx0DDtyy/qyC7nxC3kwSzhvSrduinLnh2nZQShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQHAjBbbtijgvCrivyvlwyzpxi3syS7wzjD12VAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12VLwzjDsyi7pxy7mwyzjwCvfvCnbtyjFlRmkXwKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQG4fxDZtCffuyrivyvlwizoxSzryS7uzC/z1EL78bwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD88b7z1UHvzS/syS7oxi3lwyzivyrfvCncuSjCjxelYQOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChXAC4gBDYsSXfuynhvirkwSvnxCzqyC3tyy/xzzD56JYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD66p/x0TXuzC/ryC7oxS3kwivhvirfvCnatSfDkRikXwKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQG1ew7YsibeuynhvirkwSvmxCzpxy3syi7wzzL23msAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD443/x0DTtyy/qyC3nxCzkwSvivireuynbuCjCkBelYgOhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwC6ghHXsCXeuynhvirkwSvnxCzpxy3syi7vzS/121wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD23mnwzzDtyy/qxy3nxCzkwSvhvirfvCnatifImhunZQShXAChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwClYQO6hBLZsybeuynhvirkwSvmxCzpxy3syi7vzS/z1UUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12lbwzi/syi7qxy3nxCzkwSvivyrfvCrduSnNoR+vcQqhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCnZATGlhnZtCffuynhvirkwSvnxCzpxy3syi7vzS/z1D/777YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12ljvzjDsyi7qxy3nxSzlwivivyrgvSrduinWryS4fxCkYAKhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCiXQGvcgrOox/cuCjfuynivirkwSvnxC3pxy3syi/vzTDz1ED777QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD12VPwzi/tyy7qyC3oxS3lwizjwCzhvSrfuyratCfGlhmoZwWhWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCkXwK8hxPVriTduingvCrivyrlwiznxS3qyC7syi/vzTDz0zz77q4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD121zwzzHtyy/ryS7oxi3nxC3kwSzivyvgvCrduSnUrCO5ghGmYwShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXwKydwzNoR/buCjeuynhvirjwCvlwizoxS3qyC7tyy/wzjD01kf88LkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD23mvwzzDuzC/ryS7pxy7nxC3lwizjvyvgvSreuynatSfMoB6wcgqiXAChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCqaQbEkxnXsSbduingvCrhvivjwSvmwyzoxi3ryS7tyy/wzzD010r88sIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD45ovy0zvvzS/tyy/qyC7oxi3mwyzkwSvhvirgvCneuinbtyjNoh+zdw2mYwShWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwChWwCjXgGwcgrEkhjbtijeuinfvCrivivjwCvlwiznxCzpxy3ryS7uzC/x0DH34HEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD67anz0zvwzzHtyy/ryS7pxy3nxC3l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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD88sL666T443723GHz1ULz0TPy0THy0DHx0DHxzzHxzzHxzzDxzzDxzzDxzzDy0DHy0DHz1D312lb34Xb56Jf78LoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD888f78Lr777H77az77av77q/78Lf88sIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD////////////////wAAAA///////gAD//////8AAAAP/////8AAAD//////AAAAD/////wAAAAD/////wAAAA/////wAAAAAP////8AAAAP////wAAAAAAf////AAAAD////gAAAAAAB////wAAAA////wAAAAAAAH///8AAAAP///wAAAAAAAA////AAAAD///4AAAAAAAAD///wAAAA///4AAAAAAAAAf//8AAAAP//8AAAAAAAAAD///AAAAD//+AAAAAAAAAAP//wAAAA//+AAAAAAAAAAB//8AAAAP//AAAAAAAAAAAP//AAAAD//gAAAAAAAAAAB//wAAAA//wAAAAAAAAAAAP/8AAAAP/4AAAAAAAAAAAB//AAAAD/+AAAAAAAAAAAAP/wAAAA//AAAAAAAAAAAAB/8AAAAP/gAAAAAAAAAAAAf/AAAAD/wAAAAAAAAAAAAD/wAAAA/8AAAAAAAAAAAAAf8AAAAP+AAAAAAAAAAAAAH/AAAAD/AAAAAAAAAAAAAA/wAAAA/wAAAAAAAAAAAAAH8AAAAP4AAAAAAAAAAAAAB/AAAAD8AAAAAAAAAAAAAAPwAAAA/AAAAAAAAAAAAAAD8AAAAPwAAAAAAAAAAAAAAfAAAAD4AAAAAAAAAAAAAAHwAAAA+AAAAAAAAAAAAAAA8AAAAPAAAAAAAAAAAAAAAPAAAADwAAAAAAAAAAAAAADwAAAA4AAAAAAAAAAAAAAAcAAAAOAAAAAAAAAAAAAAAHAAAADgAAAAAAAAAAAAAABwAAAA4AAAAAAAAAAAAAAAMAAAAMAAAAAAAAAAAAAAADAAAADAAAAAAAAAAAAAAAAwAAAAwAAAAAAAAAAAAAAAMAAAAMAAAAAAAAAAAAAAABAAAACAAAAAAAAAAAAAAAAQAAAAgAAAAAAAAAAAAAAAEAAAAIAAAAAAAAAAAAAAABAAAACAAAAAAAAAAAAAAAAQAAAAgAAAAAAAAAAAAAAAEAAAAIAAAAAAAAAAAAAAABAAAACAAAAAAAAAAAAAAAAQAAAAgAAAAAAAAAAAAAAAEAAAAIAAAAAAAAAAAAAAABAAAACAAAAAAAAAAAAAAAAQAAAAgAAAAAAAAAAAAAAAEAAAAIAAAAAAAAAAAAAAABAAAACAAAAAAAAAAAAAAAAQAAAAgAAAAAAAAAAAAAAAEAAAAIAAAAAAAAAAAAAAABAAAACAAAAAAAAAAAAAAAAQAAAAwAAAAAAAAAAAAAAAEAAAAMAAAAAAAAAAAAAAABAAAADAAAAAAAAAAAAAAAAwAAAAwAAAAAAAAAAAAAAAMAAAAMAAAAAAAAAAAAAAADAAAADgAAAAAAAAAAAAAAAwAAAA4AAAAAAAAAAAAAAAcAAAAOAAAAAAAAAAAAAAAHAAAADwAAAAAAAAAAAAAABwAAAA8AAAAAAAAAAAAAAA8AAAAPAAAAAAAAAAAAAAAPAAAAD4AAAAAAAAAAAAAADwAAAA+AAAAAAAAAAAAAAB8AAAAPwAAAAAAAAAAAAAAfAAAAD8AAAAAAAAAAAAAAPwAAAA/gAAAAAAAAAAAAAD8AAAAP4AAAAAAAAAAAAAB/AAAAD/AAAAAAAAAAAAAA/wAAAA/wAAAAAAAAAAAAAP8AAAAP+AAAAAAAAAAAAAH/AAAAD/wAAAAAAAAAAAAB/wAAAA/8AAAAAAAAAAAAA/8AAAAP/gAAAAAAAAAAAAf/AAAAD/8AAAAAAAAAAAAP/wAAAA//gAAAAAAAAAAAH/8AAAAP/8AAAAAAAAAAAB//AAAAD//gAAAAAAAAAAA//wAAAA//8AAAAAAAAAAAf/8AAAAP//gAAAAAAAAAAP//AAAAD//8AAAAAAAAAAH//wAAAA///gAAAAAAAAAH//8AAAAP//8AAAAAAAAAD///AAAAD///wAAAAAAAAB///wAAAA///+AAAAAAAAB///8AAAAP///4AAAAAAAA////AAAAD////AAAAAAAA////wAAAA////8AAAAAAA////8AAAAP////wAAAAAA/////AAAAD/////gAAAAA/////wAAAA//////AAAAB/////8AAAAP/////+AAAH//////AAAAD///////wD///////wAAAA'
$iconBytes       = [Convert]::FromBase64String($iconBase64)
$stream          = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
$stream.Write($iconBytes, 0, $iconBytes.Length);
$iconImage       = [System.Drawing.Image]::FromStream($stream, $true)
$Main.Icon       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())


function OnFormClosing_Main{ 
	#   if (($_).CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing)
	($_).Cancel= $False
}

$Main.Add_FormClosing( { OnFormClosing_Main} )

$Main.Add_Shown({$Main.Activate()})
$ModalResult=$Main.ShowDialog()
# Release the Form
$Main.Dispose()