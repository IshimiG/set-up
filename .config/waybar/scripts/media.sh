#!/usr/bin/env bash
# Waybar custom/media.
#
# Emits one JSON line every time the active MPRIS player changes state, so the
# module reacts instantly instead of being polled. `playerctl --follow` exits as
# soon as the last player disappears, so the outer loop restarts it; an empty
# "text" is what makes waybar hide the module altogether rather than leave a
# blank gap in the bar.

set -uo pipefail

SEP='@@'

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

while true; do
	playerctl --follow \
		--format "{{status}}${SEP}{{artist}}${SEP}{{title}}${SEP}{{album}}" \
		metadata 2>/dev/null |
		while IFS= read -r line; do
			status=${line%%"$SEP"*}
			rest=${line#*"$SEP"}
			artist=${rest%%"$SEP"*}
			rest=${rest#*"$SEP"}
			title=${rest%%"$SEP"*}
			album=${rest#*"$SEP"}
			emit "$status" "$artist" "$title" "$album"
		done

	# No player left (or playerctl died): clear the module and retry.
	emit_idle
	sleep 2
done
