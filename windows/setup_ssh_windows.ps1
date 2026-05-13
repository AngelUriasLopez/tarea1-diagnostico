. "$PSScriptRoot\lib\FuncionesSSH.ps1"

if (-not (Test-IsAdmin)) {
    Write-Host "[ERROR] Ejecuta este script como Administrador." -ForegroundColor Red
    exit 1
}

Install-SSHServer
Show-ConexionInfo