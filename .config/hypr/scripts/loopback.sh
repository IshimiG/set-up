#!/usr/bin/env bash
# Loopback de micrófono → auriculares, portado de la extensión de GNOME Shell
# (loopback-toggle@ishimimain) a Hyprland.
#
# El estado vive en el mismo esquema GSettings que usaban la extensión y la app
# GTK3, así que las tres herramientas siguen compartiendo dispositivos, volumen
# y el on/off: cambiar el micro en la app se nota aquí sin tocar nada.
#
# La regla de oro heredada del diagnóstico del "sonido metálico": NUNCA puede
# haber dos module-loopback cargados a la vez. Dos copias de la misma señal con
# latencias distintas se suman desfasadas y producen comb filtering. Por eso
# cada arranque descarga todo lo que haya antes de cargar lo suyo.

set -uo pipefail

SCHEMA_DIR="$HOME/.local/share/glib-2.0/schemas"
SCHEMA="org.gnome.shell.extensions.loopback-toggle"
LATENCY_MSEC=25
VOLUME_STEP=0.05
VOLUME_MAX=2.0

gget() {
	gsettings --schemadir "$SCHEMA_DIR" get "$SCHEMA" "$1" 2>/dev/null |
		sed "s/^'//;s/'\$//"
}

gset() {
	gsettings --schemadir "$SCHEMA_DIR" set "$SCHEMA" "$1" "$2" 2>/dev/null
}

# Los valores guardados pueden ser el nombre PulseAudio o la descripción legible
# ("Yeti Stereo Microphone Analog Stereo"), según qué herramienta los escribió.
# Aceptamos ambos y devolvemos siempre el nombre canónico.
resolve_device() {
	local kind=$1 want=$2
	[[ -z $want ]] && return 0

	pactl list "$kind" 2>/dev/null | awk -v want="$want" '
		/^(Sink|Source) #/ { name = ""; desc = "" }
		/^[ \t]*Name: / { name = $2 }
		/^[ \t]*Description: / {
			sub(/^[ \t]*Description: /, "")
			desc = $0
		}
		name != "" && desc != "" && (name == want || desc == want) {
			print name
			exit
		}
	'
}

loopback_modules() {
	pactl list modules short 2>/dev/null | awk -F'\t' '$2 == "module-loopback" { print $1 }'
}

unload_all() {
	local mod
	for mod in $(loopback_modules); do
		pactl unload-module "$mod" >/dev/null 2>&1
	done
}

volume_pct() {
	awk -v v="$(gget volume)" 'BEGIN { printf "%d", v * 100 + 0.5 }'
}

# El volumen no se aplica al módulo sino al sink-input que el módulo crea, que
# es lo que pactl sabe atenuar. Se localiza por su Owner Module.
apply_volume() {
	local mod=$1 input
	input=$(pactl list sink-inputs 2>/dev/null | awk -v mod="$mod" '
		/^Sink Input #/ { id = substr($0, index($0, "#") + 1) }
		$1 == "Owner" && $2 == "Module:" && $3 == mod { print id; exit }
	')
	[[ -n $input ]] && pactl set-sink-input-volume "$input" "$(volume_pct)%" >/dev/null 2>&1
}

start() {
	local src sink mod
	src=$(resolve_device sources "$(gget source)")
	sink=$(resolve_device sinks "$(gget sink)")

	if [[ -z $src || -z $sink ]]; then
		notify-send -a Loopback "Loopback de micrófono" \
			"No hay micrófono o salida configurados.\nÁbrelo con la app «Loopback de micrófono»." 2>/dev/null
		return 1
	fi

	unload_all
	mod=$(pactl load-module module-loopback \
		source="$src" sink="$sink" latency_msec="$LATENCY_MSEC" 2>/dev/null) || return 1

	apply_volume "$mod"
}

is_active() {
	[[ -n $(loopback_modules) ]]
}

# Si esta máquina tiene el esquema GSettings de la extensión (la torre sí; el
# portátil, que nunca tuvo GNOME, no). Sin él no hay dispositivos guardados ni
# nada que encender.
configurado() {
	gsettings --schemadir "$SCHEMA_DIR" list-keys "$SCHEMA" >/dev/null 2>&1
}

cmd_on() {
	start && gset loopback-enabled true
}

cmd_off() {
	unload_all
	gset loopback-enabled false
}

cmd_toggle() {
	if is_active; then
		cmd_off
	else
		cmd_on
	fi
}

# Al arrancar la sesión: reponer el loopback sólo si estaba encendido. Cargar a
# ciegas era justo lo que generaba el módulo duplicado en el setup de GNOME.
cmd_restore() {
	unload_all
	[[ $(gget loopback-enabled) == true ]] && start
}

cmd_volume() {
	local delta=$1 new mod
	new=$(awk -v v="$(gget volume)" -v d="$delta" -v max="$VOLUME_MAX" 'BEGIN {
		r = v + d
		if (r < 0) r = 0
		if (r > max) r = max
		printf "%.2f", r
	}')
	gset volume "$new"

	for mod in $(loopback_modules); do
		apply_volume "$mod"
	done
}

cmd_status() {
	if is_active; then
		echo "activo · $(gget source) → $(gget sink) · $(volume_pct)%"
	else
		echo "inactivo"
	fi
}

# Estado en JSON para la barra (~/.config/quickshell/bar/Telemetry.qml). El
# módulo se queda siempre visible, atenuado cuando está apagado, porque si se
# ocultara no habría dónde hacer clic para encenderlo.
#
# Antes este subcomando se llamaba "waybar" y además mandaba SIGRTMIN+8 para que
# la barra se redibujara al instante. Las dos cosas se fueron con ella: la barra
# de Quickshell se entera de los cambios de fuera por su suscripción a
# `pactl subscribe`, y de los suyos propios porque es quien los provoca.
cmd_json() {
	local state icon tooltip
	# "none" esconde el módulo de la barra. Si hay un module-loopback cargado
	# se enseña igualmente, aunque no lo haya puesto este script.
	if ! configurado && ! is_active; then
		jq -cn '{text: "", alt: "none", class: "none", tooltip: ""}'
		return
	fi
	if is_active; then
		state=on
		icon="󰍬"
		tooltip="Loopback activo · $(volume_pct)%"$'\n'"$(gget source)"$'\n'"→ $(gget sink)"
	else
		state=off
		icon="󰍭"
		tooltip="Loopback apagado"$'\n'"Clic para escucharte por los auriculares"
	fi

	jq -cn \
		--arg text "$icon" \
		--arg state "$state" \
		--arg tooltip "$tooltip" \
		'{text: $text, alt: $state, class: $state, tooltip: $tooltip}'
}

case "${1:-status}" in
on) cmd_on ;;
off) cmd_off ;;
toggle) cmd_toggle ;;
restore) cmd_restore ;;
up) cmd_volume "$VOLUME_STEP" ;;
down) cmd_volume "-$VOLUME_STEP" ;;
status) cmd_status ;;
json) cmd_json ;;
*)
	echo "uso: ${0##*/} {on|off|toggle|restore|up|down|status|json}" >&2
	exit 1
	;;
esac
