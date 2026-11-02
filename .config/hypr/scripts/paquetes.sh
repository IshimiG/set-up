#!/usr/bin/env bash
# Lista y desinstala los paquetes instalados explícitamente. Lo usa el panel
# de paquetes del menú de sesión (quickshell/bar), que no habla con pacman: sólo
# lanza este script.
#
#   paquetes.sh lista                  una línea por paquete, campos separados por TAB:
#                                      nombre versión tamaño origen protegido requeridos descripción
#   paquetes.sh desinstalar <pkg>...   pacman -Rns, pensado para correr en una terminal
#
# Para probarlo sin tocar el sistema (pruebas/paquetes/script.sh):
#   PAQUETES_QI / PAQUETES_QM   ficheros con la salida de `pacman -Qie` (locale C)
#                               y de `pacman -Qqm`, en lugar de llamar a pacman
#   PAQUETES_PACMAN             orden que sustituye a `sudo pacman` (p. ej. echo)
#   PAQUETES_SIN_ESPERA=1       se salta el «Pulsa Enter» final

# Paquetes protegidos: los que dejan el sistema sin arrancar o el escritorio sin
# una terminal desde la que arreglarlo. Una sola lista para el panel y para la
# defensa en profundidad de «desinstalar». Es una expresión regular ampliada:
#  - nombres exactos (base, arranque, pacman, el escritorio y su terminal...;
#    paru o yay según el equipo, así que van los dos);
#  - el núcleo `linux` y sus variantes (-lts, -zen, -hardened, -rt, -cachyos...),
#    y cualquier linux-firmware-*. Las variantes van con nombre y no como
#    «linux-loquesea»: eso protegería también programas que sólo empiezan por
#    linux, como linux-atm o linux-wifi-hotspot. El segundo patrón deja fuera
#    los -headers y -docs, que sí se pueden quitar sin romper el arranque.
PROTEGIDOS='^(base|base-devel|systemd|systemd-libs|glibc|pacman|pacman-contrib|sudo|mkinitcpio|limine|grub|efibootmgr|hyprland|quickshell|quickshell-git|ghostty|fish|git|paru|yay|iwd|networkmanager|sddm)$|^linux(-(lts|zen|hardened|rt|rt-lts|cachyos(-[a-z0-9]+)*))?$|^linux-firmware(-[a-z0-9]+)*$'
NO_PROTEGIDOS='-(headers|docs)$'

es_protegido() {
	[[ $1 =~ $PROTEGIDOS ]] && ! [[ $1 =~ $NO_PROTEGIDOS ]]
}

lista() {
	local qi qm
	# LC_ALL=C: las etiquetas de `pacman -Qi` salen traducidas si el sistema
	# está en español, y el awk de abajo busca las inglesas.
	if [ -n "${PAQUETES_QI:-}" ]; then
		qi=$(<"$PAQUETES_QI") || return 1
	else
		qi=$(LC_ALL=C pacman -Qie) || return 1
	fi
	# -Qqm sale con 1 cuando no hay ningún paquete ajeno a los repos: no es error.
	if [ -n "${PAQUETES_QM:-}" ]; then
		qm=$(<"$PAQUETES_QM") || qm=
	else
		qm=$(LC_ALL=C pacman -Qqm 2>/dev/null) || qm=
	fi

	# Un solo awk sobre toda la salida (una llamada a pacman por paquete tardaría
	# segundos). Los paquetes vienen separados por una línea en blanco; la
	# descripción puede seguir en líneas con sangría, que se unen con espacios.
	awk -v aur="$qm" -v prot="$PROTEGIDOS" -v noprot="$NO_PROTEGIDOS" '
		BEGIN { n = split(aur, a, "\n"); for (i = 1; i <= n; i++) esaur[a[i]] = 1 }
		function limpia(s) { gsub(/[\t\r\n]/, " ", s); return s }
		function vuelca(   p, req, k, m, r) {
			if (nombre == "") return
			p = (nombre ~ prot && nombre !~ noprot) ? 1 : 0
			req = 0
			if (reqpor != "None" && reqpor != "") req = split(reqpor, r, /  +/)
			printf "%s\t%s\t%s\t%s\t%d\t%d\t%s\n", nombre, version, tam,
				(nombre in esaur) ? "aur" : "repo", p, req, desc
		}
		/^$/ { vuelca(); nombre = version = tam = reqpor = desc = campo = ""; next }
		/^[A-Za-z][A-Za-z ]*[A-Za-z] *: / || /^[A-Za-z][A-Za-z ]*[A-Za-z] *:$/ {
			i = index($0, ":")
			campo = $0; sub(/ *:.*/, "", campo)
			v = substr($0, i + 1); sub(/^ +/, "", v); sub(/ +$/, "", v)
			if (campo == "Name") nombre = v
			else if (campo == "Version") version = limpia(v)
			else if (campo == "Description") desc = limpia(v)
			else if (campo == "Installed Size") tam = limpia(v)
			else if (campo == "Required By") reqpor = v
			next
		}
		/^ +/ {
			v = $0; sub(/^ +/, "", v); sub(/ +$/, "", v)
			if (campo == "Description") desc = desc " " limpia(v)
			else if (campo == "Required By") reqpor = reqpor "  " v
		}
		END { vuelca() }
	' <<<"$qi" | LC_ALL=C sort -t "$(printf '\t')" -k1,1
}

desinstalar() {
	local p
	if [ "$#" -eq 0 ]; then
		echo 'Uso: paquetes.sh desinstalar <paquete>...' >&2
		return 2
	fi
	# Si alguno está protegido no se quita ninguno: mejor repetir la orden que
	# dejar una desinstalación a medias.
	for p in "$@"; do
		if es_protegido "$p"; then
			echo "No se desinstala nada: «$p» es un paquete protegido (sin él el sistema o el escritorio podrían quedar sin arrancar)." >&2
			return 2
		fi
	done
	# Sin --noconfirm: la pregunta [Y/n] de pacman es la confirmación final.
	# PAQUETES_PACMAN se deja sin comillas a propósito, para admitir una orden
	# con argumentos.
	# shellcheck disable=SC2086
	${PAQUETES_PACMAN:-sudo pacman} -Rns -- "$@"
}

orden=${1:-}
[ "$#" -gt 0 ] && shift
case $orden in
lista)
	lista
	exit $?
	;;
desinstalar)
	desinstalar "$@"
	estado=$?
	# También tras negarse o fallar: la terminal no debe cerrarse sin dejar leer.
	if [ "${PAQUETES_SIN_ESPERA:-}" != 1 ]; then
		printf '\n'
		read -r -p 'Pulsa Enter para cerrar… '
	fi
	exit "$estado"
	;;
*)
	echo 'Uso: paquetes.sh lista | desinstalar <paquete>...' >&2
	exit 2
	;;
esac
