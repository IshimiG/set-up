#!/usr/bin/env bash
# Programa un recordatorio y confirma por el propio sistema de notificaciones.
#
# Existe para que la ventana de SUPER+R no tenga que construir una línea de
# órdenes: recibe el cuándo y el texto como dos argumentos sueltos y se encarga
# del resto, así no hay comillas que escapar con lo que el usuario acabe de
# teclear.

set -uo pipefail

readonly SCRIPTS="$HOME/.config/hypr/scripts"

cuando=${1:-}
texto=${2:-}

if [[ -z $cuando || -z $texto ]]; then
	notify-send -a "Recordatorio" -u critical "No se ha programado nada" \
		"Hacen falta el cuándo y el texto."
	exit 1
fi

if ! momento=$("$SCRIPTS/recordatorios.sh" añadir "$cuando" "$texto" 2>&1); then
	notify-send -a "Recordatorio" -u critical "No se ha programado nada" "$momento"
	exit 1
fi

# El planificador vuelve a mirar ahora mismo: si el aviso cae dentro de la
# próxima media hora hay que armarle su disparo puntual sin esperar al
# siguiente latido, que es justo el caso de "avísame en diez minutos".
"$SCRIPTS/notify-scheduler.sh" >/dev/null 2>&1 &

notify-send -a "Recordatorio" -u low "Aviso programado" "$momento · $texto"
