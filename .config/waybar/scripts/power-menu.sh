#!/usr/bin/env bash
# Menú de sesión de la barra: bloquear, suspender, cerrar sesión, reiniciar y
# apagar. Este script sólo es el interruptor; el menú en sí vive en
# ~/.config/quickshell/powermenu/shell.qml.
#
# Antes se dibujaba con fuzzel en modo dmenu. Se cambió a Quickshell para poder
# cerrarlo con un clic fuera: fuzzel toma el teclado en exclusiva y no sabe
# cerrarse por un clic, y su modo --keyboard-focus=on-demand no sirve aquí
# porque con follow_mouse = 1 el menú se cierra en cuanto el ratón sale de él.
#
# Segundo clic en el botón: cierra el menú abierto en vez de apilar otro encima.
# La decisión se toma consultando las instancias vivas y no por el código de
# salida de "qs kill", que además del caso "no había nada que matar" también
# falla cuando el registro arrastra instancias muertas de sesiones anteriores;
# con eso un segundo clic cerraba el menú y abría otro a continuación.
#
# Se filtra por la ruta de la configuración y no por nombre de proceso porque
# el lanzador de aplicaciones es otra instancia de Quickshell y un pkill se la
# llevaría por delante.

set -uo pipefail

readonly CONFIG="powermenu"

if qs list --all 2>/dev/null | grep -q "/$CONFIG/shell.qml"; then
	qs kill -c "$CONFIG" >/dev/null 2>&1
	# El menú no llega a ejecutar su propio aviso cuando lo matan desde fuera,
	# así que el botón de la barra se apaga desde aquí.
	pkill -RTMIN+9 waybar 2>/dev/null
	exit 0
fi

# -d se desprende de la terminal, para que waybar no se quede con el proceso
# colgando mientras el menú está abierto.
exec qs -c "$CONFIG" -d
