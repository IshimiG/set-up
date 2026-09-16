#!/usr/bin/env bash
# Cuenta los paquetes pendientes de actualizar y, si hay alguno, enseña el
# disco de ~/.config/quickshell/updates/shell.qml en el centro de la pantalla.
# Lo lanza Hyprland al iniciar la sesión.
#
# Las cuentas se hacen aquí y no en el QML para que el aviso no llegue a
# aparecer cuando no hay nada que decir. Los repos van por checkupdates, que
# sincroniza contra una base de datos temporal y por tanto no toca la del
# sistema ni necesita sudo; el AUR va por paru -Qua, que consulta su propia
# caché.
#
# checkupdates devuelve 0 cuando hay actualizaciones y 2 cuando no hay
# ninguna. Cualquier otro código es un fallo de verdad —y al iniciar sesión
# casi siempre significa que la red todavía no está lista—, así que se
# reintenta un rato antes de rendirse en silencio.

set -uo pipefail

readonly ATTEMPTS=20
readonly DELAY=5

repos_list=""
rc=1
for ((attempt = 1; attempt <= ATTEMPTS; attempt++)); do
	repos_list=$(checkupdates 2>/dev/null)
	rc=$?
	[[ $rc -eq 0 || $rc -eq 2 ]] && break
	sleep "$DELAY"
done

# Sigue sin haber red después de todos los intentos: no se avisa de nada, que
# es mejor que dar un número que no se ha podido comprobar.
[[ $rc -eq 0 || $rc -eq 2 ]] || exit 0

repos=0
[[ -n $repos_list ]] && repos=$(printf '%s\n' "$repos_list" | wc -l)

# El AUR no es crítico: si paru falla, se avisa igualmente de lo que haya en
# los repos en vez de perder el aviso entero.
aur_list=$(paru -Qua 2>/dev/null)
aur=0
[[ -n $aur_list ]] && aur=$(printf '%s\n' "$aur_list" | wc -l)

(( repos + aur > 0 )) || exit 0

# --no-duplicate evita un segundo disco si esto se ejecuta dos veces, que es lo
# que pasa al recargar la configuración de Hyprland sin reiniciar la sesión.
UPDATES_REPO="$repos" UPDATES_AUR="$aur" exec qs -c updates -d --no-duplicate
