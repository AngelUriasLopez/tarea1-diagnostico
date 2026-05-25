param(
    [string]$SiteName = "FTP-Academico",
    [string]$FtpRoot = "C:\FTP",
    [int]$PassiveStartPort = 50000,
    [int]$PassiveEndPort = 50100,
    [int]$UserCount
)

Import-Module ServerManager
Import-Module WebAdministration

$features = @(
    "Web-Server",
    "Web-Ftp-Server",
    "Web-Ftp-Service",
    "Web-Mgmt-Tools",
    "Web-Scripting-Tools"
)

foreach ($feature in $features) {
    $f = Get-WindowsFeature -Name $feature
    if (-not $f.Installed) {
        Install-WindowsFeature -Name $feature -IncludeManagementTools | Out-Null
    }
}

$groups = @("reprobados", "recursadores")
foreach ($group in $groups) {
    if (-not (Get-LocalGroup -Name $group -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $group | Out-Null
    }
}

New-Item -Path $FtpRoot -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $FtpRoot "general") -ItemType Directory -Force | Out-Null
foreach ($group in $groups) {
    New-Item -Path (Join-Path $FtpRoot $group) -ItemType Directory -Force | Out-Null
}

$generalAcl = Get-Acl (Join-Path $FtpRoot "general")
$generalAcl.SetAccessRuleProtection($true, $false)
$generalAcl.Access | ForEach-Object { $generalAcl.RemoveAccessRule($_) | Out-Null }
$anonRead = New-Object System.Security.AccessControl.FileSystemAccessRule("IUSR","ReadAndExecute, ListDirectory","ContainerInherit,ObjectInherit","None","Allow")
$authWrite = New-Object System.Security.AccessControl.FileSystemAccessRule("Users","Modify","ContainerInherit,ObjectInherit","None","Allow")
$generalAcl.AddAccessRule($anonRead)
$generalAcl.AddAccessRule($authWrite)
Set-Acl -Path (Join-Path $FtpRoot "general") -AclObject $generalAcl

if (-not $PSBoundParameters.ContainsKey('UserCount')) {
    $UserCount = [int](Read-Host "Numero de usuarios a crear")
}

for ($i=1; $i -le $UserCount; $i++) {
    Write-Host "--- Usuario $i de $UserCount ---"
    $username = Read-Host "Nombre de usuario"
    $securePass = Read-Host "Contrasena" -AsSecureString
    do {
        $group = Read-Host "Grupo (reprobados/recursadores)"
    } until ($groups -contains $group)

    if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $username -Password $securePass -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
    }

    foreach ($g in $groups) {
        try { Remove-LocalGroupMember -Group $g -Member $username -ErrorAction Stop } catch {}
    }
    Add-LocalGroupMember -Group $group -Member $username

    $userDir = Join-Path $FtpRoot $username
    New-Item -Path $userDir -ItemType Directory -Force | Out-Null

    $userAcl = Get-Acl $userDir
    $userAcl.SetAccessRuleProtection($true, $false)
    $userAcl.Access | ForEach-Object { $userAcl.RemoveAccessRule($_) | Out-Null }
    $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule($username,"Modify","ContainerInherit,ObjectInherit","None","Allow")
    $adminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $userAcl.AddAccessRule($userRule)
    $userAcl.AddAccessRule($adminsRule)
    $userAcl.AddAccessRule($systemRule)
    Set-Acl -Path $userDir -AclObject $userAcl

    $groupDir = Join-Path $FtpRoot $group
    $groupAcl = Get-Acl $groupDir
    $groupAcl.SetAccessRuleProtection($true, $true)
    $groupRule = New-Object System.Security.AccessControl.FileSystemAccessRule($group,"Modify","ContainerInherit,ObjectInherit","None","Allow")
    $groupAcl.AddAccessRule($groupRule)
    Set-Acl -Path $groupDir -AclObject $groupAcl
}

if (-not (Get-WebSite -Name $SiteName -ErrorAction SilentlyContinue)) {
    New-WebFtpSite -Name $SiteName -Port 21 -PhysicalPath $FtpRoot -Force | Out-Null
}

Set-ItemProperty "IIS:\Sites\$SiteName" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
Set-ItemProperty "IIS:\Sites\$SiteName" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
Set-ItemProperty "IIS:\Sites\$SiteName" -Name ftpServer.userIsolation.mode -Value "None"
Set-ItemProperty "IIS:\Sites\$SiteName" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
Set-ItemProperty "IIS:\Sites\$SiteName" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
Set-WebConfigurationProperty -PSPath 'IIS:\' -Filter "system.applicationHost/sites/site[@name='$SiteName']/ftpServer/firewallSupport" -Name "dataChannelPortRange" -Value "$PassiveStartPort-$PassiveEndPort"

Clear-WebConfiguration -PSPath 'IIS:\' -Filter "system.ftpServer/security/authorization" -Location $SiteName -ErrorAction SilentlyContinue
Add-WebConfiguration -PSPath 'IIS:\' -Filter "system.ftpServer/security/authorization" -Location $SiteName -Value @{accessType='Allow';users='?';permissions='Read'}
Add-WebConfiguration -PSPath 'IIS:\' -Filter "system.ftpServer/security/authorization" -Location $SiteName -Value @{accessType='Allow';roles='Users';permissions='Read,Write'}
Add-WebConfiguration -PSPath 'IIS:\' -Filter "system.ftpServer/security/authorization" -Location $SiteName -Value @{accessType='Allow';roles='reprobados';permissions='Read,Write'}
Add-WebConfiguration -PSPath 'IIS:\' -Filter "system.ftpServer/security/authorization" -Location $SiteName -Value @{accessType='Allow';roles='recursadores';permissions='Read,Write'}

New-NetFirewallRule -DisplayName "FTP Control 21" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "FTP Passive Ports" -Direction Inbound -Protocol TCP -LocalPort "$PassiveStartPort-$PassiveEndPort" -Action Allow -ErrorAction SilentlyContinue | Out-Null

Restart-Service ftpsvc -Force
Write-Host "Configuracion completada en Windows."