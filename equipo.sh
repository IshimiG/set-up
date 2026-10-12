#!/usr/bin/env bash
# Lo que sólo necesita un portátil. Lo ejecuta setup.sh al final, con sus
# mismos argumentos (--comprobar incluido); no hace falta lanzarlo a mano.
#
# Vale para cualquier portátil de esta rama, no sólo para ishimiPort: los
# monitores los escribe nwg-displays en cada uno (~/.config/hypr/monitors.lua,
# fuera del repo) y la barra enseña la wifi y la batería si las hay.

# hypridle  atenuar, bloquear y apagar la pantalla en reposo (equipo.lua)
# iwd, impala  la wifi de la barra habla con iwd; impala, en el clic derecho
# nwg-displays  colocar los monitores, sobre todo al enchufar uno externo
# polkit-gnome  el agente de polkit (equipo.lua lo arranca)
# brightnessctl  las teclas de brillo
# upower  la batería de la barra
PAQUETES=(hypridle iwd impala nwg-displays polkit-gnome brightnessctl upower)

set -uo pipefail

comprobar=false
[[ ${1:-} == --comprobar ]] && comprobar=true

aviso() { printf '\033[33m%s\033[0m\n' "$*"; }
hacer() {
	if $comprobar; then
		echo "  haría: $*"
	else
		"$@"
	fi
}

mapfile -t faltan < <(pacman -T "${PAQUETES[@]}")
if ((${#faltan[@]})); then
	echo "  faltan: ${faltan[*]}"
	hacer sudo pacman -S --needed "${faltan[@]}"
else
	echo "  todo instalado"
fi

# La wifi de la barra va contra iwd. Si la máquina usa NetworkManager, no se
# activa: los dos a la vez se pelean por la tarjeta.
if systemctl is-active --quiet NetworkManager; then
	aviso "  NetworkManager está activo: la wifi de la barra necesita iwd; no lo activo"
elif systemctl is-enabled --quiet iwd; then
	echo "  iwd ya activo"
else
	hacer sudo systemctl enable --now iwd
fi
