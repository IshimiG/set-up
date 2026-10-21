#!/bin/sh
# Prueba sin pantalla de la agenda del calendario de la barra.
#
# Tres partes, con datos falsos:
#   - el formato (shared/AgendaFormato.js): de las tareas del panel a la
#     agenda, y de la agenda a lo que pinta el calendario;
#   - el fichero: el cajón (homelab/Agenda.qml, con una API falsa) lo escribe
#     y la barra (bar/Agenda.qml) lo lee, de verdad, en un $XDG_RUNTIME_DIR
#     temporal;
#   - el calendario (bar/CalendarPanel.qml) con un shell falso: los puntos, la
#     lista del día, el clic, la rueda y el botón de hoy.
# Imprime OK o FALLO por cada comprobación y deja capturas en
# <carpeta temporal>/capturas. Sale con 1 si algo falla.
#
# Como pruebas/homelab/prueba.sh, copia lo que carga a una carpeta temporal
# (Quickshell no importa nada de fuera de la carpeta de la configuración). No
# toca la barra, el cajón ni el fichero de la agenda de la sesión: el qs de la
# prueba tiene su propio XDG_RUNTIME_DIR.
#
#   pruebas/calendario/prueba.sh            la prueba, y la carpeta se borra
#   pruebas/calendario/prueba.sh --guardar  la deja, para mirar las capturas
set -e

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
qs_dir=$repo/.config/quickshell
tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-calendario.XXXXXX")

mkdir -p "$tmp/barra" "$tmp/cajon" "$tmp/capturas"
mkdir -m 700 "$tmp/run"
cp "$aqui/shell.qml" "$tmp/"
cp -r "$qs_dir/shared" "$tmp/shared"
cp "$qs_dir/bar/CalendarPanel.qml" "$qs_dir/bar/Agenda.qml" "$tmp/barra/"
cp "$qs_dir/homelab/Agenda.qml" "$tmp/cajon/"
ln -s ../shared "$tmp/barra/shared"
ln -s ../shared "$tmp/cajon/shared"

# Una agenda de otra vez, que el cajón tiene que borrar al arrancar.
printf '%s' '{"formato":1,"conectado":true,"actualizado":"","eventos":[{"dia":"2026-10-21","titulo":"Agenda vieja","origen":"tarea"}]}' >"$tmp/run/escritorio-agenda.json"

cd "$tmp"
XDG_RUNTIME_DIR=$tmp/run PRUEBA_DIR=$tmp QT_QPA_PLATFORM=offscreen timeout 120 qs -p ./shell.qml >"$tmp/salida.log" 2>&1 || true

resultado=$(sed -E 's/\x1b\[[0-9;]*m//g' "$tmp/salida.log" | grep -E "qml: " | sed -E 's/^.*qml: //')

# Ni el texto de una tarea ni el JSON de la agenda van nunca a un log. La
# prueba no imprime ninguno, así que en la salida de qs no puede haber ninguno.
if grep -q -e "Entrega secreta" -e "Informe trimestral" -e '"eventos"' "$tmp/salida.log"; then
	privacidad="FALLO  el texto de una tarea o el JSON de la agenda sale en el log de qs"
else
	privacidad="OK     ni el texto de las tareas ni el JSON salen en el log de qs"
fi

printf '%s\n%s\n' "$resultado" "$privacidad"

if [ "$1" = "--guardar" ]; then
	echo "Capturas en $tmp/capturas"
else
	rm -rf "$tmp"
fi

case "$resultado$privacidad" in
*FALLO* | "") exit 1 ;;
*Resultado:*) exit 0 ;;
*) exit 1 ;;
esac
