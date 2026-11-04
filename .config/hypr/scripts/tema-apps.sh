#!/usr/bin/env bash
# El tema del escritorio en las aplicaciones: Ghostty, Neovim, fuzzel, foot y
# btop (ver «Temas» en el README). Lo llama tema.sh cada vez que pone un tema,
# dentro o fuera de la sesión, y setup.sh al montar la máquina.
#
#   tema-apps.sh            el tema activo (el que dice tema.sh)
#   tema-apps.sh <tema>     ese tema; si no hay ningún tema con ese nombre, default
#
# Los datos de cada tema están en .config/escritorio/temas/<tema>.conf, una
# clave=valor por línea (# empieza un comentario):
#   como              el nombre de otro tema: se usan sus datos, y nada más
#   ghostty_tema      el tema de Ghostty de base; pone lo que no se dice aquí
#                     (cursor-text, selection-foreground, si faltan)
#   fondo, texto, cursor, seleccion       #rrggbb
#   cursor_texto, seleccion_texto         #rrggbb, opcionales
#   ansi0 … ansi15    la paleta; ansi16 … ansi18, opcionales (si no, los de xterm)
#   opacidad          la de Ghostty, de 0 a 1 (y la de foot, si no hay foot_alpha)
#   desenfoque        el blur de Ghostty (0, sin; foot lo pone si es más de 0)
#   fuente            la letra de Ghostty; si no está instalada, la de default
#   nvim              el colorscheme de Neovim
#   fuzzel_<clave>    cada color de [colors] de fuzzel, rrggbbaa, en ese orden
#   foot_colores=no   foot se queda con sus colores de fábrica
#   foot_alpha        la transparencia de foot
#   btop              el tema de btop: temas/btop/<btop>.theme
#
# Con eso escribe en ${XDG_STATE_HOME:-~/.local/state}/escritorio:
#   ghostty.conf  lo carga config.ghostty al final (config-file);
#   nvim.lua      el colorscheme; lo vigila cada Neovim (lua/config/tema.lua);
#   fuzzel.ini    los [colors] de fuzzel (un include de fuzzel.ini);
#   foot.ini      los [colors-dark] de foot (un include de foot.ini);
#   btop.theme    el tema de btop (themes/escritorio.theme apunta aquí; lo
#                 enlaza setup.sh, con color_theme = "escritorio").
# Cada fichero se escribe de una vez (un temporal que se renombra encima) y
# sólo si cambia: repetirlo no toca nada. Lo que cambie se avisa a lo que está
# abierto: Ghostty y btop recargan su configuración con SIGUSR2. Se manda sólo
# a los procesos de este usuario con este mismo HOME que la atrapan (a uno que
# no la atrape lo mataría), y sólo si el estado es ~/.local/state/escritorio,
# que es el que leen sus configuraciones. Neovim se entera solo; fuzzel lo lee
# cada vez que se abre, y foot, al abrir una ventana. TEMA_APPS_RECARGAR=0 no
# avisa a nadie.

set -uo pipefail

aqui=$(dirname "$(readlink -f "$0")")
readonly TEMAS_DIR=$(readlink -f "$aqui/../../escritorio/temas")
readonly DIR="${XDG_STATE_HOME:-$HOME/.local/state}/escritorio"
# Los colores 16 a 18 de xterm, para los temas que no los cambian: default (los
# de caelestia) sí los cambia, y al pasar a otro tema tienen que volver.
readonly XTERM=([16]="#000000" [17]="#00005f" [18]="#000087")

error() {
	echo "tema-apps.sh: $*" >&2
}

# --- Los datos ----------------------------------------------------------------

declare -A T=()
orden=()

