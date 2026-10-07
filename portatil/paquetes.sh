#!/usr/bin/env bash
# Paquetes que el setup de la torre necesita y el Omarchy del portátil no trae.
#
#   sudo ~/Projects/set-up/portatil/paquetes.sh
#
# Es el paso 1 de portatil/LEEME.md. Sólo instala: no toca ninguna
# configuración, así que se puede ejecutar cuando sea, aunque el cambio de
# escritorio todavía no se haya aplicado.
#
# El resto de lo que usan los scripts (grim, slurp, satty, hyprpicker,
# wl-clipboard, jq, libnotify, checkupdates, brightnessctl, playerctl,
# hypridle, hyprlock, nautilus, zen-browser, btop, polkit-gnome) ya lo trajo
# Omarchy; aplicar.sh lo comprueba igualmente antes de empezar.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "Con sudo: sudo $0" >&2
	exit 1
fi

# quickshell y ghostty van con el repo delante porque el repo de Omarchy trae
# su propia versión de los dos (quickshell-git, ghostty), y la torre usa las
# de extra.
#
#   quickshell    la barra, la isla, el lanzador, las notificaciones…
#   ghostty       la terminal (SUPER+RETURN, btop desde la barra)
#   hyprpaper     el fondo de pantalla
#   pavucontrol   clic en el volumen y en el loopback de la barra
#   hyprshutdown  cerrar sesión con SUPER+M y desde el panel de sesión
#   dolphin       el gestor de archivos de SUPER+E (SUPER+SHIFT+F es nautilus)
pacman -S --needed \
	extra/quickshell \
	extra/ghostty \
	hyprpaper \
	pavucontrol \
	hyprshutdown \
	dolphin

cat <<'EOF'

Listo. Opcional, y sin sudo porque viene del AUR: gcalcli, para que
notify-scheduler.sh avise de los eventos de Google Calendar.

  yay -S gcalcli && gcalcli init

Siguiente paso: ~/Projects/set-up/portatil/aplicar.sh
EOF
