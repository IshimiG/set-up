#!/bin/sh
# Prueba sin pantalla del cajón del panel del homelab (quickshell/homelab).
#
# Carga el Cajon.qml del repo dentro de una ventana sin compositor, con un shell
# falso, y mueve el ratón con TestEvent: asomar, arrastrar, soltar, tirones, la
# goma, el clic y la rueda. Imprime OK o FALLO por cada comprobación y deja
# capturas en <carpeta temporal>/capturas.
#
# Quickshell no importa nada de fuera de la carpeta de la configuración, así que
# se copia todo a una carpeta temporal y se lanza desde allí. No toca la barra
# ni el cajón que estén corriendo.
#
#   pruebas/homelab/prueba.sh            la prueba, y la carpeta se borra
#   pruebas/homelab/prueba.sh --guardar  la deja, para mirar las capturas
set -e

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
qs_dir=$repo/.config/quickshell
tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-cajon.XXXXXX")

mkdir -p "$tmp/homelab" "$tmp/capturas"
cp "$aqui/shell.qml" "$tmp/"
cp -r "$qs_dir/shared" "$tmp/shared"
cp "$qs_dir/homelab/"*.qml "$tmp/homelab/"
ln -s ../shared "$tmp/homelab/shared"

cd "$tmp"
PRUEBA_DIR=$tmp QT_QPA_PLATFORM=offscreen timeout 60 qs -p ./shell.qml 2>&1 |
	sed -E 's/\x1b\[[0-9;]*m//g' |
	grep -E "qml: " | sed -E 's/^.*qml: //'

if [ "$1" = "--guardar" ]; then
	echo "Capturas en $tmp/capturas"
else
	rm -rf "$tmp"
fi
