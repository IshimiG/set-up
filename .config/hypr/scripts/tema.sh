#!/usr/bin/env bash
# El tema del escritorio (ver «Temas» en el README).
#
#   tema.sh              dice el tema activo
#   tema.sh lista        los temas que hay, uno por línea; el activo, con *
#   tema.sh <tema>       pone ese tema (uno de los de `lista`)
#   tema.sh alternar     pasa al siguiente de la lista (SUPER+SHIFT+CTRL+T)
#
# El tema es una palabra en ${XDG_STATE_HOME:-~/.local/state}/escritorio/tema,
# de cada máquina y fuera del repo. Se escribe de una vez (un temporal que se
# renombra encima), así que quien lo vigila nunca lo lee a medias. Lo leen:
#   - la paleta de Quickshell (quickshell/shared/Theme.qml), que lo vigila y
#     repinta la barra, el cajón y lo demás en caliente;
#   - hyprland.lua, al cargar: por eso, dentro de una sesión de Hyprland, este
#     script hace "hyprctl reload config-only" después de escribirlo, y para o
#     arranca la aberración cromática del borde (scripts/aberracion.sh);
#   - tema-apps.sh, al que llama siempre, dentro o fuera de la sesión: escribe
#     al lado lo de Ghostty, Neovim, fuzzel, foot y btop, y avisa a los que
#     están abiertos (ver ese script).
# Fuera de una sesión (sin HYPRLAND_INSTANCE_SIGNATURE) escribe el estado y lo
# de las aplicaciones, y lo de Hyprland vale al entrar; así se prueba
# (pruebas/temas/prueba.sh).
#
# Poner el tema que ya está no rompe nada: no reescribe el fichero y vuelve a
# aplicarlo en Hyprland. Si falta el fichero o dice algo que no es un tema, el
# activo es default, igual que para Theme.qml y hyprland.lua.

set -uo pipefail

# Los temas, en orden: el de `lista` y el de `alternar`. Un tema nuevo va aquí,
# en las paletas de Theme.qml, en la tabla `temas` de hyprland.lua y en
# .config/escritorio/temas/<tema>.conf (lo de las aplicaciones).
readonly TEMAS=(default liquido catppuccin tokyonight gruvbox kanagawa phosphor)

readonly DIR="${XDG_STATE_HOME:-$HOME/.local/state}/escritorio"
readonly FICHERO="$DIR/tema"
aqui=$(dirname "$(readlink -f "$0")")

es_tema() {
	local t
	for t in "${TEMAS[@]}"; do
		[[ $1 == "$t" ]] && return 0
	done
	return 1
}

# Lo que dice el fichero, sin blancos (vacío si no hay fichero).
leido() {
	[[ -r $FICHERO ]] && tr -d '[:space:]' <"$FICHERO"
}

actual() {
	local t
	t=$(leido)
	if es_tema "$t"; then
		printf '%s\n' "$t"
	else
		echo default
	fi
}

en_sesion() {
	[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null
}

# Ghostty, Neovim, fuzzel, foot y btop, dentro o fuera de la sesión. Si falla,
# el tema del escritorio queda puesto igual.
aplicaciones() {
	"$aqui/tema-apps.sh" "$1" ||
		echo "tema.sh: tema-apps.sh ha fallado; las aplicaciones siguen con el tema de antes" >&2
}

poner() {
	local nuevo=$1 carpeta_nueva=false tmp
	if ! es_tema "$nuevo"; then
		echo "tema.sh: no hay ningún tema «$nuevo» (hay: ${TEMAS[*]})" >&2
		exit 1
	fi

	if [[ ! -d $DIR ]]; then
		mkdir -p "$DIR" || exit 1
		carpeta_nueva=true
	fi
	if [[ $(leido) != "$nuevo" ]]; then
		tmp=$(mktemp "$DIR/.tema.XXXXXX") || exit 1
		if ! printf '%s\n' "$nuevo" >"$tmp" || ! chmod 644 "$tmp" || ! mv -f "$tmp" "$FICHERO"; then
			rm -f "$tmp"
			echo "tema.sh: no se pudo escribir $FICHERO" >&2
			exit 1
		fi
	fi
	echo "Tema: $nuevo"

	if ! en_sesion; then
		aplicaciones "$nuevo"
		echo "  (sin sesión de Hyprland: se aplica al entrar)"
		return
	fi

	# La aberración se para antes de recargar (deja el borde normal del tema
	# que se va) y se vuelve a arrancar después: el propio aberracion.sh sale
	# sin hacer nada si el tema nuevo no la tiene o si ABERRACION=0. Las
	# aplicaciones van detrás, para que esto siga justo después de escribir el
	# tema.
	"$aqui/aberracion.sh" --parar
	hyprctl reload config-only >/dev/null 2>&1 ||
		echo "tema.sh: hyprctl reload ha fallado; mira hyprctl configerrors" >&2
	setsid -f "$aqui/aberracion.sh" </dev/null >/dev/null 2>&1
	aplicaciones "$nuevo"

	local cuerpo="SUPER+SHIFT+T para cambiar"
	# El vigilante de Theme.qml no ve aparecer el fichero si la carpeta no
	# existía cuando arrancó Quickshell (setup.sh la crea; esto es por si no).
	if $carpeta_nueva; then
		cuerpo="Es la primera vez: si la barra no cambia, reinicia Quickshell o la sesión."
		echo "  $cuerpo"
	fi
	notify-send -a Escritorio -i preferences-desktop-theme "Tema: $nuevo" "$cuerpo" 2>/dev/null || true
}

case "${1:-}" in
"")
	actual
	;;
lista)
	a=$(actual)
	for t in "${TEMAS[@]}"; do
		if [[ $t == "$a" ]]; then
			echo "* $t"
		else
			echo "  $t"
		fi
	done
	;;
alternar)
	a=$(actual)
	siguiente=${TEMAS[0]}
	for i in "${!TEMAS[@]}"; do
		if [[ ${TEMAS[$i]} == "$a" ]]; then
			siguiente=${TEMAS[$(((i + 1) % ${#TEMAS[@]}))]}
			break
		fi
	done
	poner "$siguiente"
	;;
-h | --help | ayuda)
	sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
	;;
*)
	poner "$1"
	;;
esac
