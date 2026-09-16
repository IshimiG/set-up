#!/usr/bin/env bash
# El sistema de notificaciones mira el reloj aquí, y avisa por notify-send, que
# es quien habla con el daemon de ~/.config/quickshell/notifications/shell.qml.
#
# El latido es cada media hora, no cada minuto: despertar sesenta veces por hora
# para comprobar si ya toca algo es mucho gasto para lo poco que cambia. La
# precisión no se pierde por ello. En cada latido se mira también lo que va a
# tocar *dentro* de la próxima media hora y se arma un temporizador de un solo
# disparo para la hora exacta de cada cosa, así que un recordatorio para dentro
# de siete minutos sale a los siete minutos, no en el siguiente latido.
#
# Con "--ahora" no se arma nada nuevo: es como vuelve a entrar aquí cada uno de
# esos disparos puntuales.
#
# Lo lanza notificaciones.timer, en ~/.config/systemd/user/.

set -uo pipefail

readonly STORE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/notificaciones"
readonly AVISADOS="$STORE_DIR/calendario-avisados.tsv"
readonly SCRIPTS="$HOME/.config/hypr/scripts"

# Con cuánta antelación avisa de un evento del calendario.
readonly ANTELACION_MIN=${NOTIFY_LEAD_MINUTES:-10}
# Hasta dónde mira cada latido. Tiene que cubrir el hueco hasta el siguiente,
# o habría ratos ciegos entre uno y otro.
readonly VENTANA_SEG=1800

armar=true
[[ ${1:-} == "--ahora" ]] && armar=false

mkdir -p "$STORE_DIR"
[[ -f $AVISADOS ]] || : >"$AVISADOS"

ahora=$(date +%s)

# Arma un despertar de un solo disparo para dentro de tantos segundos. La
# unidad lleva la hora en el nombre, así que dos latidos que vean lo mismo no
# crean dos temporizadores: el segundo choca con el nombre y systemd-run se
# niega, que es justo lo que se quiere.
armar_disparo() {
	local delta=$1
	(( delta < 5 )) && return 0
	local unidad="notificacion-$(date -d "@$((ahora + delta))" +%Y%m%d-%H%M)"
	systemd-run --user --quiet --collect \
		--unit="$unidad" \
		--on-active="${delta}s" \
		--timer-property=AccuracySec=5s \
		"$SCRIPTS/notify-scheduler.sh" --ahora >/dev/null 2>&1 || true
}

# --- Recordatorios propios -------------------------------------------------
# Van como críticos a propósito: un recordatorio que se desvanece solo a los
# siete segundos, justo mientras mirabas a otro lado, no sirve de nada. Se
# queda hasta que lo cierres.
#
# Esto se ejecuta siempre, también en los disparos puntuales, y es además lo
# que recoge lo que venció mientras el equipo estaba apagado o suspendido.
while IFS= read -r texto; do
	[[ -n $texto ]] || continue
	notify-send -a "Recordatorio" -u critical -i "alarm-symbolic" "$texto"
done < <("$SCRIPTS/recordatorios.sh" vencidos)

# --- Google Calendar -------------------------------------------------------
# gcalcli --tsv saca una cabecera y luego una fila por evento:
#   start_date  start_time  end_date  end_time  title
# Los eventos de todo el día vienen con la hora vacía; ésos no llevan aviso
# previo, porque "empieza en 10 minutos" no significa nada para algo que dura
# el día entero.
#
# Se pide margen de sobra por delante: hace falta ver los eventos cuyo aviso
# cae dentro de la ventana, no sólo los que empiezan dentro de ella.
agenda=$(gcalcli agenda --tsv "now" "now+4hours" 2>/dev/null) || agenda=""

proximos_avisos=()

while IFS=$'\t' read -r fecha hora _ _ titulo; do
	[[ ${fecha:-} == "start_date" || -z ${fecha:-} || -z ${hora:-} ]] && continue
	[[ -n ${titulo:-} ]] || continue

	inicio=$(date -d "$fecha $hora" +%s 2>/dev/null) || continue
	aviso=$((inicio - ANTELACION_MIN * 60))

	# Lo que ya ha empezado no se avisa: llegar tarde con el aviso es peor
	# que no darlo.
	(( inicio > ahora )) || continue

	clave="$fecha $hora $titulo"
	grep -Fqx "$clave" "$AVISADOS" && continue

	if (( aviso <= ahora )); then
		faltan=$(( (inicio - ahora + 59) / 60 ))
		notify-send -a "Calendario" -u normal -i "calendar-symbolic" \
			"$titulo" "Empieza en $faltan min · ${hora:0:5}"
		printf '%s\n' "$clave" >>"$AVISADOS"
	elif (( aviso <= ahora + VENTANA_SEG )); then
		proximos_avisos+=("$((aviso - ahora))")
	fi
done <<<"$agenda"

# --- Despertares exactos ---------------------------------------------------
if [[ $armar == true ]]; then
	for delta in "${proximos_avisos[@]:-}"; do
		[[ -n $delta ]] && armar_disparo "$delta"
	done

	while IFS= read -r epoch; do
		[[ -n $epoch ]] && armar_disparo "$((epoch - ahora))"
	done < <("$SCRIPTS/recordatorios.sh" proximos "$VENTANA_SEG")
fi

# El registro de avisados sólo tiene que cubrir el día: dejarlo crecer para
# siempre sería guardar un historial que nadie va a leer.
if [[ -s $AVISADOS ]]; then
	hoy=$(date +%F)
	manana=$(date -d tomorrow +%F)
	grep -E "^($hoy|$manana) " "$AVISADOS" >"$AVISADOS.tmp" 2>/dev/null || : >"$AVISADOS.tmp"
	mv "$AVISADOS.tmp" "$AVISADOS"
fi
