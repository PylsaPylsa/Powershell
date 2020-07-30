cls
$group = "Contoso-fileperms-RW"
$domain ='contoso.local'
$target = "\\?\D:\"
$permissions = "Modify"


$countTotal = [int]0
$countApply = [int]0

$folders = Get-ChildItem -LiteralPath $target -Directory -recurse
foreach ($folder in $folders) {
    $acls = Get-Acl -Path $folder.FullName  
    if ($acls.AreAccessRulesProtected -eq $true) {
        foreach ($acl in $acls) {
            Write-Host $("[*] Checking {0}" -f $folder.FullName) -ForegroundColor "Green"
            $accs = $acl.Access 
            $apply = $true 
            foreach ($acc in  $accs){
                if ($acc.identityreference.tostring().split('\')[1] -eq $group) {
                    Write-Host "    [*] Already applied" -ForegroundColor "Cyan"
                    $apply = $false
                }
            }
            $countTotal++
            if ($apply -eq $true) {
                $acl_Rule = new-object System.Security.AccessControl.FileSystemAccessRule ("$domain\$group", "$permissions","ContainerInherit,ObjectInherit","None","Allow")
                $acl.SetAccessRule($ACL_Rule)
                Write-Host $("    [*] Applying") -ForegroundColor "Green"
                Set-Acl -Path $folder.FullName -AclObject $acl 
                $countApply++
            }
        }
    }
}

Write-Host "[*] $countTotal directories found, applied group to $countApply of them." -ForegroundColor "Cyan"