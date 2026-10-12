#!/usr/bin/env bash
# Mando a distancia de la isla de la barra (~/.config/quickshell/bar/).
#
# La isla lleva dentro el daemon de notificaciones, así que las mismas órdenes
# que antes iban a la configuración "notifications" van ahora a "bar". Se mudó
# porque el historial tiene que crecer desde la propia campana de la barra, y
# para interpolar geometría entre las dos hace falta que sean el mismo Item, y
# por tanto el mismo proceso.
#
# Las órdenes van por el IPC de Quickshell en vez de por D-Bus: para abrir un
# panel y poner o quitar el silencio, montar una interfaz de bus propia sería
# mucho aparato. Lo usan los atajos de teclado de ~/.config/hypr/hyprland.lua.

set -uo pipefail

readonly CONFIG="bar"

call() {
	qs -c "$CONFIG" ipc call "$CONFIG" "$1" 2>/dev/null
}

case "${1:-}" in
centro)
	call toggleCenter >/dev/null
	;;
calendario)
	call toggleCalendar >/dev/null
	;;
sesion)
	call togglePower >/dev/null
	;;
silencio)
	# Ya no hace falta avisar a waybar con SIGRTMIN+10: la campana dejó de ser
	# un módulo de la barra GTK y es una propiedad del mismo proceso que la
	# dibuja, así que se entera sola.
	call toggleSilent >/dev/null
	;;
limpiar)
	call dismissAll >/dev/null
	;;
estado)
	# Sale "on" cuando el silencio está puesto. Si la isla no está levantada se
	# responde "off" en vez de nada, que es lo que menos confunde al que
	# pregunta.
	estado=$(call silentState)
	printf '%s\n' "${estado:-off}"
	;;
*)
	printf 'uso: %s {centro|calendario|sesion|silencio|limpiar|estado}\n' "${0##*/}" >&2
	exit 1
	;;
esac
