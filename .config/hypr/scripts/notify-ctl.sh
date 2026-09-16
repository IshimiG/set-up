#!/usr/bin/env bash
# Mando a distancia del daemon de notificaciones
# (~/.config/quickshell/notifications/shell.qml).
#
# El daemon expone sus órdenes por el IPC de Quickshell en vez de por D-Bus:
# para abrir un panel y poner o quitar el silencio, montar una interfaz de bus
# propia sería mucho aparato. Lo usan el atajo de teclado y el botón de la
# barra, que necesitan lo mismo.

set -uo pipefail

readonly CONFIG="notifications"

call() {
	qs -c "$CONFIG" ipc call notifications "$1" 2>/dev/null
}

case "${1:-}" in
centro)
	call toggleCenter >/dev/null
	;;
silencio)
	call toggleSilent >/dev/null
	# El botón de la barra tiene que enterarse de que la campana ha cambiado.
	pkill -RTMIN+10 waybar 2>/dev/null
	;;
limpiar)
	call dismissAll >/dev/null
	;;
estado)
	# Para el módulo de waybar: sale "on" cuando el silencio está puesto. Si
	# el daemon no está levantado, se responde "off" en vez de nada, que es
	# lo que menos confunde al que pregunta.
	estado=$(call silentState)
	printf '%s\n' "${estado:-off}"
	;;
*)
	printf 'uso: %s {centro|silencio|limpiar|estado}\n' "${0##*/}" >&2
	exit 1
	;;
esac
