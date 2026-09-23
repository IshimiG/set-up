#!/usr/bin/env bash
# Screenshot tool bound to SUPER+SHIFT+S in ~/.config/hypr/hyprland.lua,
# modelled on the Windows snipping shortcut.
#
# The screen is frozen first (hyprpicker -z) so menus and tooltips stay put
# while choosing. Then one slurp selection decides the size of the capture:
#   - drag a rectangle      -> exactly that region
#   - click on a window     -> that window
#   - click on empty desktop -> the whole monitor
#   - Escape / right click  -> cancel, nothing is saved
#
# The result is copied to the clipboard and saved in ~/Pictures/Screenshots.
# The notification offers "Editar", which opens it in satty to crop, draw or
# annotate; saving from satty overwrites the same file and re-copies it.

set -uo pipefail

readonly DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$DIR"

# Rectangles slurp can snap to: every window on a workspace currently shown on
# some monitor (including an open special workspace).
window_boxes() {
	local visible
	visible=$(hyprctl monitors -j | jq -c '[.[] | .activeWorkspace.id, .specialWorkspace.id]')
	hyprctl clients -j | jq -r --argjson ws "$visible" '
		.[] | select(.mapped and (.workspace.id as $id | $ws | index($id)))
		| "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

hyprpicker -r -z >/dev/null 2>&1 &
freeze=$!
sleep 0.15 # let the frozen frame appear before slurp draws over it

geometry=$(window_boxes | slurp -o -d -b '#0b0f1488' -c '#89b4faee' -s '#89b4fa22' -w 2)
status=$?

if [[ $status -ne 0 || -z "$geometry" ]]; then
	kill "$freeze" 2>/dev/null
	exit 0
fi

file="$DIR/Captura $(date '+%Y-%m-%d %H-%M-%S').png"
grim -g "$geometry" "$file"
kill "$freeze" 2>/dev/null

if [[ ! -s "$file" ]]; then
	notify-send -a Captura -u critical "Captura" "No se pudo guardar la captura"
	exit 1
fi

wl-copy --type image/png <"$file"

# notify-send -A blocks until the notification is acted on or dismissed, so
# the rest runs detached and the keybind returns immediately.
(
	action=$(notify-send -a Captura -i "$file" \
		-A editar=Editar -A carpeta="Abrir carpeta" \
		"Captura copiada" "${file##*/}")
	case "$action" in
	editar)
		satty --filename "$file" --output-filename "$file" \
			--copy-command wl-copy --init-tool crop --early-exit
		;;
	carpeta)
		xdg-open "$DIR"
		;;
	esac
) >/dev/null 2>&1 &
disown
