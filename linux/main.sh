#!/bin/bash
source "$(dirname "$0")/lib/funciones_ssh.sh"

verificar_root

echo ""
echo "==============================="
echo "   MENU PRINCIPAL - SISTEMAS   "
echo "==============================="
echo "1. Configurar SSH"
echo "2. Configurar DHCP"
echo "3. Ver estado de servicios"
echo "==============================="
read -rp "Elige una opcion: " opcion

case $opcion in
    1)
        instalar_ssh
        mostrar_conexion
    ;;
    2)
        bash "$(dirname "$0")/setup_dhcp_linux.sh"
    ;;
    3)
        separador
        echo -e "${GREEN}SSH:${NC}"
        systemctl status ssh --no-pager
        separador
        echo -e "${GREEN}DHCP:${NC}"
        systemctl status isc-dhcp-server --no-pager
    ;;
    *)
        echo -e "${RED}Opcion no valida.${NC}"
    ;;
esac