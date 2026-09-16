#!/usr/bin/env bash
# Estado del botón de sesión de la barra.
#
# El botón lleva el rojo de los estados críticos al pasar el ratón por encima,
# pero mientras el menú está abierto el ratón puede estar en cualquier parte y
# el botón se apagaba, con lo que nada en la barra indicaba que el menú que se
# ve colgando de ella sale de ahí. Este script le da al módulo la clase "open",
# que el CSS pinta igual que el :hover.
#
# No hay intervalo de refresco: el módulo se redibuja sólo cuando le llega
# SIGRTMIN+9, y esa señal la mandan los dos extremos que pueden cambiar el
# estado —el interruptor power-menu.sh al abrir o cerrar desde el botón, y el
# propio menú al cerrarse con Escape o con un clic fuera—.

set -uo pipefail

readonly GLYPH="󰐥"
readonly TOOLTIP="Sesión · clic derecho para bloquear"

if qs list --all 2>/dev/null | grep -q "/powermenu/shell.qml"; then
	class="open"
else
	class=""
fi

printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$GLYPH" "$class" "$TOOLTIP"
