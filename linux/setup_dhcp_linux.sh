#!/bin/bash
source "$(dirname "$0")/lib/funciones_comunes.sh"

verificar_root
separador
echo -e "${GREEN}Configuracion de ISC-DHCP-SERVER${NC}"
separador

instalar_paquete "isc-dhcp-server"

leer_ip() {
    local mensaje=$1
    local valor
    while true; do
        read -rp "$mensaje: " valor
        if validar_ip "$valor"; then
            echo "$valor"
            return
        else
            echo -e "${RED}[ERROR] IP invalida. Intenta de nuevo.${NC}"
        fi
    done
}

read -rp "Nombre del ambito (ej. Red-Laboratorio): " SCOPENAME
IPSTART=$(leer_ip "IP inicial del rango (ej. 192.168.100.50)")
IPEND=$(leer_ip "IP final del rango (ej. 192.168.100.150)")
GATEWAY=$(leer_ip "Puerta de enlace / Gateway")
DNSSERVER=$(leer_ip "Servidor DNS")
read -rp "Tiempo de concesion en segundos (ej. 86400): " LEASETIME

SUBNET=$(echo "$IPSTART" | cut -d. -f1-3).0

echo
echo -e "${YELLOW}--- RESUMEN ---${NC}"
echo "Ambito   : $SCOPENAME"
echo "Subred   : $SUBNET / 255.255.255.0"
echo "Rango    : $IPSTART - $IPEND"
echo "Gateway  : $GATEWAY"
echo "DNS      : $DNSSERVER"
echo "Lease    : $LEASETIME segundos"

read -rp "Confirmar y aplicar? (s/n): " CONFIRM
if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
    echo "Cancelado."
    exit 0
fi

separador
echo -e "${GREEN}[1/5] Escribiendo /etc/dhcp/dhcpd.conf...${NC}"

cat > /etc/dhcp/dhcpd.conf <<EOF
# Generado por setup_dhcp_linux.sh - $SCOPENAME

default-lease-time $LEASETIME;
max-lease-time $((LEASETIME * 2));
authoritative;

subnet $SUBNET netmask 255.255.255.0 {
    range $IPSTART $IPEND;
    option routers $GATEWAY;
    option domain-name-servers $DNSSERVER;
    option subnet-mask 255.255.255.0;
}
EOF

separador
echo -e "${GREEN}[2/5] Configurando interfaz de escucha...${NC}"
sed -i 's/^INTERFACESv4=.*/INTERFACESv4=\"enp0s8\"/' /etc/default/isc-dhcp-server

separador
echo -e "${GREEN}[3/5] Validando sintaxis...${NC}"
dhcpd -t -cf /etc/dhcp/dhcpd.conf
if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERROR] Sintaxis invalida en /etc/dhcp/dhcpd.conf${NC}"
    exit 1
fi

separador
echo -e "${GREEN}[4/5] Reiniciando y habilitando servicio...${NC}"
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

separador
echo -e "${GREEN}[5/5] Modulo de monitoreo${NC}"
echo -e "${YELLOW}Estado del servicio:${NC}"
systemctl status isc-dhcp-server --no-pager

echo -e "${YELLOW}Concesiones activas:${NC}"
if [[ -s /var/lib/dhcp/dhcpd.leases ]]; then
    grep -E "lease|binding state active|hardware ethernet|client-hostname" /var/lib/dhcp/dhcpd.leases
else
    echo "Sin concesiones activas todavia."
fi

separador
echo -e "${GREEN}[DONE] Configuracion DHCP Linux completada.${NC}"