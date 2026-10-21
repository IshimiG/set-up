#!/bin/sh
# Prueba sin pantalla de la capa de datos del cajón (quickshell/homelab/Api.qml)
# contra un panel local (../panel-local.sh): nunca contra panel.lab.ishimi.es
# ni contra el NUC.
#
# Arranca el panel local con un usuario y una contraseña de prueba inventados
# para la ocasión, y lanza Api.qml con «qs -p» sin pantalla (shell.qml, al
# lado) dentro de una sesión de D-Bus aparte con un gnome-keyring de usar y
# tirar: secret-tool es el de verdad, pero el llavero del usuario no se toca.
# Imprime OK o FALLO por cada comprobación. Además, mientras corre, mira con
# «ps -eo args» que la contraseña de prueba no sale en ninguna línea de
# órdenes, y al final, que tampoco sale en la salida.
#
# Quickshell no importa nada de fuera de la carpeta de la configuración, así que
# se copia todo a una carpeta temporal y se lanza desde allí. No toca la barra
# ni el cajón que estén corriendo.
#
#   pruebas/homelab/api/prueba-api.sh            la prueba, y luego lo borra todo
#   pruebas/homelab/api/prueba-api.sh --guardar  deja la carpeta (salida, ps, registro)
#
# Hace falta: docker, curl, quickshell, secret-tool (libsecret), gnome-keyring,
# dbus-run-session y dbus-send.
set -eu

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../../..")
qs_dir=$repo/.config/quickshell
panel_local=$(readlink -f "$aqui/../panel-local.sh")
tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-api.XXXXXX")
guardar=false
[ "${1:-}" = "--guardar" ] && guardar=true

for orden in docker curl qs secret-tool gnome-keyring-daemon dbus-run-session dbus-send; do
	if ! command -v "$orden" >/dev/null; then
		echo "FALLO  falta $orden" >&2
		exit 1
	fi
done

vigia=""
run=""
acabar() {
	[ -n "$vigia" ] && kill "$vigia" 2>/dev/null || true
	[ -n "$run" ] && rm -rf "$run"
	PANEL_LOCAL_DIR=$tmp/panel "$panel_local" parar >/dev/null 2>&1 || true
	if $guardar; then
		echo "La carpeta de la prueba: $tmp"
	else
		rm -rf "$tmp"
	fi
}
trap acabar EXIT INT TERM

# El usuario y la contraseña de prueba. La contraseña solo va a ficheros 600 y
# a la entrada estándar de secret-tool; nunca a la línea de órdenes.
umask 077
clave="Pr0ba-$(head -c 15 /dev/urandom | base64 | tr -d '/+=')"
printf '%s' "$clave" >"$tmp/clave"
printf 'equipo-prueba:%s\n' "$clave" >"$tmp/credenciales"
unset clave

PANEL_LOCAL_DIR=$tmp/panel PANEL_LOCAL_CREDENCIALES=$tmp/credenciales "$panel_local" arrancar

# La configuración, en una carpeta propia: solo Api.qml y la prueba.
mkdir -p "$tmp/qs/homelab" "$tmp/home"
# Los sockets (el del gnome-keyring de prueba, el IPC de qs) no caben en una
# ruta larga (107 bytes): su XDG_RUNTIME_DIR va en el del usuario.
run=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/prueba-api.XXXXXX")
cp "$aqui/shell.qml" "$tmp/qs/"
cp "$qs_dir/homelab/Api.qml" "$tmp/qs/homelab/"

# curl y secret-tool, envueltos para apuntar cada línea de órdenes con que se
# lanzan (ps puede no ver los que duran milisegundos).
mkdir -p "$tmp/envoltorios"
for orden in curl secret-tool; do
	cat >"$tmp/envoltorios/$orden" <<-EOF
		#!/bin/sh
		printf '%s\n' "$orden \$*" >>"$tmp/ordenes.txt"
		exec $(command -v "$orden") "\$@"
	EOF
	chmod +x "$tmp/envoltorios/$orden"
