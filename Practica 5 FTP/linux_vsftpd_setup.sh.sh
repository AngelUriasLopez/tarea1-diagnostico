#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta este script como root o con sudo."
  exit 1
fi

FTP_ROOT="/srv/ftp"
GENERAL_DIR="$FTP_ROOT/general"
GROUPS=(reprobados recursadores)
VSFTPD_CONF="/etc/vsftpd.conf"
VSFTPD_BAK="/etc/vsftpd.conf.bak.$(date +%F_%H%M%S)"

read -rp "Numero de usuarios a crear: " N
[[ "$N" =~ ^[0-9]+$ ]] || { echo "Debes ingresar un numero entero."; exit 1; }

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd acl

mkdir -p "$GENERAL_DIR"
chmod 755 "$FTP_ROOT"
chmod 775 "$GENERAL_DIR"
chown root:root "$FTP_ROOT"

for grp in "${GROUPS[@]}"; do
  getent group "$grp" >/dev/null || groupadd "$grp"
  mkdir -p "$FTP_ROOT/$grp"
  chown root:"$grp" "$FTP_ROOT/$grp"
  chmod 2775 "$FTP_ROOT/$grp"
done

for ((i=1; i<=N; i++)); do
  echo "--- Usuario $i de $N ---"
  read -rp "Nombre de usuario: " USERNAME
  while true; do
    read -rsp "Contrasena para $USERNAME: " PASS; echo
    read -rsp "Confirmar contrasena: " PASS2; echo
    [[ "$PASS" == "$PASS2" ]] && break
    echo "Las contrasenas no coinciden. Intenta de nuevo."
  done

  while true; do
    read -rp "Grupo (reprobados/recursadores): " USERGROUP
    [[ "$USERGROUP" == "reprobados" || "$USERGROUP" == "recursadores" ]] && break
    echo "Grupo invalido. Usa reprobados o recursadores."
  done

  HOME_DIR="$FTP_ROOT/$USERNAME"

  if id "$USERNAME" >/dev/null 2>&1; then
    echo "El usuario $USERNAME ya existe; se actualizara."
    usermod -d "$HOME_DIR" -s /usr/sbin/nologin -g "$USERGROUP" "$USERNAME"
  else
    useradd -d "$HOME_DIR" -s /usr/sbin/nologin -g "$USERGROUP" "$USERNAME"
  fi

  echo "$USERNAME:$PASS" | chpasswd

  mkdir -p "$HOME_DIR"
  chown "$USERNAME":"$USERGROUP" "$HOME_DIR"
  chmod 700 "$HOME_DIR"

  setfacl -m u:$USERNAME:rwx "$GENERAL_DIR"
  setfacl -m g:$USERGROUP:rwx "$FTP_ROOT/$USERGROUP"
  setfacl -m u:$USERNAME:rwx "$FTP_ROOT/$USERGROUP"
done

cp "$VSFTPD_CONF" "$VSFTPD_BAK"
cat > "$VSFTPD_CONF" <<CONF
listen=YES
listen_ipv6=NO
anonymous_enable=YES
anon_root=$FTP_ROOT
anon_world_readable_only=YES
write_enable=YES
local_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
user_sub_token=\$USER
local_root=$FTP_ROOT
hide_ids=YES
ftpd_banner=Servidor FTP academico
anon_mkdir_write_enable=NO
anon_upload_enable=NO
anon_other_write_enable=NO
CONF

systemctl enable vsftpd
systemctl restart vsftpd

cat <<INFO

Configuracion completada.
Raiz FTP: $FTP_ROOT
Acceso anonimo: solo lectura en $GENERAL_DIR
Usuarios autenticados: escritura en general, carpeta de grupo y carpeta personal.

INFO