#!/bin/sh
# Prueba sin pantalla de la agenda del calendario de la barra.
#
# Cuatro partes, con datos falsos:
#   - el formato (shared/AgendaFormato.js): de las tareas del panel a la
#     agenda, y de la agenda a lo que pinta el calendario;
#   - el fichero: el cajón (homelab/Agenda.qml, con una API falsa) lo escribe
#     y la barra (bar/Agenda.qml) lo lee, de verdad, en un $XDG_RUNTIME_DIR
#     temporal;
#   - el calendario (bar/CalendarPanel.qml) con un shell falso: los puntos, la
#     lista del día, el clic, la rueda, el botón de hoy, el desplegable de mes
#     y año y arrastrar tareas;
#   - el cliente del panel (bar/Tareas.qml) de verdad, por HTTP, contra un
#     panel falso (panel-falso.py, al lado) y con el calendario encima: la
#     hoja de una tarea (bar/HojaTarea.qml) para crearla con doble clic y
#     editarla pulsando su título, con sus horas, su color, lo que valida y
#     el cuerpo exacto de cada POST; la prioridad, el 🚫🤖 y mover.
# Imprime OK o FALLO por cada comprobación y deja capturas en
# <carpeta temporal>/capturas. Sale con 1 si algo falla.
#
# Como pruebas/homelab/prueba.sh, copia lo que carga a una carpeta temporal
# (Quickshell no importa nada de fuera de la carpeta de la configuración). No
# toca la barra, el cajón ni el fichero de la agenda de la sesión: el qs de la
# prueba tiene su propio XDG_RUNTIME_DIR. Tampoco el llavero ni el NUC: el
# panel es el falso, en 127.0.0.1, y secret-tool, uno de mentira que da una
# contraseña inventada para la ocasión.
#
#   pruebas/calendario/prueba.sh            la prueba, y la carpeta se borra
#   pruebas/calendario/prueba.sh --guardar  la deja, para mirar las capturas
#
# Hace falta: quickshell y python3.
set -e

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
qs_dir=$repo/.config/quickshell

for orden in qs python3; do
	if ! command -v "$orden" >/dev/null; then
		echo "FALLO  falta $orden" >&2
		exit 1
	fi
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-calendario.XXXXXX")
panel=""
acabar() {
	[ -n "$panel" ] && kill "$panel" 2>/dev/null || true
}
trap acabar EXIT INT TERM

mkdir -p "$tmp/barra" "$tmp/cajon" "$tmp/capturas" "$tmp/bin"
mkdir -m 700 "$tmp/run"
cp "$aqui/shell.qml" "$tmp/"
cp -r "$qs_dir/shared" "$tmp/shared"
cp "$qs_dir/bar/CalendarPanel.qml" "$qs_dir/bar/HojaTarea.qml" "$qs_dir/bar/Agenda.qml" "$qs_dir/bar/Tareas.qml" "$tmp/barra/"
cp "$qs_dir/homelab/Agenda.qml" "$tmp/cajon/"
ln -s ../shared "$tmp/barra/shared"
ln -s ../shared "$tmp/cajon/shared"

# El llavero de la prueba: el usuario «prueba» y una contraseña de usar y
# tirar, que solo va a un fichero 600 (nunca a una línea de órdenes). Tareas.qml
# llama a secret-tool como siempre y encuentra este antes en el PATH.
(umask 077 && head -c 15 /dev/urandom | base64 | tr -d '/+=' | sed 's/^/Pr0ba-/' >"$tmp/clave")
cat >"$tmp/bin/secret-tool" <<'FIN'
#!/bin/sh
# secret-tool de mentira: los atributos por la salida de errores, como el de
# verdad, y la contraseña de la prueba al pedirla.
case "$1" in
# Con --all salen todas, y «movil» primero: la barra tiene que quedarse con la otra.
search) [ "$2" = "--all" ] && echo "attribute.usuario = movil" >&2; echo "attribute.usuario = prueba" >&2 ;;
lookup) cat "$PRUEBA_DIR/clave" ;;
*) exit 1 ;;
esac
FIN
chmod +x "$tmp/bin/secret-tool"

# El panel falso, en un puerto libre que deja escrito cuando ya escucha.
python3 "$aqui/panel-falso.py" "$tmp/puerto" "$tmp/clave" >"$tmp/panel.log" 2>&1 &
panel=$!
n=0
while [ ! -s "$tmp/puerto" ] && [ $n -lt 50 ]; do
	sleep 0.1
	n=$((n + 1))
done
if [ ! -s "$tmp/puerto" ]; then
	echo "FALLO  el panel falso no arranca" >&2
	rm -rf "$tmp"
	exit 1
fi

# Una agenda de otra vez, que el cajón tiene que borrar al arrancar.
printf '%s' '{"formato":1,"conectado":true,"actualizado":"","eventos":[{"dia":"2026-10-21","titulo":"Agenda vieja","origen":"tarea"}]}' >"$tmp/run/escritorio-agenda.json"

cd "$tmp"
PATH=$tmp/bin:$PATH HOMELAB_PANEL_URL=http://127.0.0.1:$(cat "$tmp/puerto") XDG_RUNTIME_DIR=$tmp/run PRUEBA_DIR=$tmp QT_QPA_PLATFORM=offscreen timeout 180 qs -p ./shell.qml >"$tmp/salida.log" 2>&1 || true

resultado=$(sed -E 's/\x1b\[[0-9;]*m//g' "$tmp/salida.log" | grep -E "qml: " | sed -E 's/^.*qml: //')

# Ni el texto de una tarea, ni el JSON de la agenda, ni la contraseña van
# nunca a un log. La prueba no imprime ninguno, así que en la salida de qs no
# puede haber ninguno.
if grep -q -e "Entrega secreta" -e "Informe trimestral" -e "Revisar el informe" -e "Comprar pilas" -e "Tarea quinta" -e "Llamar al taller" -e "Tutoría" -e "Clase de yoga" -e "Otra cosa" -e "No la quiero" -e '"eventos"' "$tmp/salida.log" || grep -q -F -f "$tmp/clave" "$tmp/salida.log"; then
	privacidad="FALLO  el texto de una tarea, el JSON de la agenda o la contraseña salen en el log de qs"
else
	privacidad="OK     ni el texto de las tareas, ni el JSON, ni la contraseña salen en el log de qs"
fi

printf '%s\n%s\n' "$resultado" "$privacidad"

acabar
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
