. "$PSScriptRoot\lib\FuncionesSSH.ps1"

if (-not (Test-IsAdmin)) {
    Write-Host "[ERROR] Ejecuta este script como Administrador." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===============================" -ForegroundColor Cyan
Write-Host "   MENU PRINCIPAL - SISTEMAS   " -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host "1. Configurar SSH"
Write-Host "2. Configurar DHCP"
Write-Host "3. Ver estado de servicios"
Write-Host "===============================" -ForegroundColor Cyan

$opcion = Read-Host "Elige una opcion"

switch ($opcion) {
    "1" {
        Install-SSHServer
        Show-ConexionInfo
    }
    "2" {
        & "$PSScriptRoot\setup_dhcp_windows.ps1"
    }
    "3" {
        Write-Separador
        Write-Host "SSH:" -ForegroundColor Green
        Get-Service sshd -ErrorAction SilentlyContinue

        Write-Separador
        Write-Host "DHCP:" -ForegroundColor Green
        Get-Service DHCPServer -ErrorAction SilentlyContinue
    }
    default {
        Write-Host "Opcion no valida." -ForegroundColor Red
    }
}