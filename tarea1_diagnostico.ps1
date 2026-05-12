Write-Host "Diagnostico del sistema"
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like "192.168.10.*"}).IPAddress
$disco = Get-PSDrive C
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "IP Interna: $ip"
Write-Host "Espacio libre: $([math]::Round($disco.Free/1GB,2)) GB"