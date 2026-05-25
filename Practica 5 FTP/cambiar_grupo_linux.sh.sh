#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta este script como root o con sudo."
  exit 1
fi

FTP_ROOT="/srv/ftp"
read -rp "Usuario a mover: " USERNAME
read -rp "Nuevo grupo (reprobados/recursadores): " NEWGROUP

[[ "$NEWGROUP" == "reprobados" || "$NEWGROUP" == "recursadores" ]] || { echo "Grupo invalido."; exit 1; }
id "$USERNAME" >/dev/null 2>&1 || { echo "El usuario no existe."; exit 1; }

usermod -g "$NEWGROUP" "$USERNAME"
chown "$USERNAME":"$NEWGROUP" "$FTP_ROOT/$USERNAME"
setfacl -m u:$USERNAME:rwx "$FTP_ROOT/$NEWGROUP"

echo "Usuario $USERNAME movido a $NEWGROUP."