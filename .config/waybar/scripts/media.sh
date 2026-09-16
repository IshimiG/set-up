#!/usr/bin/env bash
# Waybar custom/media.
#
# Emite una línea JSON cada vez que el reproductor MPRIS activo cambia de
# estado, así que el módulo reacciona al instante en vez de ser sondeado.
# `playerctl --follow` termina en cuanto desaparece el último reproductor, de
# modo que el bucle exterior lo vuelve a levantar; un "text" vacío es lo que
# hace que waybar esconda el módulo entero en lugar de dejar un hueco en la
# barra.

set -uo pipefail

SEP='@@'
readonly FORMAT="{{status}}${SEP}{{artist}}${SEP}{{title}}${SEP}{{album}}"
# Con qué reconocer a las copias viejas de este mismo script en /proc. Se usa
# el sufijo de la ruta y no el basename para no confundirlo con cualquier otro
# media.sh que pueda haber por el sistema.
readonly SELF_TAG="waybar/scripts/media.sh"

# Job control activado a propósito. Sin él los procesos en segundo plano
# comparten el grupo de procesos de waybar, y entonces no hay forma de matar el
# seguidor y su tubería de golpe sin llevarse la barra por delante. Con -m cada
# seguidor arranca en su propio grupo y basta un kill al grupo.
set -m

emit_idle() {
	printf '{"text":"","alt":"none","class":"none"}\n'
}

emit() {
	local status=$1 artist=$2 title=$3 album=$4

	if [[ -z $title ]]; then
		emit_idle
		return
	fi

	local text=$title
	[[ -n $artist ]] && text="$artist · $title"

	local alt
	case $status in
	Playing) alt=playing ;;
	Paused) alt=paused ;;
	*)
		emit_idle
		return
		;;
	esac

	local tooltip=$title
	[[ -n $artist ]] && tooltip+=$'\n'"$artist"
	[[ -n $album ]] && tooltip+=$'\n'"$album"

	jq -cn \
		--arg text "$text" \
		--arg alt "$alt" \
		--arg tooltip "$tooltip" \
		'{text: $text, alt: $alt, class: $alt, tooltip: $tooltip}'
}

# Limpieza de las copias que dejó vivas una recarga anterior de la barra.
#
# Waybar no reclama los `exec` continuos cuando se recarga: mata la barra, el
# script queda reparentado a init y la barra nueva lanza otra copia. Con dos
# monitores cada recarga deja dos parejas media.sh + playerctl colgadas para
# siempre, y no se van por su cuenta porque sólo escriben cuando cambia la
# música: sin escribir nunca llegan a recibir el SIGPIPE de la tubería cerrada.
# Medido antes de este arreglo: 21 media.sh y 19 playerctl, el más viejo con 94
# minutos, y 598 MB en 40 procesos colgando de la barra.
#
# El criterio para matar es PPID 1, que es exactamente "ya no tiene barra a la
# que escribir". Las copias de esta misma barra cuelgan del waybar vivo, así
# que las dos hermanas legítimas —una por monitor— nunca se matan entre ellas.
#
# Se recorre /proc a mano en vez de con pgrep para no lanzar procesos desde el
# arranque de un script cuyo problema es justamente la acumulación de procesos.
reap_orphans() {
	local dir pid stat rest ppid cmdline
	local -a argv

	for dir in /proc/[0-9]*; do
		pid=${dir#/proc/}
		[[ $pid == "$$" ]] && continue

		mapfile -d '' -t argv <"$dir/cmdline" 2>/dev/null || continue
		cmdline="${argv[*]}"
		case $cmdline in
		*"$SELF_TAG"* | *"$FORMAT"*) ;;
		*) continue ;;
		esac

		# El PPID es el cuarto campo de /proc/PID/stat. El segundo lleva el
		# nombre del ejecutable entre paréntesis y puede contener espacios, así
		# que se corta por el último ")" en lugar de partir por espacios desde
		# el principio.
		IFS= read -r stat <"$dir/stat" 2>/dev/null || continue
		rest=${stat##*") "}
		ppid=${rest#* }
		ppid=${ppid%% *}

		[[ $ppid == 1 ]] && kill "$pid" 2>/dev/null
	done

	return 0
}

# El seguidor va en segundo plano y el script lo espera con `wait`, en vez de
# tener la tubería en primer plano. Es lo que permite que las trampas se
# atiendan: bash no ejecuta un trap mientras un comando en primer plano está
# bloqueado, y `playerctl --follow` bloquea para siempre.
follow() {
	playerctl --follow --format "$FORMAT" metadata 2>/dev/null |
		while IFS= read -r line; do
			status=${line%%"$SEP"*}
			rest=${line#*"$SEP"}
			artist=${rest%%"$SEP"*}
			rest=${rest#*"$SEP"}
			title=${rest%%"$SEP"*}
			album=${rest#*"$SEP"}
			emit "$status" "$artist" "$title" "$album"
		done
}

follower=0

# Cuando a esta copia sí le llega la señal —un waybar que cierra bien, o el
# reaper de una copia posterior— tiene que llevarse su playerctl con ella. Sin
# esto, matar el media.sh sólo reparenta al hijo y el playerctl sobrevive.
cleanup() {
	trap - EXIT INT TERM HUP
	((follower != 0)) && kill -- "-$follower" 2>/dev/null
	exit 0
}

trap cleanup EXIT INT TERM HUP

reap_orphans

while true; do
	follow &
	follower=$!
	wait "$follower" 2>/dev/null
	follower=0

	# No queda ningún reproductor (o playerctl ha muerto): se limpia el módulo
	# y se reintenta.
	emit_idle
	sleep 2
done
