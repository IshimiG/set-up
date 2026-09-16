#!/usr/bin/env bash
# Recordatorios propios: los que no están en ningún calendario.
#
# Se guardan en un fichero de texto y no en temporizadores de systemd creados al
# vuelo, aunque eso pareciera lo natural: los temporizadores transitorios no
# sobreviven a un reinicio, y un recordatorio para mañana a las nueve tiene que
# seguir ahí si apagas el ordenador esta noche. Quien los mira es
# notify-scheduler.sh, una vez por minuto.
#
# Cada línea del fichero es "epoch<TAB>texto".

set -uo pipefail

readonly STORE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/notificaciones"
readonly STORE="$STORE_DIR/recordatorios.tsv"

mkdir -p "$STORE_DIR"
[[ -f $STORE ]] || : >"$STORE"

# Traduce lo que se escribe a un instante concreto.
#
# Se aceptan las formas cortas que uno teclea sin pensar —"20m", "2h", "3d"— y
# las horas sueltas, que se entienden como hoy, o como mañana si esa hora ya ha
# pasado: quien escribe "9:00" a las once de la noche quiere mañana. Todo lo
# demás se le pasa tal cual a date, que entiende bastante inglés ("tomorrow
# 9am", "next monday") y las fechas ISO.
cuando_a_epoch() {
	local texto=$1 ahora
	ahora=$(date +%s)

	# Las tildes y mayúsculas sobran para comparar.
	local limpio=${texto,,}
	limpio=${limpio//mañana/tomorrow}
	limpio=${limpio//manana/tomorrow}
	limpio=${limpio//pasado tomorrow/+2 days}
	limpio=${limpio//en /}
	limpio=${limpio# }

	if [[ $limpio =~ ^([0-9]+)m(in(utos?)?)?$ ]]; then
		printf '%s\n' "$((ahora + BASH_REMATCH[1] * 60))"
		return 0
	fi
	if [[ $limpio =~ ^([0-9]+)h(oras?)?$ ]]; then
		printf '%s\n' "$((ahora + BASH_REMATCH[1] * 3600))"
		return 0
	fi
	if [[ $limpio =~ ^([0-9]+)d(ías?|ias?)?$ ]]; then
		printf '%s\n' "$((ahora + BASH_REMATCH[1] * 86400))"
		return 0
	fi

	if [[ $limpio =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
		local epoch
		epoch=$(date -d "today ${BASH_REMATCH[1]}:${BASH_REMATCH[2]}" +%s 2>/dev/null) || return 1
		(( epoch <= ahora )) && epoch=$(date -d "tomorrow ${BASH_REMATCH[1]}:${BASH_REMATCH[2]}" +%s)
		printf '%s\n' "$epoch"
		return 0
	fi

	date -d "$limpio" +%s 2>/dev/null
}

case "${1:-}" in
añadir | anadir)
	cuando=${2:-}
	texto=${3:-}
	if [[ -z $cuando || -z $texto ]]; then
		printf 'uso: %s añadir <cuándo> <texto>\n' "${0##*/}" >&2
		exit 1
	fi
	if ! epoch=$(cuando_a_epoch "$cuando") || [[ -z $epoch ]]; then
		printf 'no entiendo cuándo es "%s"\n' "$cuando" >&2
		exit 1
	fi
	# Un recordatorio en el pasado casi siempre es un error de escritura, y
	# saltaría en el siguiente minuto sin que se entienda por qué.
	if (( epoch <= $(date +%s) )); then
		printf '"%s" cae en el pasado\n' "$cuando" >&2
		exit 1
	fi
	# El texto va en una línea, así que los saltos se quedan fuera.
	printf '%s\t%s\n' "$epoch" "${texto//$'\n'/ }" >>"$STORE"
	date -d "@$epoch" '+%a %d %H:%M'
	;;
listar)
	# Ordenado por fecha, que es como se quiere leer.
	sort -n "$STORE" | while IFS=$'\t' read -r epoch texto; do
		[[ -n ${epoch:-} ]] || continue
		printf '%s\t%s\n' "$(date -d "@$epoch" '+%a %d %H:%M')" "$texto"
	done
	;;
proximos)
	# Los que vencen dentro de los próximos N segundos, sin tocarlos: el
	# planificador los usa para saber a qué hora exacta tiene que despertar.
	# Quien los borra es "vencidos", y sólo cuando ya han saltado.
	ventana=${2:-1800}
	ahora=$(date +%s)
	awk -F'\t' -v now="$ahora" -v hasta="$((ahora + ventana))" \
		'$1 != "" && $1 > now && $1 <= hasta { print $1 }' "$STORE" | sort -n
	;;
vencidos)
	# Saca los que ya tocan y los borra del fichero de una sola pasada, para
	# que no puedan saltar dos veces si el planificador se solapa consigo
	# mismo.
	ahora=$(date +%s)
	pendientes=$(awk -F'\t' -v now="$ahora" '$1 > now' "$STORE")
	awk -F'\t' -v now="$ahora" '$1 != "" && $1 <= now { print $2 }' "$STORE"
	printf '%s' "$pendientes" >"$STORE"
	[[ -s $STORE ]] && printf '\n' >>"$STORE"
	;;
*)
	printf 'uso: %s {añadir <cuándo> <texto>|listar|proximos [segundos]|vencidos}\n' "${0##*/}" >&2
	exit 1
	;;
esac
