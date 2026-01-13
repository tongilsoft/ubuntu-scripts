
#!/usr/bin/env bash
# instalar_rdp_ubuntu24.sh
# Instala XFCE + xrdp y configura todo para RDP en Ubuntu 24.04 (EC2).
# Uso:
#   sudo bash instalar_rdp_ubuntu24.sh
# Opcional (automatizar password y UFW):
#   XRDP_USER=ubuntu XRDP_PASSWORD='TuPass' UFW_ALLOW_RDP=1 sudo -E bash instalar_rdp_ubuntu24.sh

set -euo pipefail

RED="$(tput setaf 1 || true)"; GREEN="$(tput setaf 2 || true)"; YELLOW="$(tput setaf 3 || true)"; RESET="$(tput sgr0 || true)"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "${RED}Este script debe ejecutarse como root (usa: sudo bash instalar_rdp_ubuntu24.sh).${RESET}"
    exit 1
  fi
}

check_ubuntu_24() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != 24.* ]]; then
      echo "${YELLOW}Advertencia: Este script está pensado para Ubuntu 24.x. Detectado: ${PRETTY_NAME:-desconocido}.${RESET}"
    fi
  fi
}

apt_install() {
  echo "${GREEN}Actualizando paquetes e instalando dependencias...${RESET}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    xfce4 xfce4-goodies \
    xrdp dbus-x11 \
    xorgxrdp \
    curl ca-certificates
}

configure_xrdp() {
  echo "${GREEN}Habilitando y arrancando xrdp...${RESET}"
  systemctl enable xrdp
  systemctl restart xrdp

  # Permiso del certificado snakeoil para TLS del xrdp
  echo "${GREEN}Ajustando grupo ssl-cert para xrdp...${RESET}"
  adduser xrdp ssl-cert >/dev/null 2>&1 || true

  # Sesión por defecto XFCE para nuevos usuarios
  if [[ ! -f /etc/skel/.xsession ]]; then
    echo "startxfce4" > /etc/skel/.xsession
  fi

  # Si existe usuario 'ubuntu', crear su .xsession si no existe
  if id ubuntu >/dev/null 2>&1; then
    if [[ ! -f /home/ubuntu/.xsession ]]; then
      echo "startxfce4" > /home/ubuntu/.xsession
      chown ubuntu:ubuntu /home/ubuntu/.xsession
    fi
  fi

  # Opcional: pequeños ajustes en xrdp.ini (más compatibilidad)
  XRDP_INI="/etc/xrdp/xrdp.ini"
  if [[ -f "$XRDP_INI" ]]; then
    sed -i 's/^#*security_layer=.*/security_layer=negotiate/' "$XRDP_INI"
    sed -i 's/^#*crypt_level=.*/crypt_level=high/' "$XRDP_INI"
    sed -i 's/^#*max_bpp=.*/max_bpp=24/' "$XRDP_INI"
  fi

  systemctl restart xrdp
}

maybe_open_ufw() {
  local allow="${UFW_ALLOW_RDP:-0}"
  if command -v ufw >/dev/null 2>&1; then
    local status
    status=$(ufw status | head -n1 || true)
    if [[ "$allow" == "1" ]]; then
      echo "${YELLOW}Abriendo puerto 3389 en UFW (RDP)...${RESET}"
      ufw allow 3389/tcp || true
    else
      echo "${YELLOW}UFW detectado (${status}). No se abrirá 3389 automáticamente.${RESET}"
      echo "${YELLOW}Recomendado: mantener 3389 cerrado y usar túnel SSH.${RESET}"
    fi
  fi
}

maybe_set_password() {
  local user="${XRDP_USER:-}"
  local pass="${XRDP_PASSWORD:-}"

  if [[ -n "$user" && -n "$pass" ]]; then
    if id "$user" >/dev/null 2>&1; then
      echo "${user}:${pass}" | chpasswd
      echo "${GREEN}Password establecido para el usuario '${user}'.${RESET}"
    else
      echo "${RED}El usuario '${user}' no existe. Omite el paso de password.${RESET}"
    fi
  else
    echo "${YELLOW}No se estableció password vía variables. Recuerda ejecutar: sudo passwd <tu_usuario>${RESET}"
  fi
}

post_info() {
  echo
  echo "${GREEN}✅ Instalación y configuración de RDP completadas.${RESET}"
  echo
  echo "Siguientes pasos:"
  echo "1) Establece/recuerda el password de tu usuario (ej.: 'ubuntu'):"
  echo "   ${YELLOW}sudo passwd ubuntu${RESET}"
  echo "2) Seguridad recomendada: NO abras el puerto 3389 en el Security Group."
  echo "   En su lugar, crea un túnel SSH desde tu PC y conéctate a 127.0.0.1:13389."
  echo "3) Verifica que xrdp escuche localmente:"
  echo "   ${YELLOW}sudo ss -tulpn | grep 3389${RESET}"
}

main() {
  require_root
  check_ubuntu_24
  apt_install
  configure_xrdp
  maybe_open_ufw
  maybe_set_password
  post_info
}

main "$@"

