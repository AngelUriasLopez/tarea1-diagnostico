#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Debes ejecutar este script como root o con sudo.${NC}"
        exit 1
    fi
}

function instalar_paquete() {
    local paquete="$1"

    if dpkg -s "$paquete" >/dev/null 2>&1; then
        echo -e "${YELLOW}[OK] El paquete '$paquete' ya está instalado.${NC}"
    else
        echo -e "${GREEN}[INFO] Instalando paquete '$paquete'...${NC}"
        apt-get update -y
        apt-get install -y "$paquete"
    fi
}

function validar_ip() {
    local ip="$1"

    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 1
    fi

    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

    for octeto in "$o1" "$o2" "$o3" "$o4"; do
        if (( octeto < 0 || octeto > 255 )); then
            return 1
        fi
    done

    return 0
}

function separador() {
    echo -e "${YELLOW}-------------------------------------------${NC}"
}