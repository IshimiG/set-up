#!/bin/sh
# Prueba sin pantalla del aviso de actualizaciones (quickshell/updates).
#
# Un PanelWindow no carga sin compositor, así que se copia el shell.qml del
# repo como una FloatingWindow —sin lo de layershell ni el monitor enfocado—,
# con el lanzamiento de la terminal y el Qt.quit cambiados por dos contadores.
# Luego el shell.qml de aquí la pulsa con TestEvent: la máscara de clics, el
# cristal, la flecha, la pestaña y los dos botones. Imprime OK o FALLO por cada
# comprobación y deja capturas en <carpeta temporal>/capturas.
#
#   pruebas/updates/prueba.sh            la prueba, y la carpeta se borra
#   pruebas/updates/prueba.sh --guardar  la deja, para mirar las capturas
set -e

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
qs_dir=$repo/.config/quickshell
tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-updates.XXXXXX")

mkdir -p "$tmp/capturas"
cp "$aqui/shell.qml" "$tmp/"
cp -r "$qs_dir/shared" "$tmp/shared"

sed -E \
	-e 's/^PanelWindow \{/FloatingWindow {/' \
	-e '/^    WlrLayershell\./d' \
	-e '/^    exclusionMode:/d' \
	-e '/^    anchors\.top: true$/d' \
	-e '/^    margins\.top:/d' \
	-e '/^    screen: \{$/,/^    \}$/d' \
	-e 's/Quickshell\.execDetached\(\[.*\]\);/root.pruebaLanzadas++;/' \
	-e 's/onTriggered: Qt\.quit\(\)/onTriggered: root.pruebaSalidas++/' \
	-e 's/^    id: root$/    id: root\n    property int pruebaLanzadas: 0\n    property int pruebaSalidas: 0\n    readonly property Item pruebaCard: card\n    readonly property Item pruebaTab: tab\n    readonly property var pruebaRegionCard: regionCard\n    readonly property var pruebaRegionTab: regionTab/' \
	"$qs_dir/updates/shell.qml" >"$tmp/Aviso.qml"

# Si el shell.qml cambia y alguna de esas sustituciones deja de casar, mejor
# enterarse aquí que con una prueba que pasa sin probar nada.
for patron in '^FloatingWindow \{' 'pruebaLanzadas\+\+;' 'onTriggered: root\.pruebaSalidas\+\+' 'pruebaRegionTab'; do
	grep -qE "$patron" "$tmp/Aviso.qml" || {
		echo "FALLO: la copia del aviso no tiene «$patron»"
		exit 1
	}
done
if grep -qE '^    (screen: \{|WlrLayershell\.|margins\.top)' "$tmp/Aviso.qml"; then
	echo "FALLO: a la copia del aviso le queda algo de PanelWindow"
	exit 1
fi

cd "$tmp"
PRUEBA_DIR=$tmp UPDATES_REPO=12 UPDATES_AUR=3 QT_QPA_PLATFORM=offscreen timeout 60 qs -p ./shell.qml 2>&1 |
	sed -E 's/\x1b\[[0-9;]*m//g' |
	grep -E "qml: " | sed -E 's/^.*qml: //'

if [ "$1" = "--guardar" ]; then
	echo "Capturas en $tmp/capturas"
else
	rm -rf "$tmp"
fi
