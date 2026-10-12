#!/usr/bin/env bash
# Esconder y sacar la barra, con SUPER+SHIFT+V.
#
# Ya no hay procesos que matar. Cuando la barra era waybar había que matarla y
# volver a lanzarla para que Hyprland animara la desaparición de su superficie;
# ahora la barra son cuatro superficies de un mismo Quickshell —los escritorios,
# la isla, la telemetría y la franja que reserva el hueco— y esconderse es una
# propiedad que anima el cristal hacia arriba. Esto sólo se lo pide.
#
# Queda como script y no como una llamada suelta en el atajo de teclado porque
# así el mando sigue siendo el mismo para el teclado y para cualquier otra cosa
# que quiera esconder la barra.

set -uo pipefail

readonly CONFIG="bar"

qs -c "$CONFIG" ipc call "$CONFIG" toggleBar >/dev/null 2>&1

exit 0
