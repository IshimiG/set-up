#!/usr/bin/env bash
# Botón de notificaciones de la barra: campana normal, o campana tachada
# mientras el silencio está puesto.
#
# Sin intervalo: se redibuja sólo cuando le llega SIGRTMIN+10, que manda
# notify-ctl.sh al cambiar el estado. Preguntarle al daemon cada pocos
# segundos por algo que sólo cambia cuando uno lo cambia no tendría sentido.

set -uo pipefail

if [[ $(~/.config/hypr/scripts/notify-ctl.sh estado) == "on" ]]; then
	printf '{"text":"󰂛","class":"silent","tooltip":"Silencio puesto · clic para ver el historial"}\n'
else
	printf '{"text":"󰂚","class":"","tooltip":"Notificaciones · clic derecho para silenciar"}\n'
fi
