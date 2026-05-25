param(
    [Parameter(Mandatory=$true)][string]$Username,
    [Parameter(Mandatory=$true)][ValidateSet('reprobados','recursadores')][string]$NewGroup
)

$groups = @('reprobados','recursadores')
foreach ($g in $groups) {
    try { Remove-LocalGroupMember -Group $g -Member $Username -ErrorAction Stop } catch {}
}
Add-LocalGroupMember -Group $NewGroup -Member $Username
Write-Host "Usuario $Username movido a $NewGroup"