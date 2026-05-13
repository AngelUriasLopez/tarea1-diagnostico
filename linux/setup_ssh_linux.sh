#!/bin/bash
source "$(dirname "$0")/lib/funciones_ssh.sh"

verificar_root
instalar_ssh
mostrar_conexion