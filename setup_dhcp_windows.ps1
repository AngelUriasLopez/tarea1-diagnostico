# ============================================================
#  setup_dhcp_windows.ps1
#  Instala, configura y monitorea el rol DHCP Server
#  Práctica 02 - Administración de Sistemas
# ============================================================

function Validar-IP {
    param([string]$IP)
    return ($IP -match '^(\d{1,3}\.){3}\d{1,3}$') -and
           (($IP.Split('.') | Where-Object { [int]$_ -gt 255 }).Count -eq 0)
}

function Leer-IP {
    param([string]$Mensaje)
    do {
        $ip = Read-Host $Mensaje
        if (-not (Validar-IP $ip)) {
            Write-Host "[ERROR] IP invalida. Intenta de nuevo." -ForegroundColor Red
        }
    } while (-not (Validar-IP $ip))
    return $ip
}

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "[1] Verificando rol DHCP Server..." -ForegroundColor Green

# BLOQUE 1 — INSTALACIÓN IDEMPOTENTE
$dhcpInstalado = Get-WindowsFeature -Name DHCP | Where-Object { $_.InstallState -eq "Installed" }

if ($dhcpInstalado) {
    Write-Host "[OK] El rol DHCP ya esta instalado. Se omite instalacion." -ForegroundColor Green
} else {
    Write-Host "[!] Instalando rol DHCP..." -ForegroundColor Yellow
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Write-Host "[OK] Instalacion completada." -ForegroundColor Green
}

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12" `
    -Name ConfigurationState -Value 2 -ErrorAction SilentlyContinue

# BLOQUE 2 — ENTRADA INTERACTIVA
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "[2] Configuracion dinamica del ambito DHCP" -ForegroundColor Green

$ScopeName = Read-Host "Nombre del ambito (ej. Red-Laboratorio)"
$IpStart   = Leer-IP   "IP inicial del rango (ej. 192.168.100.50)"
$IpEnd     = Leer-IP   "IP final del rango   (ej. 192.168.100.150)"
$Gateway   = Leer-IP   "Puerta de enlace / Gateway"
$DnsServer = Leer-IP   "Servidor DNS"
$LeaseTime = Read-Host "Tiempo de concesion en dias (ej. 1)"

$SubnetBase = ($IpStart -split "\.")[0..2] -join "."
$SubnetID   = "$SubnetBase.0"

Write-Host ""
Write-Host "--- Resumen ---" -ForegroundColor Yellow
Write-Host "  Ambito : $ScopeName"
Write-Host "  Subred : $SubnetID / 255.255.255.0"
Write-Host "  Rango  : $IpStart  ->  $IpEnd"
Write-Host "  Gateway: $Gateway"
Write-Host "  DNS    : $DnsServer"
Write-Host "  Lease  : $LeaseTime dia(s)"

$confirm = Read-Host "Confirmar y aplicar? [s/N]"
if ($confirm -notin @("s","S")) { Write-Host "Cancelado."; exit }

# BLOQUE 3 — CREAR ÁMBITO
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "[3] Creando ambito DHCP..." -ForegroundColor Green

$existente = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq $SubnetID }
if ($existente) {
    Write-Host "[!] Ambito existente. Eliminando para recrear..." -ForegroundColor Yellow
    Remove-DhcpServerv4Scope -ScopeId $SubnetID -Force
}

Add-DhcpServerv4Scope `
    -Name         $ScopeName `
    -StartRange   $IpStart `
    -EndRange     $IpEnd `
    -SubnetMask   "255.255.255.0" `
    -LeaseDuration ([TimeSpan]::FromDays([int]$LeaseTime)) `
    -State        Active

Set-DhcpServerv4OptionValue `
    -ScopeId   $SubnetID `
    -Router    $Gateway `
    -DnsServer $DnsServer

Write-Host "[OK] Ambito creado y opciones configuradas." -ForegroundColor Green

# BLOQUE 4 — INICIAR SERVICIO
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "[4] Iniciando servicio DHCP..." -ForegroundColor Green

Start-Service   -Name DHCPServer -ErrorAction SilentlyContinue
Set-Service     -Name DHCPServer -StartupType Automatic
Restart-Service -Name DHCPServer

# BLOQUE 5 — MONITOREO
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "[5] MODULO DE MONITOREO" -ForegroundColor Green

Write-Host ">> Estado del servicio:" -ForegroundColor Yellow
Get-Service -Name DHCPServer | Select-Object Name, Status, StartType

Write-Host ">> Ambitos configurados:" -ForegroundColor Yellow
Get-DhcpServerv4Scope | Format-Table ScopeId, Name, StartRange, EndRange, LeaseDuration, State

Write-Host ">> Concesiones activas:" -ForegroundColor Yellow
$leases = Get-DhcpServerv4Lease -ScopeId $SubnetID -ErrorAction SilentlyContinue
if ($leases) {
    $leases | Format-Table IPAddress, ClientId, HostName, AddressState, LeaseExpiryTime
} else {
    Write-Host "  (Sin concesiones activas todavia)" -ForegroundColor Gray
}

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "[DONE] Configuracion DHCP Windows completada." -ForegroundColor Green