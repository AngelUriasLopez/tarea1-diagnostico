#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/funciones_comunes.sh"

function instalar_ssh() {
    separador
    echo -e "${GREEN}[SSH] Instalando y configurando OpenSSH Server...${NC}"

    instalar_paquete "openssh-server"

    systemctl enable ssh
    systemctl start ssh

    if command -v ufw >/dev/null 2>&1; then
        ufw allow 22/tcp >/dev/null 2>&1
        ufw --force enable >/dev/null 2>&1
    fi

    separador
    echo -e "${GREEN}[SSH] Estado del servicio:${NC}"
    systemctl status ssh --no-pager
}

function mostrar_conexion() {
    local ip_interna
    ip_interna=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

    separador
    echo -e "${GREEN}[LISTO] SSH configurado correctamente.${NC}"
    echo "Conectate desde el cliente con:"
    echo "ssh angel@${ip_interna}"
}