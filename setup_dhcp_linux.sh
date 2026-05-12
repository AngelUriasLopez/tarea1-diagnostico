#!/bin/bash
# ============================================================
#  setup_dhcp_linux.sh
#  Instala, configura y monitorea isc-dhcp-server
#  Práctica 02 - Administración de Sistemas
# ============================================================

# ---------- COLORES ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

separador() { echo -e "${YELLOW}============================================${NC}"; }

# ============================================================
# BLOQUE 1 — INSTALACIÓN IDEMPOTENTE
# ============================================================
separador
echo -e "${GREEN}[1] Verificando presencia de isc-dhcp-server...${NC}"

if dpkg -l | grep -q "isc-dhcp-server"; then
    echo -e "${GREEN}[OK] isc-dhcp-server ya está instalado. Se omite instalación.${NC}"
else
    echo -e "${YELLOW}[!] No encontrado. Instalando en modo no interactivo...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -y
    sudo apt-get install -y isc-dhcp-server
    echo -e "${GREEN}[OK] Instalación completada.${NC}"
fi

# ============================================================
# BLOQUE 2 — ENTRADA INTERACTIVA CON VALIDACIÓN IPv4
# ============================================================
separador
echo -e "${GREEN}[2] Configuración dinámica del ámbito DHCP${NC}"

validar_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octetos <<< "$ip"
        for oct in "${octetos[@]}"; do
            [[ $oct -gt 255 ]] && return 1
        done
        return 0
    fi
    return 1
}

leer_ip() {
    local mensaje=$1; local var_name=$2
    while true; do
        read -rp "$mensaje" ip_input
        if validar_ip "$ip_input"; then
            eval "$var_name='$ip_input'"
            break
        else
            echo -e "${RED}[ERROR] IP inválida. Intenta de nuevo.${NC}"
        fi
    done
}

read -rp "Nombre descriptivo del ámbito (ej. Red-Laboratorio): " SCOPE_NAME
leer_ip "IP inicial del rango (ej. 192.168.100.50): " IP_START
leer_ip "IP final del rango  (ej. 192.168.100.150): " IP_END
leer_ip "Puerta de enlace / Gateway: " GATEWAY
leer_ip "Servidor DNS: " DNS_SERVER
read -rp "Tiempo de concesión en segundos (ej. 86400 = 1 día): " LEASE_TIME

# Calcular subred (asume /24)
SUBNET=$(echo "$IP_START" | cut -d. -f1-3).0

echo ""
echo -e "${YELLOW}--- Resumen de configuración ---${NC}"
echo "  Ámbito   : $SCOPE_NAME"
echo "  Subred   : $SUBNET / 255.255.255.0"
echo "  Rango    : $IP_START  →  $IP_END"
echo "  Gateway  : $GATEWAY"
echo "  DNS      : $DNS_SERVER"
echo "  Lease    : $LEASE_TIME segundos"
read -rp "¿Confirmar y aplicar? [s/N]: " CONFIRM
[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && echo "Cancelado." && exit 0

# ============================================================
# BLOQUE 3 — ESCRITURA DE dhcpd.conf
# ============================================================
separador
echo -e "${GREEN}[3] Escribiendo /etc/dhcp/dhcpd.conf...${NC}"

sudo bash -c "cat > /etc/dhcp/dhcpd.conf" <<EOF
# Generado por setup_dhcp_linux.sh — $SCOPE_NAME
default-lease-time $LEASE_TIME;
max-lease-time $((LEASE_TIME * 2));

authoritative;

subnet $SUBNET netmask 255.255.255.0 {
    range $IP_START $IP_END;
    option routers $GATEWAY;
    option domain-name-servers $DNS_SERVER;
    option subnet-mask 255.255.255.0;
}
EOF

# Indicar interfaz de escucha
sudo sed -i 's/^INTERFACESv4=.*/INTERFACESv4="enp0s8"/' /etc/default/isc-dhcp-server

# ============================================================
# BLOQUE 4 — VALIDACIÓN Y ARRANQUE DEL SERVICIO
# ============================================================
separador
echo -e "${GREEN}[4] Validando sintaxis de dhcpd.conf...${NC}"
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERROR] Sintaxis inválida. Corrige dhcpd.conf antes de continuar.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Sintaxis válida. Reiniciando servicio...${NC}"
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

# ============================================================
# BLOQUE 5 — MÓDULO DE MONITOREO
# ============================================================
separador
echo -e "${GREEN}[5] MÓDULO DE MONITOREO${NC}"

echo ""
echo -e "${YELLOW}>> Estado del servicio:${NC}"
sudo systemctl status isc-dhcp-server --no-pager

echo ""
echo -e "${YELLOW}>> Concesiones activas (/var/lib/dhcp/dhcpd.leases):${NC}"
if [[ -s /var/lib/dhcp/dhcpd.leases ]]; then
    grep -E "lease|binding state active|hardware ethernet|client-hostname" \
        /var/lib/dhcp/dhcpd.leases | grep -A3 "^lease"
else
    echo "  (Sin concesiones activas todavía)"
fi

separador
echo -e "${GREEN}[DONE] Configuración de DHCP Linux completada.${NC}"