# Lee un fichero de tema en T (y el orden de las claves en `orden`).
cargar() {
	local linea n=0
	T=()
	orden=()
	if [[ ! -r $1 ]]; then
		error "no puedo leer $1"
		return 1
	fi
	while IFS= read -r linea || [[ -n $linea ]]; do
		n=$((n + 1))
		linea=${linea%$'\r'}
		[[ $linea =~ ^[[:space:]]*(#|$) ]] && continue
		if [[ $linea =~ ^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$ ]]; then
			[[ -v T[${BASH_REMATCH[1]}] ]] || orden+=("${BASH_REMATCH[1]}")
			T[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
		else
			error "${1##*/}:$n: no es clave=valor: $linea"
			return 1
		fi
	done <"$1"
}

# Comprueba que el tema tiene todo y bien escrito.
validar() {
	local k malas=()
	local obligatorias=(ghostty_tema fondo texto cursor seleccion opacidad desenfoque fuente nvim btop)
	for k in {0..15}; do obligatorias+=("ansi$k"); done
	for k in "${obligatorias[@]}"; do
		[[ -n ${T[$k]:-} ]] || malas+=("falta $k")
	done
	for k in fondo texto cursor seleccion cursor_texto seleccion_texto ansi{0..18}; do
		[[ -z ${T[$k]:-} || ${T[$k]} =~ ^#[0-9a-fA-F]{6}$ ]] || malas+=("$k no es #rrggbb")
	done
	for k in "${orden[@]}"; do
		[[ $k != fuzzel_* || ${T[$k]} =~ ^[0-9a-fA-F]{8}$ ]] || malas+=("$k no es rrggbbaa")
	done
	[[ -z ${T[opacidad]:-} || ${T[opacidad]} =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] || malas+=("opacidad no va de 0 a 1")
	[[ -z ${T[foot_alpha]:-} || ${T[foot_alpha]} =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] || malas+=("foot_alpha no va de 0 a 1")
	[[ -z ${T[desenfoque]:-} || ${T[desenfoque]} =~ ^[0-9]+$ ]] || malas+=("desenfoque no es un número")
	[[ -z ${T[nvim]:-} || ${T[nvim]} =~ ^[A-Za-z0-9_.-]+$ ]] || malas+=("nvim no es un nombre de colorscheme")
	[[ -z ${T[btop]:-} || -r $TEMAS_DIR/btop/${T[btop]}.theme ]] || malas+=("no hay btop/${T[btop]}.theme")
	if ((${#malas[@]})); then
		local IFS=','
		error "${1##*/}: ${malas[*]}"
		return 1
	fi
}

# Si la letra está instalada (sin fontconfig no se sabe, y se da por buena).
instalada() {
	command -v fc-list >/dev/null || return 0
	local patron
	patron=$(printf '%s' "$1" | sed 's/[-:,\\]/\\&/g')
	[[ -n $(fc-list ":family=$patron" family 2>/dev/null) ]]
}

# --- Lo que se escribe --------------------------------------------------------

cabecera() { # $1: el carácter de comentario
	echo "$1 Lo escribe ~/.config/hypr/scripts/tema-apps.sh con .config/escritorio/temas/$origen.conf."
	echo "$1 No se edita a mano: se rehace cada vez que se cambia de tema."
}

ghostty_conf() {
	local i
	cabecera "#"
	echo "# Lo carga config.ghostty al final, así que manda sobre lo de allí."
	echo "theme = ${T[ghostty_tema]}"
	echo "background = ${T[fondo]}"
	echo "foreground = ${T[texto]}"
	echo "cursor-color = ${T[cursor]}"
	if [[ -n ${T[cursor_texto]:-} ]]; then echo "cursor-text = ${T[cursor_texto]}"; fi
	echo "selection-background = ${T[seleccion]}"
	if [[ -n ${T[seleccion_texto]:-} ]]; then echo "selection-foreground = ${T[seleccion_texto]}"; fi
	for i in {0..18}; do
		echo "palette = $i=${T[ansi$i]:-${XTERM[$i]:-}}"
	done
	# Vaciar la lista primero: si no, la letra se añade como reserva de la de
	# config.ghostty en lugar de cambiarla.
	echo 'font-family = ""'
	echo "font-family = $fuente"
	echo "background-opacity = ${T[opacidad]}"
	echo "background-blur-radius = ${T[desenfoque]}"
}

nvim_lua() {
	cabecera "--"
	echo "-- Lo vigila ~/.config/nvim/lua/config/tema.lua en cada Neovim abierto."
	echo "return { colorscheme = \"${T[nvim]}\" }"
}

fuzzel_ini() {
	local k
	cabecera "#"
	echo "# Lo incluye ~/.config/fuzzel/fuzzel.ini."
	echo "[colors]"
	for k in "${orden[@]}"; do
		if [[ $k == fuzzel_* ]]; then echo "${k#fuzzel_}=${T[$k]}"; fi
	done
}

foot_ini() {
	local i sel=${T[seleccion_texto]:-${T[texto]}} ct=${T[cursor_texto]:-${T[fondo]}}
	cabecera "#"
	echo "# Lo incluye ~/.config/foot/foot.ini, al final."
	echo "[colors-dark]"
	echo "alpha=${T[foot_alpha]:-${T[opacidad]}}"
	if ((10#${T[desenfoque]} > 0)); then echo "blur=yes"; else echo "blur=no"; fi
	if [[ ${T[foot_colores]:-si} == no ]]; then
		return 0
	fi
	echo "foreground=${T[texto]#\#}"
	echo "background=${T[fondo]#\#}"
	for i in {0..7}; do echo "regular$i=${T[ansi$i]#\#}"; done
	for i in {0..7}; do echo "bright$i=${T[ansi$((i + 8))]#\#}"; done
	for i in 16 17 18; do
		if [[ -n ${T[ansi$i]:-} ]]; then echo "$i=${T[ansi$i]#\#}"; fi
	done
	echo "selection-foreground=${sel#\#}"
	echo "selection-background=${T[seleccion]#\#}"
	echo "cursor=${ct#\#} ${T[cursor]#\#}"
}

btop_theme() {
	cabecera "#"
	echo "# ~/.config/btop/themes/escritorio.theme apunta aquí (color_theme = \"escritorio\")."
	echo
	cat "$TEMAS_DIR/btop/${T[btop]}.theme"
}

cambiados=()

# Escribe lo que entra por la entrada en $DIR/$1, de una vez y sólo si cambia.
escribir() {
	local destino=$DIR/$1 tmp
	tmp=$(mktemp "$DIR/.$1.XXXXXX") || return 1
	if ! cat >"$tmp"; then
		rm -f "$tmp"
		return 1
	fi
	if cmp -s "$tmp" "$destino"; then
		rm -f "$tmp"
		return 0
	fi
	if ! chmod 644 "$tmp" || ! mv -f "$tmp" "$destino"; then
		rm -f "$tmp"
		error "no se pudo escribir $destino"
		return 1
	fi
	cambiados+=("$1")
}

# --- Avisar a lo que está abierto ---------------------------------------------

# Manda SIGUSR2 a los procesos $1 de este usuario y este HOME que la atrapan.
recargar() {
	local pid mascara home
	[[ ${TEMA_APPS_RECARGAR:-1} != 0 ]] || return 0
	[[ $(readlink -f "$DIR") == "$(readlink -f "$HOME/.local/state/escritorio")" ]] || return 0
	for pid in $(pgrep -u "$(id -u)" -x "$1" 2>/dev/null); do
		mascara=$(sed -n 's/^SigCgt:[[:space:]]*//p' "/proc/$pid/status" 2>/dev/null)
		[[ $mascara =~ ^[0-9a-fA-F]+$ ]] || continue
		(((16#$mascara >> 11) & 1)) || continue # SIGUSR2 es la 12
		home=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^HOME=//p')
		[[ $home == "$HOME" ]] || continue
		kill -USR2 "$pid" 2>/dev/null
	done
}

# --- Todo junto ---------------------------------------------------------------

tema=${1:-}
[[ -n $tema ]] || tema=$("$aqui/tema.sh")
if [[ ! $tema =~ ^[A-Za-z0-9_-]+$ || ! -f $TEMAS_DIR/$tema.conf ]]; then
	error "no hay ningún tema «$tema»; pongo default"
	tema=default
fi

cargar "$TEMAS_DIR/$tema.conf" || exit 1
origen=$tema
if [[ -n ${T[como]:-} ]]; then
	origen=${T[como]}
	if [[ ! $origen =~ ^[A-Za-z0-9_-]+$ || ! -f $TEMAS_DIR/$origen.conf ]]; then
		error "$tema.conf: como=$origen, y no hay ningún tema «$origen»"
		exit 1
	fi
	cargar "$TEMAS_DIR/$origen.conf" || exit 1
	if [[ -n ${T[como]:-} ]]; then
		error "$origen.conf: un tema con «como» no puede ser el «como» de otro"
		exit 1
	fi
fi
validar "$TEMAS_DIR/$origen.conf" || exit 1

fuente=${T[fuente]}
if ! instalada "$fuente"; then
	reserva=$(sed -n 's/^fuente=//p' "$TEMAS_DIR/default.conf")
	error "la letra «$fuente» no está instalada; Ghostty va con «$reserva»"
	fuente=$reserva
fi

mkdir -p "$DIR" || exit 1
# Con < <(…) y no con una tubería: escribir tiene que ir en este mismo shell
# para apuntar lo que cambia.
escribir ghostty.conf < <(ghostty_conf) || exit 1
escribir nvim.lua < <(nvim_lua) || exit 1
escribir fuzzel.ini < <(fuzzel_ini) || exit 1
escribir foot.ini < <(foot_ini) || exit 1
escribir btop.theme < <(btop_theme) || exit 1

for f in "${cambiados[@]}"; do
	case $f in
	ghostty.conf) recargar ghostty ;;
	btop.theme) recargar btop ;;
	esac
done
((${#cambiados[@]})) && echo "  aplicaciones ($tema): ${cambiados[*]}"
exit 0
