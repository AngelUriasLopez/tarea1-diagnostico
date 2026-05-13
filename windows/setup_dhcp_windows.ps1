. "$PSScriptRoot\lib\FuncionesComunes.ps1"

if (-not (Test-IsAdmin)) {
    Write-Host "[ERROR] Ejecuta este script como Administrador." -ForegroundColor Red
    exit 1
}

Write-Separador
Write-Host "Configuracion de DHCP Server en Windows" -ForegroundColor Green
Write-Separador

$dhcpFeature = Get-WindowsFeature -Name 'DHCP'
if (-not $dhcpFeature.Installed) {
    Write-Host "[INFO] Instalando rol DHCP..." -ForegroundColor Green
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
} else {
    Write-Host "[OK] El rol DHCP ya esta instalado." -ForegroundColor Yellow
}

$scopeName = Read-Host "Nombre del ambito (ej. Red-Laboratorio)"
$startRange = Read-Host "IP inicial del rango (ej. 192.168.100.50)"
$endRange = Read-Host "IP final del rango (ej. 192.168.100.150)"
$subnetMask = "255.255.255.0"
$gateway = Read-Host "Puerta de enlace / Gateway"
$dnsServer = Read-Host "Servidor DNS"
$leaseDays = Read-Host "Tiempo de concesion en dias (ej. 1)"

Write-Host ""
Write-Host "--- RESUMEN ---" -ForegroundColor Yellow
Write-Host "Ambito   : $scopeName"
Write-Host "Rango    : $startRange - $endRange"
Write-Host "Mascara  : $subnetMask"
Write-Host "Gateway  : $gateway"
Write-Host "DNS      : $dnsServer"
Write-Host "Lease    : $leaseDays dia(s)"

$confirm = Read-Host "Confirmar y aplicar? (s/n)"
if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "Cancelado."
    exit 0
}

$scopeId = ($startRange -split '\.')[0..2] -join '.'
$scopeId = "$scopeId.0"

Write-Separador
Write-Host "[1/5] Creando ambito DHCP..." -ForegroundColor Green

if (-not (Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq $scopeId })) {
    Add-DhcpServerv4Scope `
        -Name $scopeName `
        -StartRange $startRange `
        -EndRange $endRange `
        -SubnetMask $subnetMask `
        -State Active `
        -LeaseDuration (New-TimeSpan -Days $leaseDays)
} else {
    Write-Host "[OK] El ambito $scopeId ya existe." -ForegroundColor Yellow
}

Write-Separador
Write-Host "[2/5] Configurando opciones del ambito..." -ForegroundColor Green
Set-DhcpServerv4OptionValue `
    -ScopeId $scopeId `
    -Router $gateway `
    -DnsServer $dnsServer

Write-Separador
Write-Host "[3/5] Reiniciando servicio DHCP..." -ForegroundColor Green
Restart-Service DHCPServer
Set-Service -Name DHCPServer -StartupType Automatic

Write-Separador
Write-Host "[4/5] Estado del servicio..." -ForegroundColor Green
Get-Service DHCPServer

Write-Separador
Write-Host "[5/5] Concesiones activas..." -ForegroundColor Green
Get-DhcpServerv4Lease -ScopeId $scopeId -ErrorAction SilentlyContinue

Write-Separador
Write-Host "[DONE] Configuracion DHCP Windows completada." -ForegroundColor Green