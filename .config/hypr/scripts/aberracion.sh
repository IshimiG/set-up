#!/usr/bin/env bash
# Aberración cromática en el borde de la ventana activa, a pulsos aleatorios.
# Sólo en el tema liquido (ver ABERRACIÓN en hyprland.lua).
#
#   aberracion.sh            el demonio: sigue mientras el tema sea liquido
#   aberracion.sh --parar    para el que esté en marcha (deja el borde normal)
#   aberracion.sh --en-seco  no toca Hyprland ni espera: imprime cada orden
#                            (hyprctl eval …) y cada espera (espera <s>)
#
# Cada turno espera de 4 a 25 s, al azar, y cuatro de cada diez veces no hace
# nada. Las demás, un pulso de 150 a 600 ms: el borde de la aberración, con uno
# o dos parpadeos (el segundo con las franjas cambiadas de lado), y vuelta al
# borde normal. Los colores no están aquí: hyprctl eval llama a
# escritorio.aberracion(n) de hyprland.lua (hyprctl keyword no funciona con la
# configuración en Lua), que pone el borde n del tema activo o, con 0, el
# normal.
#
# Lo arrancan hyprland.lua (al empezar la sesión, si el tema es liquido) y
# tema.sh (al cambiar de tema), y se para solo en cuanto el tema deja de ser
# liquido. No se duplica: un cerrojo (flock) en $XDG_RUNTIME_DIR, que guarda
# también el PID para --parar.
#
# Variables:
#   ABERRACION=0          apagado: sale sin hacer nada
#   ABERRACION_TURNOS=n   sale después de n turnos (en seco, 10 si no se dice)
#   ABERRACION_SEMILLA=n  semilla del azar: la misma secuencia cada vez

set -uo pipefail

# Los temas con aberración (los que tienen `aberracion` en hyprland.lua).
readonly CON_ABERRACION=(liquido)

aqui=$(dirname "$(readlink -f "$0")")
readonly CERROJO="${XDG_RUNTIME_DIR:-/tmp}/escritorio-aberracion.lock"

en_seco=false
case "${1:-}" in
"") ;;
--en-seco) en_seco=true ;;
--parar)
	# Nadie tiene el cerrojo: no hay demonio que parar.
	[[ -e $CERROJO ]] || exit 0
	if flock -n "$CERROJO" true; then
		exit 0
	fi
	# El demonio toma el cerrojo y un instante después escribe su PID: si
	# se llega entre las dos cosas (el fichero aún guarda el del anterior), se
	# espera a que aparezca el bueno (hasta 1 s).
	# Sin esto, --parar no mataba al que acababa de arrancar y el borde normal
	# llegaba después de la recarga (era la comprobación inestable de la prueba).
	for _ in $(seq 20); do
		pid=$(head -n1 "$CERROJO" 2>/dev/null)
		[[ $pid =~ ^[0-9]+$ ]] && grep -qa aberracion "/proc/$pid/cmdline" 2>/dev/null && break
		sleep 0.05
	done
	if [[ $pid =~ ^[0-9]+$ ]] && grep -qa aberracion "/proc/$pid/cmdline" 2>/dev/null; then
		kill -TERM "$pid" 2>/dev/null
		# Espera a que suelte el cerrojo: para entonces ya ha dejado el borde
		# normal.
		flock -w 3 "$CERROJO" true
	fi
	exit 0
	;;
*)
	printf 'uso: %s [--en-seco | --parar]\n' "${0##*/}" >&2
	exit 1
	;;
esac

[[ ${ABERRACION:-1} == 0 ]] && exit 0

con_aberracion() {
	local t a
	t=$("$aqui/tema.sh")
	for a in "${CON_ABERRACION[@]}"; do
		[[ $t == "$a" ]] && return 0
	done
	return 1
}

con_aberracion || exit 0

if ! $en_seco && [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
	# Sin sesión de Hyprland no hay borde que tocar.
	exit 0
fi

[[ -n ${ABERRACION_SEMILLA:-} ]] && RANDOM=$ABERRACION_SEMILLA
turnos=${ABERRACION_TURNOS:-}
$en_seco && turnos=${turnos:-10}

# El borde n de la aberración, o el normal con 0.
borde() {
	if $en_seco; then
		echo "hyprctl eval 'escritorio.aberracion($1)'"
	elif ! hyprctl eval "escritorio.aberracion($1)" >/dev/null 2>&1; then
		# Hyprland ya no está, o su configuración no tiene la función.
		exit 0
	fi
}

# Espera en milisegundos. El sleep va en segundo plano para que una señal
# (--parar) no tenga que esperar a que acabe.
dormido=""
espera() {
	local s
	s=$(printf '%d.%03d' $(($1 / 1000)) $(($1 % 1000)))
	if $en_seco; then
		echo "espera $s"
	else
		sleep "$s" &
		dormido=$!
		wait "$dormido"
		dormido=""
	fi
}

salir() {
	[[ -n $dormido ]] && kill "$dormido" 2>/dev/null
	borde 0
	exit 0
}
trap salir TERM INT HUP

# Uno solo a la vez. El cerrojo se abre sin truncar para no borrar el PID del
# que ya lo tiene; sólo el que lo consigue escribe el suyo.
exec 9>>"$CERROJO" || exit 1
flock -n 9 || exit 0
printf '%s\n' "$$" >"$CERROJO"
# (Va después del trap de arriba: en cuanto el PID está en el cerrojo, --parar
# puede mandar TERM, y sin trap el demonio moriría sin dejar el borde normal.)

n=0
while [[ -z $turnos ]] || ((n < turnos)); do
	n=$((n + 1))
	# De 4 a 25 s, en décimas.
	espera $(((RANDOM % 211 + 40) * 100))
	# El tema ha podido cambiar mientras esperaba: se sale dejando el borde
	# normal (y no a secas: tema.sh escribe el tema antes de llamar a --parar,
	# y si el demonio salía solo, la recarga se encontraba sin borde normal
	# puesto; era la comprobación inestable de la prueba).
	con_aberracion || salir
	# Cuatro de cada diez turnos, nada.
	((RANDOM % 100 < 40)) && continue

	# El pulso entero, de 150 a 600 ms, y por qué borde empieza.
	total=$((RANDOM % 451 + 150))
	primero=$((RANDOM % 2 + 1))
	if ((RANDOM % 2)); then
		borde "$primero"
		espera "$total"
	else
		# Dos parpadeos: 45 % encendido, 20 % apagado y el resto con las
		# franjas al revés.
		a=$((total * 45 / 100))
		b=$((total * 20 / 100))
		borde "$primero"
		espera "$a"
		borde 0
		espera "$b"
		borde $((3 - primero))
		espera $((total - a - b))
	fi
	borde 0
done

exit 0