done

# Las líneas de órdenes de todo el equipo, cuatro veces por segundo, mientras
# dura la prueba. Se filtran después con grep -f (la contraseña no va en los
# argumentos de grep, que también saldría en ps).
(
	while :; do
		ps -eo args | grep -v '^\[' >>"$tmp/ps.txt"
		sleep 0.25
	done
) &
vigia=$!

# El llavero de usar y tirar: otra sesión de D-Bus (dbus-run-session), con su
# HOME, su XDG_RUNTIME_DIR y su gnome-keyring, y sin el entorno del escritorio.
env -i \
	HOME="$tmp/home" XDG_RUNTIME_DIR="$run" PATH="$tmp/envoltorios:/usr/local/bin:/usr/bin:/bin" \
	LANG="${LANG:-C.UTF-8}" DOCKER_CONFIG="${DOCKER_CONFIG:-$HOME/.docker}" \
	QT_QPA_PLATFORM=offscreen HOMELAB_PANEL_URL=http://127.0.0.1:8791 \
	PRUEBA_DIR="$tmp" PANEL_LOCAL="$panel_local" PANEL_LOCAL_DIR="$tmp/panel" \
	dbus-run-session -- sh -c '
		printf "desbloqueo" | gnome-keyring-daemon --unlock --components=secrets --daemonize >/dev/null 2>&1
		# Hasta que el llavero de prueba esté en este bus: si secret-tool
		# llegara antes, D-Bus arrancaría otro gnome-keyring.
		i=0
		until dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
			org.freedesktop.DBus.NameHasOwner string:org.freedesktop.secrets 2>/dev/null | grep -q true; do
			i=$((i + 1))
			[ $i -ge 100 ] && echo "qml: FALLO  no arranca el gnome-keyring de prueba" && exit 1
			sleep 0.1
		done
		cd "$PRUEBA_DIR/qs" && timeout 300 qs -p ./shell.qml
	' >"$tmp/salida.txt" 2>&1 || true

kill "$vigia" 2>/dev/null || true
vigia=""

sed -E 's/\x1b\[[0-9;]*m//g' "$tmp/salida.txt" | grep -E "qml: " | sed -E 's/^.*qml: //'
grep -E "TypeError|ReferenceError|SyntaxError|is not defined|Cannot " "$tmp/salida.txt" | sed -E 's/\x1b\[[0-9;]*m//g' | sed 's/^/AVISO  /' || true

echo
muestras=$(grep -c -- 'curl -K - ' "$tmp/ps.txt" || true)
if [ "$muestras" -eq 0 ]; then
	echo "FALLO  ps no ha visto nunca curl corriendo"
elif grep -q -F -f "$tmp/clave" "$tmp/ps.txt"; then
	echo "FALLO  la contraseña de prueba sale en ps -eo args"
else
	echo "OK     la contraseña de prueba no sale en ps -eo args  ($muestras muestras con curl -K - corriendo)"
fi
curls=$(grep -c '^curl -K - ' "$tmp/ordenes.txt" || true)
lookups=$(grep -c '^secret-tool lookup ' "$tmp/ordenes.txt" || true)
if grep -q -F -f "$tmp/clave" "$tmp/ordenes.txt"; then
	echo "FALLO  la contraseña de prueba sale en la línea de órdenes de curl o de secret-tool"
else
	echo "OK     la contraseña de prueba no sale en ninguna línea de órdenes de curl ($curls) ni de secret-tool ($lookups lookup)"
fi
if grep -q -F -f "$tmp/clave" "$tmp/salida.txt"; then
	echo "FALLO  la contraseña de prueba sale en la salida de qs"
else
	echo "OK     la contraseña de prueba no sale en la salida de qs"
fi
if docker logs prueba-fase2-caddy 2>&1 | grep -q -F -f "$tmp/clave"; then
	echo "FALLO  la contraseña de prueba sale en el registro del Caddy falso"
else
	echo "OK     la contraseña de prueba no sale en el registro del Caddy falso"
fi
