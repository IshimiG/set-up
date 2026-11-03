#!/bin/sh
# Prueba sin pantalla del selector de tema (quickshell/temas), en los dos temas.
#
# Un PanelWindow no carga sin compositor, así que se copia el shell.qml del
# repo como una FloatingWindow —sin lo de layershell ni el monitor enfocado—,
# con la orden de tema.sh cambiada por una lista y el Qt.quit por un contador:
# la prueba NO ejecuta el tema.sh de verdad. El estado va en un
# $XDG_STATE_HOME de prueba. Luego panel-shell.qml pulsa teclas y filas con
# TestEvent y mira que carga, lista los temas, marca el activo, que Enter y el
# clic aplican y que Escape cierra. Imprime OK o FALLO por cada comprobación y
# deja capturas en <carpeta temporal>/capturas.
#
#   pruebas/temas/panel.sh            la prueba, y la carpeta se borra
#   pruebas/temas/panel.sh --guardar  la deja, para mirar las capturas
set -u

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
qs_dir=$repo/.config/quickshell
tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-temas-panel.XXXXXX")

mkdir -p "$tmp/capturas" "$tmp/estado/escritorio"
cp "$aqui/panel-shell.qml" "$tmp/shell.qml"
cp -r "$qs_dir/shared" "$tmp/shared"

sed -E \
	-e 's/^PanelWindow \{/FloatingWindow {/' \
	-e '/^    WlrLayershell\./d' \
	-e '/^    exclusionMode:/d' \
	-e '/^    anchors \{$/,/^    \}$/d' \
	-e '/^    screen: \{$/,/^    \}$/d' \
	-e 's/Quickshell\.execDetached\(\[.*\]\);/root.pruebaElegidos = root.pruebaElegidos.concat([Theme.temas[i]]);/' \
	-e 's/onTriggered: Qt\.quit\(\)/onTriggered: root.pruebaSalidas++/' \
	-e 's/^    id: root$/    id: root\n    property var pruebaElegidos: []\n    property int pruebaSalidas: 0\n    readonly property Item pruebaCard: card\n    readonly property var pruebaFilas: filas/' \
	-e 's/^                Repeater \{$/                Repeater {\n                    id: filas/' \
	"$qs_dir/temas/shell.qml" >"$tmp/Panel.qml"

# Si el shell.qml cambia y alguna de esas sustituciones deja de casar, mejor
# enterarse aquí que con una prueba que pasa sin probar nada.
for patron in '^FloatingWindow \{' 'pruebaElegidos = ' 'onTriggered: root\.pruebaSalidas\+\+' 'id: filas' 'pruebaFilas'; do
	grep -qE "$patron" "$tmp/Panel.qml" || {
		echo "FALLO: la copia del panel no tiene «$patron»"
		exit 1
	}
done
if grep -qE '^    (screen: \{|WlrLayershell\.|anchors \{)|execDetached' "$tmp/Panel.qml"; then
	echo "FALLO: a la copia del panel le queda algo de PanelWindow o lanza tema.sh de verdad"
	exit 1
fi

unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
export XDG_STATE_HOME=$tmp/estado
cd "$tmp" || exit 1

fallos=0
for tema in default liquido; do
	echo "== tema $tema =="
	printf '%s\n' "$tema" >"$XDG_STATE_HOME/escritorio/tema"
	salida=$(PRUEBA_DIR=$tmp PRUEBA_TEMA=$tema QT_QPA_PLATFORM=offscreen timeout 60 qs -p ./shell.qml 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g')
	printf '%s\n' "$salida" | grep -E "qml: " | sed -E 's/^.*qml: //'
	if printf '%s\n' "$salida" | grep -qiE 'unresolvable|is not a type|ReferenceError|TypeError|Cannot assign|Unable to assign|ERROR'; then
		echo "FALLO [$tema] errores de QML:"
		printf '%s\n' "$salida" | grep -iE 'unresolvable|is not a type|ReferenceError|TypeError|Cannot assign|Unable to assign|ERROR' | head -5
		fallos=$((fallos + 1))
	else
		echo "OK    [$tema] qs no da errores de QML"
	fi
	printf '%s\n' "$salida" | grep -q "Todo OK" || fallos=$((fallos + 1))
	# El estado real no se ha tocado: el de prueba sigue diciendo $tema.
	[ "$(cat "$XDG_STATE_HOME/escritorio/tema")" = "$tema" ] || fallos=$((fallos + 1))
done

if [ "${1:-}" = "--guardar" ]; then
	echo "Capturas en $tmp/capturas"
else
	cd / && rm -rf "$tmp"
fi
if [ "$fallos" -eq 0 ]; then echo "Resultado: todo bien"; else echo "Resultado: $fallos FALLOS"; exit 1; fi
