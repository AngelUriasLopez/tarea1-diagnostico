#!/bin/bash
echo "Diagnostico del sistema"
echo "Hostname: $(hostname)"
echo "IP Interna: $(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
echo "Espacio en disco: $(df -h / | awk 'NR==2 {print $4, "disponibles de", $2}')"