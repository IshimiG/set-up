#!/bin/sh
# Prueba sin pantalla del panel de paquetes de la isla (bar/PaquetesPanel.qml)
# y de su entrada en el menú de sesión (bar/PowerPanel.qml).
#
# Carga los dos con un shell falso dentro de una ventana sin compositor y los
# mueve con TestEvent: la lista, el buscador, las flechas, Enter y Ctrl+Enter,
# el clic en una fila (también por su canto de abajo), la rueda, los
# protegidos, el botón, la confirmación y el reinicio al cerrar; los estados
# de carga y de error; y que «Desinstalar» del menú cambia la isla al panel.
#
# Después, la isla de verdad (bar/Island.qml) con todos sus paneles: un
# PanelWindow no carga sin compositor, así que se copia como FloatingWindow,
# sin lo de layer-shell ni el focus grab de Hyprland (como hace
# pruebas/updates con su aviso). Con ella se mira que el menú se reajusta al
# panel sin cerrarse, que la máscara de entrada cubre el panel entero y que el
# teclado va y vuelve entre la isla y el buscador.
#
# Imprime OK o FALLO por cada comprobación y deja capturas en
# <carpeta temporal>/capturas. Sale con 1 si algo falla.
#
# No toca pacman ni abre terminales: el script de paquetes es uno falso que lee
# lista.tsv (al lado) y el panel se queda con la orden que lanzaría en vez de
# lanzarla. Por si acaso, ghostty, pacman, sudo, systemctl, hyprlock y hyprctl
# son, en el PATH de la prueba, de mentira, y si alguien los llama la prueba
# falla.
#
# Como pruebas/homelab/prueba.sh, copia lo que carga a una carpeta temporal
# (Quickshell no importa nada de fuera de la carpeta de la configuración).
#
#   pruebas/paquetes/prueba.sh            la prueba, y la carpeta se borra
#   pruebas/paquetes/prueba.sh --guardar  la deja, para mirar las capturas
set -e

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
qs_dir=$repo/.config/quickshell

if ! command -v qs >/dev/null; then
	echo "FALLO  falta qs (quickshell)" >&2
	exit 1
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-paquetes.XXXXXX")

mkdir -p "$tmp/barra" "$tmp/capturas" "$tmp/bin" "$tmp/home/.config/hypr/scripts"
cp "$aqui/shell.qml" "$aqui/lista.tsv" "$tmp/"
cp -r "$qs_dir/shared" "$tmp/shared"
for f in PaquetesPanel PowerPanel PowerButton Clock Bell CalendarPanel HojaTarea NotificationsPanel HistoryItem; do
	cp "$qs_dir/bar/$f.qml" "$tmp/barra/"
done
ln -s ../shared "$tmp/barra/shared"

# La isla, como FloatingWindow y con sus piezas a la vista de la prueba.
sed -E \
	-e '/^import Quickshell\.(Wayland|Hyprland)$/d' \
	-e 's/^PanelWindow \{/FloatingWindow {/' \
	-e '/^    WlrLayershell\./d' \
	-e '/^    exclusionMode:/d' \
	-e '/^    anchors \{$/,/^    \}$/d' \
	-e '/^    HyprlandFocusGrab \{$/,/^    \}$/d' \
	-e 's/^    id: island$/    id: island\n    implicitWidth: 760\n    implicitHeight: 600\n    readonly property Item pruebaCristal: glassEdge\n    readonly property var pruebaRegion: regionAbierta\n    readonly property Item pruebaTeclado: teclado\n    readonly property Item pruebaPaquetes: paquetes\n    readonly property Item pruebaMenu: power\n    readonly property Item pruebaPastilla: pill/' \
	"$qs_dir/bar/Island.qml" >"$tmp/barra/IslaPrueba.qml"

# Si Island.qml cambia y alguna sustitución deja de casar, mejor enterarse aquí
# que con una prueba que pasa sin probar nada.
for patron in '^FloatingWindow \{' 'pruebaRegion: regionAbierta' 'pruebaPaquetes: paquetes'; do
	grep -qE "$patron" "$tmp/barra/IslaPrueba.qml" || {
		echo "FALLO  la copia de la isla no tiene «$patron»"
		exit 1
	}
done
if grep -qE '^    (WlrLayershell\.|HyprlandFocusGrab|exclusionMode|anchors \{)' "$tmp/barra/IslaPrueba.qml"; then
	echo "FALLO  a la copia de la isla le queda algo de PanelWindow"
	exit 1
fi

# El script de paquetes, falso. «lista» da lista.tsv; cualquier otra cosa (un
# «desinstalar») no debería llegar nunca, y lo deja apuntado.
cat >"$tmp/bin/paquetes.sh" <<'FIN'
#!/bin/sh
case "$1" in
lista) cat "$PRUEBA_DIR/lista.tsv" ;;
*) echo "paquetes.sh $*" >>"$PRUEBA_DIR/no-debia"; exit 3 ;;
esac
FIN
# Uno que falla, como si pacman no contestara.
cat >"$tmp/bin/paquetes-falla.sh" <<'FIN'
#!/bin/sh
echo "error: no se pudo leer la base de datos" >&2
exit 1
FIN
# Uno lento, que además da otra lista (las tres primeras): si su respuesta
# llega con el panel ya cerrado y abierto otra vez, no tiene que pisar nada.
cat >"$tmp/bin/paquetes-lento.sh" <<'FIN'
#!/bin/sh
sleep 1
head -n 3 "$PRUEBA_DIR/lista.tsv"
FIN
# Lo que no se puede llamar nunca desde la prueba.
for orden in ghostty pacman sudo systemctl hyprlock hyprctl hyprshutdown; do
	printf '#!/bin/sh\necho "%s $*" >>"$PRUEBA_DIR/no-debia"\n' "$orden" >"$tmp/bin/$orden"
done
chmod +x "$tmp/bin/"*
# La isla usa la ruta de siempre, ~/.config/hypr/scripts/paquetes.sh: con HOME
# en la carpeta de la prueba, es el falso.
cp "$tmp/bin/paquetes.sh" "$tmp/home/.config/hypr/scripts/paquetes.sh"

cd "$tmp"
HOME=$tmp/home PATH=$tmp/bin:$PATH PRUEBA_DIR=$tmp QT_QPA_PLATFORM=offscreen timeout 120 qs -p ./shell.qml >"$tmp/salida.log" 2>&1 || true

resultado=$(sed -E 's/\x1b\[[0-9;]*m//g' "$tmp/salida.log" | grep -E "qml: " | sed -E 's/^.*qml: //')

if [ -s "$tmp/no-debia" ]; then
	extra="FALLO  se ha llamado a algo que la prueba no puede llamar: $(tr '\n' ';' <"$tmp/no-debia")"
else
	extra="OK     ni pacman, ni sudo, ni una terminal, ni systemctl: nada de verdad se ha llamado"
fi

printf '%s\n%s\n' "$resultado" "$extra"

if [ "$1" = "--guardar" ]; then
	echo "Capturas en $tmp/capturas"
else
	rm -rf "$tmp"
fi

case "$resultado$extra" in
*FALLO* | "") exit 1 ;;
*Resultado:*) exit 0 ;;
*) exit 1 ;;
esac
