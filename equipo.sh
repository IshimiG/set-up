#!/usr/bin/env bash
# Lo que sólo necesita la torre. Lo ejecuta setup.sh al final, con sus mismos
# argumentos (--comprobar incluido); no hace falta lanzarlo a mano.
#
# El driver de NVIDIA no va aquí: en CachyOS lo instala y lo mantiene chwd.
# Si la máquina fuese un Arch a secas, nvidia-utils hace falta para la GPU de
# la barra (nvidia-smi).

# libpulse  pactl, para el loopback del micrófono (loopback.sh y la barra)
# python  mouse-battery.py, la batería del ratón Razer en la barra
PAQUETES=(libpulse python)

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
