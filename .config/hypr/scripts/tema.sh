#!/usr/bin/env bash
# El tema del escritorio (ver «Temas» en el README).
#
#   tema.sh              dice el tema activo
#   tema.sh lista        los temas que hay, uno por línea; el activo, con *
#   tema.sh <tema>       pone ese tema: default o liquido
#   tema.sh alternar     pasa al siguiente de la lista (SUPER+SHIFT+CTRL+T)
#   tema.sh aplicar      vuelve a copiar los fragmentos del tema activo (setup.sh)
#
# El tema es una palabra en ${XDG_STATE_HOME:-~/.local/state}/escritorio/tema,
# de cada máquina y fuera del repo. Se escribe de una vez (un temporal que se
# renombra encima), así que quien lo vigila nunca lo lee a medias. Lo leen dos:
#   - la paleta de Quickshell (quickshell/shared/Theme.qml), que lo vigila y
#     repinta la barra, el cajón y lo demás en caliente;
#   - hyprland.lua, al cargar: por eso, dentro de una sesión de Hyprland, este
#     script hace "hyprctl reload config-only" después de escribirlo.
# Fuera de una sesión (sin HYPRLAND_INSTANCE_SIGNATURE) sólo escribe el
# estado, que vale al entrar; así se prueba (pruebas/temas/prueba.sh).
#
# Además de la palabra, deja en la misma carpeta los fragmentos del tema para lo
# que no sabe leerla: ghostty-tema (lo incluye config.ghostty) y
# hyprlock-tema.conf (lo hace `source` hyprlock.conf). Salen de
# ghostty/temas/<tema>.ghostty y hypr/temas/hyprlock-<tema>.conf del repo.
# Las terminales de Ghostty abiertas se recargan solas (acción reload-config
# por D-Bus: no se mata ni se señala a nadie); Neovim no depende del tema.
#
# Poner el tema que ya está no rompe nada: no reescribe el fichero y vuelve a
# aplicarlo en Hyprland. Si falta el fichero o dice algo que no es un tema, el
# activo es default, igual que para Theme.qml y hyprland.lua.

set -uo pipefail

# Los temas, en orden: el de `lista` y el de `alternar`. Un tema nuevo va aquí,
# en las paletas de Theme.qml y en la tabla `temas` de hyprland.lua.
readonly TEMAS=(default liquido)

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

# Copia de una vez (temporal + mv) el fragmento $1 a $2, si existe.
copiar() {
	local origen=$1 destino=$2 tmp
	[[ -r $origen ]] || return 0
	cmp -s "$origen" "$destino" && return 0
	tmp=$(mktemp "$DIR/.frag.XXXXXX") || return 1
	if cp "$origen" "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$destino"; then
		return 0
	fi
	rm -f "$tmp"
	return 1
}

# Los fragmentos del tema $1.
fragmentos() {
	local t=$1 raiz
	raiz=$(readlink -f "$aqui/../..")
	mkdir -p "$DIR" || return 1
	copiar "$raiz/ghostty/temas/$t.ghostty" "$DIR/ghostty-tema"
	copiar "$raiz/hypr/temas/hyprlock-$t.conf" "$DIR/hyprlock-tema.conf"
	return 0
}

# Recarga la configuración de las terminales de Ghostty abiertas.
recargar_ghostty() {
	command -v gdbus >/dev/null || return 0
	gdbus call --session --dest com.mitchellh.ghostty --object-path /com/mitchellh/ghostty \
		--method org.gtk.Actions.Activate reload-config '[]' '{}' >/dev/null 2>&1 || true
}

en_sesion() {
	[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null
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

	fragmentos "$nuevo"
	# Se recarga siempre que haya sesión: no cuesta nada.
	if en_sesion || [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
		recargar_ghostty
	fi

	if ! en_sesion; then
		echo "  (sin sesión de Hyprland: se aplica al entrar)"
		return
	fi

	hyprctl reload config-only >/dev/null 2>&1 ||
		echo "tema.sh: hyprctl reload ha fallado; mira hyprctl configerrors" >&2

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
aplicar)
	mkdir -p "$DIR" && fragmentos "$(actual)"
	;;
-h | --help | ayuda)
	sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
	;;
*)
	poner "$1"
	;;
esac
