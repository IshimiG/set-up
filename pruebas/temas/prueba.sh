#!/usr/bin/env bash
# Prueba sin pantalla de los temas del escritorio. Cinco partes:
#   - tema.sh, fuera de sesión: el tema activo, lista, poner, alternar, lo que
#     no es un tema, el fichero con basura y que escribe de una vez;
#   - tema.sh y aberracion.sh "dentro" de una sesión de mentira (hyprctl,
#     notify-send y sleep falsos en el PATH): recarga, aviso, el demonio que
#     arranca, pulsa, no se duplica, se para solo al cambiar el tema y con
#     --parar, y ABERRACION=0; y el modo --en-seco, con sus tiempos;
#   - hyprland.lua con un Hyprland de mentira (hypr-simulado.lua, con lua):
#     default da los valores de siempre, liquido las mismas claves, y el borde
#     de la aberración;
#   - hyprland.lua con el Hyprland de verdad, con --verify-config (no arranca
#     nada), en los dos temas;
#   - shared/Theme.qml con qs, en caliente y al arrancar.
# Además, los fragmentos de Ghostty, hyprlock y Neovim (ghostty +validate-config,
# las variables de hyprlock.conf y nvim --headless en cada tema).
# Ninguna toca la sesión: todo va con un $XDG_STATE_HOME y un
# $XDG_RUNTIME_DIR de prueba, sin HYPRLAND_INSTANCE_SIGNATURE de verdad y sin
# bus de notificaciones.
#
#   pruebas/temas/prueba.sh            la prueba, y la carpeta se borra
#   pruebas/temas/prueba.sh --guardar  la deja, para mirar los registros
#
# Hace falta: bash, quickshell (qs) y lua; Hyprland, si está, para la cuarta
# parte. Sale con 1 si algo falla.
set -uo pipefail

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
tema_sh=$repo/.config/hypr/scripts/tema.sh
aberracion_sh=$repo/.config/hypr/scripts/aberracion.sh
hyprland_lua=$repo/.config/hypr/hyprland.lua

for orden in qs lua flock setsid; do
	if ! command -v "$orden" >/dev/null; then
		echo "FALLO  falta $orden" >&2
		exit 1
	fi
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-temas.XXXXXX")
mkdir -p "$tmp/estado" "$tmp/bin" "$tmp/simulado"
mkdir -m 700 "$tmp/run"
sleep_real=$(command -v sleep)

# Nada de esto puede llegar a la sesión de verdad.
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS ABERRACION ABERRACION_TURNOS ABERRACION_SEMILLA
export XDG_STATE_HOME=$tmp/estado XDG_RUNTIME_DIR=$tmp/run
fichero=$XDG_STATE_HOME/escritorio/tema
cerrojo=$XDG_RUNTIME_DIR/escritorio-aberracion.lock

total=0
fallos=0
ok() {
	total=$((total + 1))
	if [[ $1 == 0 ]]; then
		echo "OK     $2"
	else
		echo "FALLO  $2"
		fallos=$((fallos + 1))
	fi
}
# ok, con una condición de [[ ]] o una orden.
si() {
	local msg=$1
	shift
	"$@" >/dev/null 2>&1
	ok $? "$msg"
}
seccion() { printf '\n== %s\n' "$*"; }

# El demonio que quede vivo (de una prueba que falle a medias) se para al salir.
acabar() {
	PATH=$tmp/bin:$PATH "$aberracion_sh" --parar >/dev/null 2>&1
}
trap acabar EXIT

# ---------------------------------------------------------------------------
seccion "tema.sh, sin sesión"

si "sin fichero, el tema es default" test "$("$tema_sh")" = default
si "lista: los dos temas, default marcado" test "$("$tema_sh" lista)" = $'* default\n  liquido'
salida=$("$tema_sh" liquido)
si "tema.sh liquido sale bien" test $? = 0
si "y dice que se aplica al entrar" grep -q "sin sesión" <<<"$salida"
si "el fichero dice liquido (una palabra)" test "$(cat "$fichero")" = liquido
si "tema.sh dice liquido" test "$("$tema_sh")" = liquido
si "la carpeta la crea tema.sh, y el fichero se lee (644)" test "$(stat -c %a "$fichero")" = 644
ino=$(stat -c %i "$fichero")
"$tema_sh" liquido >/dev/null
si "poner el mismo tema otra vez sale bien y no reescribe el fichero" test "$(stat -c %i "$fichero")" = "$ino"
"$tema_sh" alternar >/dev/null
si "alternar: de liquido a default" test "$("$tema_sh")" = default
"$tema_sh" alternar >/dev/null
si "alternar: de default a liquido" test "$("$tema_sh")" = liquido
si "lista: liquido marcado" test "$("$tema_sh" lista)" = $'  default\n* liquido'
"$tema_sh" foo >/dev/null 2>"$tmp/error"
ok $(($? == 0)) "un tema que no existe falla"
si "y lo dice" grep -q "no hay ningún tema «foo»" "$tmp/error"
si "y no toca el fichero" test "$(cat "$fichero")" = liquido
printf 'liquido de mentira\n' >"$fichero"
si "con basura en el fichero, el tema es default" test "$("$tema_sh")" = default
"$tema_sh" alternar >/dev/null
si "y alternar desde la basura va a liquido" test "$(cat "$fichero")" = liquido
si "no quedan temporales en la carpeta" test -z "$(find "${fichero%/*}" -name '.tema.*')"

# ---------------------------------------------------------------------------
seccion "tema.sh y aberracion.sh, en una sesión de mentira"

# hyprctl apunta lo que le piden; notify-send, el aviso; sleep duerme 20 ms,
# así el demonio da muchos turnos en un momento.
cat >"$tmp/bin/hyprctl" <<'FIN'
#!/bin/sh
echo "$*" >>"$PRUEBA_DIR/hyprctl.log"
echo ok
FIN
cat >"$tmp/bin/notify-send" <<'FIN'
#!/bin/sh
echo "$*" >>"$PRUEBA_DIR/notify.log"
FIN
cat >"$tmp/bin/sleep" <<FIN
#!/bin/sh
exec "$sleep_real" 0.02
FIN
chmod +x "$tmp/bin/"*
export PRUEBA_DIR=$tmp
sesion() { PATH=$tmp/bin:$PATH HYPRLAND_INSTANCE_SIGNATURE=prueba-falsa "$@"; }
vivo() { [[ -e $cerrojo ]] && ! flock -n "$cerrojo" true; }
pid_demonio() { head -n1 "$cerrojo" 2>/dev/null; }
esperar() { # hasta 3 s a que se cumpla
	local i
	for i in $(seq 30); do
		"$@" && return 0
		"$sleep_real" 0.1
	done
	return 1
}

"$tema_sh" default >/dev/null
: >"$tmp/hyprctl.log"
sesion "$tema_sh" liquido >/dev/null
si "en sesión, tema.sh recarga Hyprland (reload config-only)" grep -qx "reload config-only" "$tmp/hyprctl.log"
si "y avisa" grep -q "Tema: liquido" "$tmp/notify.log"
si "y arranca el demonio de la aberración" esperar vivo
pid=$(pid_demonio)
si "el cerrojo guarda su PID" grep -qa aberracion "/proc/$pid/cmdline"
si "el demonio pulsa: pone un borde de aberración" esperar grep -qE "^eval escritorio\.aberracion\([12]\)$" "$tmp/hyprctl.log"
sesion "$aberracion_sh"
si "otro arranque no se duplica: sale y el PID sigue siendo el primero" test "$(pid_demonio)" = "$pid"
si "  y el primero sigue vivo" kill -0 "$pid"
printf 'default\n' >"$fichero"
si "se para solo cuando el tema deja de ser liquido" esperar eval '! vivo'
si "  y su proceso ya no está" eval "! kill -0 $pid"

sesion "$tema_sh" liquido >/dev/null
esperar vivo
: >"$tmp/hyprctl.log"
sesion "$tema_sh" default >/dev/null
si "tema.sh default para el demonio" eval '! vivo'
cp "$tmp/hyprctl.log" "$tmp/hyprctl-default.log"
ultimas=$(grep -vE '^eval escritorio\.aberracion\([12]\)$' "$tmp/hyprctl.log" | tail -n2 | tr '\n' '|')
ok $([[ $ultimas == "eval escritorio.aberracion(0)|reload config-only|" ]]; echo $?) "  que deja el borde normal antes de la recarga (log: $ultimas | $(tr '\n' '|' <"$tmp/hyprctl.log" | tail -c 200))"
si "  y no lo vuelve a arrancar en default" eval '! esperar vivo'
si "--parar sin demonio sale bien" sesion "$aberracion_sh" --parar
sesion env ABERRACION=0 "$tema_sh" liquido >/dev/null
"$sleep_real" 0.5
si "con ABERRACION=0, liquido no arranca el demonio" eval '! vivo'
"$aberracion_sh"
si "sin sesión, tampoco" eval '! vivo'
"$tema_sh" default >/dev/null

seccion "aberracion.sh --en-seco"

"$tema_sh" liquido >/dev/null
seco=$(ABERRACION_SEMILLA=11 ABERRACION_TURNOS=60 "$aberracion_sh" --en-seco)
si "sólo imprime esperas y órdenes de hyprctl eval" eval '! grep -vqE "^(espera [0-9]+\.[0-9]{3}|hyprctl eval '"'"'escritorio\.aberracion\([0-2]\)'"'"')$" <<<"$seco"'
# Cada turno empieza con una espera de 4 s o más; lo que va detrás, hasta la
# siguiente, es el pulso (o nada).
informe=$(awk '
	function cerrar() {
		if (!abierto) return
		if (n == 0) { nada++; if (corto > 0) mal++ }
		else {
			pulsos++; if (n == 2) dobles++; else if (n == 1) simples++; else mal++
			if (ultimo != 0) mal++
			if (corto < 0.150 - 1e-9 || corto > 0.600 + 1e-9) mal++
		}
	}
	/^espera/ {
		s = $2 + 0
		if (s >= 4) { cerrar(); abierto = 1; n = 0; corto = 0; ultimo = -1; turnos++; if (s > 25) mal++; next }
		corto += s; next
	}
	/^hyprctl/ { m = $0; gsub(/[^0-9]/, "", m); ultimo = m + 0; if (ultimo > 0) n++ }
	END { cerrar(); printf "%d %d %d %d %d %d\n", turnos, nada, pulsos, simples, dobles, mal }
' <<<"$seco")
read -r turnos nada pulsos simples dobles mal <<<"$informe"
si "da los turnos pedidos ($turnos de 60)" test "$turnos" = 60
si "cada turno espera de 4 a 25 s; cada pulso dura de 150 a 600 ms, con uno o dos parpadeos, y acaba en el borde normal" test "$mal" = 0
si "a veces no hace nada ($nada de 60 turnos; se espera un 40 %)" test "$nada" -ge 12 -a "$nada" -le 36
si "y a veces pulsa, con uno ($simples) y con dos parpadeos ($dobles)" test "$simples" -gt 0 -a "$dobles" -gt 0
otra=$(ABERRACION_SEMILLA=12 ABERRACION_TURNOS=60 "$aberracion_sh" --en-seco)
si "con otra semilla, otra secuencia" test "$seco" != "$otra"
si "con ABERRACION=0 no hace nada" test -z "$(ABERRACION=0 "$aberracion_sh" --en-seco)"
"$tema_sh" default >/dev/null
si "en default no hace nada" test -z "$(ABERRACION_TURNOS=5 "$aberracion_sh" --en-seco)"

# ---------------------------------------------------------------------------
seccion "hyprland.lua, con un Hyprland de mentira"

simular() { # $1: lo que dice el fichero de tema («» = sin fichero)
	local estado=$tmp/simulado/estado-$1
	mkdir -p "$estado/escritorio"
	[[ -n $1 ]] && printf '%s\n' "$1" >"$estado/escritorio/tema"
	XDG_STATE_HOME=$estado lua "$aqui/hypr-simulado.lua" "$hyprland_lua" aberracion
}
simular default >"$tmp/simulado/default.txt"
si "hyprland.lua se ejecuta en default" test $? = 0
simular liquido >"$tmp/simulado/liquido.txt"
si "hyprland.lua se ejecuta en liquido" test $? = 0
simular "" >"$tmp/simulado/sin.txt"
simular basura >"$tmp/simulado/basura.txt"
si "sin fichero, igual que default" cmp -s "$tmp/simulado/sin.txt" "$tmp/simulado/default.txt"
si "con basura, igual que default" cmp -s "$tmp/simulado/basura.txt" "$tmp/simulado/default.txt"

# Los valores de antes de haber temas, tal cual los daba hyprland.lua.
faltan=$(grep -vxF -f "$tmp/simulado/default.txt" <<'FIN'
config decoration.blur.brightness = 1
config decoration.blur.contrast = 0.8916
config decoration.blur.enabled = true
config decoration.blur.new_optimizations = true
config decoration.blur.noise = 0.02
config decoration.blur.passes = 3
config decoration.blur.size = 8
config decoration.blur.vibrancy_darkness = 0
config decoration.blur.vibrancy = 0.25
config decoration.rounding = 10
config decoration.rounding_power = 2
config decoration.shadow.color = 3994688026
config decoration.shadow.enabled = true
config decoration.shadow.range = 4
config decoration.shadow.render_power = 3
config general.border_size = 2
config general.col.active_border = {angle=45, colors={1="rgba(ffffffe6)", 2="rgba(ffffff26)"}}
config general.col.inactive_border = "rgba(ffffff1a)"
config general.gaps_in = 5
config general.gaps_out = 20
hl.animation({bezier="easeOutQuint", enabled=true, leaf="border", speed=5.39})
FIN
)
ok $([[ -z $faltan ]]; echo $?) "default: borde, redondeo, sombra, blur, huecos y animación del borde, los de siempre${faltan:+ (falta: $faltan)}"
capas() { grep -c "^hl.layer_rule(.*ignore_alpha=$2," "$1"; }
si "default: las 9 superficies de Quickshell con ignore_alpha 0.5" test "$(capas "$tmp/simulado/default.txt" 0.5)" = 9
si "liquido: las 9 con ignore_alpha 0.15" test "$(capas "$tmp/simulado/liquido.txt" 0.15)" = 9
si "los dos temas dan las mismas claves de configuración" cmp -s <(grep '^config ' "$tmp/simulado/default.txt" | cut -d= -f1) <(grep '^config ' "$tmp/simulado/liquido.txt" | cut -d= -f1)
si "fuera de lo del tema, liquido no cambia nada (mismas llamadas salvo borde, capas y la aberración)" cmp -s <(grep -vE '^(config |hl\.layer_rule|hl\.animation\(\{.*leaf="border"|aberracion\(|hl\.exec_cmd\(".*aberracion\.sh"\))' "$tmp/simulado/default.txt") <(grep -vE '^(config |hl\.layer_rule|hl\.animation\(\{.*leaf="border"|aberracion\(|hl\.exec_cmd\(".*aberracion\.sh"\))' "$tmp/simulado/liquido.txt")
liq() { grep -F "config $1 = " "$tmp/simulado/liquido.txt" | sed 's/^[^=]*= //'; }
def() { grep -F "config $1 = " "$tmp/simulado/default.txt" | sed 's/^[^=]*= //'; }
si "liquido: blur más grande que default, con más vibrancy y poco grano" test "$(liq decoration.blur.size)" -gt "$(def decoration.blur.size)" && test "$(liq decoration.blur.vibrancy)" != "$(def decoration.blur.vibrancy)" && test "$(liq decoration.blur.noise)" != 0.02
si "liquido: pasadas del blur entre 3 y 5" test "$(liq decoration.blur.passes)" -ge 3 -a "$(liq decoration.blur.passes)" -le 5
# Requisito: las medidas y las formas son las de default; sólo cambia el material.
for clave in general.gaps_in general.gaps_out general.border_size decoration.rounding decoration.rounding_power; do
	si "liquido: $clave igual que default ($(def $clave))" test "$(liq $clave)" = "$(def $clave)"
done
si "liquido: borde activo neutro (blanco con alfa, sin ningún color)" eval 'l=$(liq general.col.active_border); [[ $l == *angle=45* ]] && ! grep -qiE "rgba\((ff3b6b|3be8ff|5ad7ff|8b6cff|ff5cc8|ff9a5a)" <<<"$l" && [[ $(grep -oE "rgba\([0-9a-f]{6}" <<<"$l" | sort -u) == "rgba(ffffff" ]]'
si "liquido: borde inactivo blanco tenue" eval '[[ $(liq general.col.inactive_border) == "\"rgba(ffffff26)\"" ]]'
si "liquido: sombra neutra (negro con alfa)" eval '[[ $(liq decoration.shadow.color) == 1073741824 ]]'
si "liquido: blur con mucha vibrancy y contraste y brillo neutros" test "$(liq decoration.blur.vibrancy)" = 0.8 -a "$(liq decoration.blur.contrast)" = 1 -a "$(liq decoration.blur.brightness)" = 1
si "liquido: el color sólo está en la aberración (franjas rojo y cian), no en el borde normal" eval 'for n in 1 2; do grep "^aberracion($n) " "$tmp/simulado/liquido.txt" | grep -q ff3b6b || exit 1; done; ! grep -q "^config general.col.active_border.*ff3b6b" "$tmp/simulado/liquido.txt"'
bind=$(grep -c '^hl.bind("SUPER + SHIFT + T"' "$tmp/simulado/default.txt")
si "SUPER+SHIFT+T está una sola vez" test "$bind" = 1
si "  y abre/cierra el selector (qs -c temas)" grep -qE '^hl.bind\("SUPER \+ SHIFT \+ T", hl.dsp.exec_cmd\(".*qs -c temas.*"\)\)$' "$tmp/simulado/default.txt"
si "SUPER+SHIFT+CTRL+T lanza tema.sh alternar" grep -qE '^hl.bind\("SUPER \+ SHIFT \+ CTRL \+ T", hl.dsp.exec_cmd\(".*/\.config/hypr/scripts/tema\.sh alternar"\)\)$' "$tmp/simulado/default.txt"
inicio() { sed -n '/^hl.on("hyprland.start"/,/^fin "hyprland.start"/p' "$1"; }
si "liquido arranca aberracion.sh con la sesión" grep -q 'aberracion\.sh' <(inicio "$tmp/simulado/liquido.txt")
si "default no" eval '! grep -q "aberracion\.sh" <(inicio "$tmp/simulado/default.txt")'
normal=$(liq general.col.active_border)
si "escritorio.aberracion(0) deja el borde normal de liquido" grep -qxF "aberracion(0) $normal" "$tmp/simulado/liquido.txt"
si "escritorio.aberracion(1) y (2) ponen bordes con franja roja y cian, distintos del normal" eval 'for n in 1 2; do l=$(grep "^aberracion($n) " "$tmp/simulado/liquido.txt"); [[ $l == *ff3b6b* && $l == *3be8ff* && $l != *"$normal" ]] || exit 1; done'
si "en default, escritorio.aberracion(n) siempre deja el borde normal" test "$(grep -c '^aberracion([0-3]) {angle=45, colors={1="rgba(ffffffe6)", 2="rgba(ffffff26)"}}$' "$tmp/simulado/default.txt")" = 4

# Para Theme.qml: el ignore_alpha de cada tema y las franjas, en #aarrggbb.
ia_default=$(grep -m1 -o 'ignore_alpha=[0-9.]*' "$tmp/simulado/default.txt" | cut -d= -f2)
ia_liquido=$(grep -m1 -o 'ignore_alpha=[0-9.]*' "$tmp/simulado/liquido.txt" | cut -d= -f2)
argb() { sed -E 's/rgba\((..)(..)(..)(..)\)/#\4\1\2\3/'; }
franja_roja=$(grep '^aberracion(1) ' "$tmp/simulado/liquido.txt" | grep -o 'rgba(ff3b6b..)' | head -n1 | argb)
franja_cian=$(grep '^aberracion(1) ' "$tmp/simulado/liquido.txt" | grep -o 'rgba(3be8ff..)' | head -n1 | argb)

# ---------------------------------------------------------------------------
seccion "hyprland.lua, con Hyprland --verify-config"

if command -v Hyprland >/dev/null; then
	verificar() { # $1: tema; $2: fichero de configuración
		local estado=$tmp/simulado/estado-$1
		XDG_STATE_HOME=$estado timeout 30 Hyprland --verify-config -c "$2" 2>&1 | sed -n '/Config parsing result/,$p' | grep -v '^\s*$' | tail -n +2
	}
	cat >"$tmp/simulado/con-aberracion.lua" <<FIN
dofile("$hyprland_lua")
escritorio.aberracion(1)
escritorio.aberracion(2)
escritorio.aberracion(0)
FIN
	for t in default liquido; do
		r=$(verificar "$t" "$hyprland_lua")
		ok $([[ $r == "config ok" ]]; echo $?) "Hyprland da la configuración por buena en $t${r:+ ($r)}"
	done
	r=$(verificar liquido "$tmp/simulado/con-aberracion.lua")
	ok $([[ $r == "config ok" ]]; echo $?) "y también los bordes de escritorio.aberracion en liquido${r:+ ($r)}"
else
	echo "OMITIDA  no hay Hyprland en esta máquina"
fi

# ---------------------------------------------------------------------------
seccion "Ghostty, hyprlock y Neovim"

# tema.sh deja, junto a la palabra, los fragmentos del tema. Sin sesión y sin
# bus: no recarga nada.
rm -rf "$XDG_STATE_HOME/escritorio"
"$tema_sh" liquido >/dev/null
est=$XDG_STATE_HOME/escritorio
si "tema.sh liquido deja ghostty-tema igual que temas/liquido.ghostty" cmp -s "$est/ghostty-tema" "$repo/.config/ghostty/temas/liquido.ghostty"
si "  y hyprlock-tema.conf igual que hyprlock-liquido.conf" cmp -s "$est/hyprlock-tema.conf" "$repo/.config/hypr/temas/hyprlock-liquido.conf"
"$tema_sh" default >/dev/null
si "tema.sh default los cambia por los de default" cmp -s "$est/ghostty-tema" "$repo/.config/ghostty/temas/default.ghostty"
rm -f "$est/ghostty-tema" "$est/hyprlock-tema.conf"
"$tema_sh" aplicar
si "tema.sh aplicar los vuelve a dejar (del tema activo)" test -s "$est/ghostty-tema" -a -s "$est/hyprlock-tema.conf"
si "no quedan temporales de los fragmentos" test -z "$(find "$est" -name '.frag.*')"

if command -v ghostty >/dev/null; then
	gh=$tmp/ghostty
	validar_ghostty() { # $1: tema; saca la configuración efectiva
		local casa=$gh/$1/casa
		rm -rf "$gh/$1"
		mkdir -p "$casa/.local/state/escritorio" "$gh/$1/xdg/ghostty"
		cp "$repo/.config/ghostty/temas/$1.ghostty" "$casa/.local/state/escritorio/ghostty-tema"
		cp "$repo/.config/ghostty/config.ghostty" "$gh/$1/xdg/ghostty/config.ghostty"
		HOME=$casa XDG_CONFIG_HOME=$gh/$1/xdg XDG_STATE_HOME= ghostty +validate-config >"$gh/$1/validar.txt" 2>&1
		echo $? >"$gh/$1/rc"
		HOME=$casa XDG_CONFIG_HOME=$gh/$1/xdg XDG_STATE_HOME= ghostty +show-config 2>/dev/null >"$gh/$1/efectiva.txt"
	}
	for t in default liquido; do
		validar_ghostty $t
		si "Ghostty valida config.ghostty con el fragmento de $t" test "$(cat "$gh/$t/rc")" = 0 -a ! -s "$gh/$t/validar.txt"
	done
	ef() { grep -m1 "^$2 = " "$gh/$1/efectiva.txt" | sed 's/^[^=]*= //'; }
	si "Ghostty default: Horizon con los colores de caelestia, #131317 al 85 %, Noto Sans Mono" test "$(ef default background)" = "#131317" -a "$(ef default background-opacity)" = 0.85 -a "$(ef default font-family)" = "Noto Sans Mono" -a "$(ef default foreground)" = "#e5e1e7"
	si "Ghostty liquido: mismos colores que default (fondo, texto, cursor, selección y paleta)" eval 'cmp -s <(grep -E "^(background|foreground|cursor-color|selection-background|palette) " "'"$gh"'/default/efectiva.txt") <(grep -E "^(background|foreground|cursor-color|selection-background|palette) " "'"$gh"'/liquido/efectiva.txt")'
	si "Ghostty liquido: sólo más translúcido (0,70 en vez de 0,85)" test "$(ef liquido background-opacity)" = 0.70 -o "$(ef liquido background-opacity)" = 0.7
	si "Ghostty liquido: misma letra, tamaño, ventana y desenfoque que default" eval 'for k in font-family font-size window-width window-height background-blur-radius; do [[ $(ef liquido $k) == $(ef default $k) ]] || exit 1; done'
	si "Ghostty: el fragmento de liquido no tiene ningún color" test -z "$(grep -E '^(foreground|background|cursor|selection|palette)' "$repo/.config/ghostty/temas/liquido.ghostty" | grep -v '^background-opacity')"
	# Sin el fichero de estado (máquina nueva) la terminal es la de default.
	rm -f "$gh/liquido/casa/.local/state/escritorio/ghostty-tema"
	si "Ghostty sin fragmento de estado: valida y es la de default" eval 'HOME='"$gh"'/liquido/casa XDG_CONFIG_HOME='"$gh"'/liquido/xdg ghostty +validate-config && [[ $(HOME='"$gh"'/liquido/casa XDG_CONFIG_HOME='"$gh"'/liquido/xdg ghostty +show-config | grep -m1 "^background = ") == "background = #131317" ]]'
else
	echo "OMITIDA  no hay ghostty en esta máquina"
fi

# hyprlock no se puede probar sin bloquear la pantalla: se comprueba que todas
# las variables que usa hyprlock.conf las dan los dos temas (y el propio
# fichero, por si faltara el de estado) y que default es lo de siempre.
lock=$repo/.config/hypr/hyprlock.conf
usadas=$(grep -v '^\s*#' "$lock" | grep -oE '\$(fondo|campo|texto)_?[a-z]*' | sort -u)
for t in default liquido; do
	frag=$repo/.config/hypr/temas/hyprlock-$t.conf
	definidas=$(grep -oE '^\$[a-z_]+' "$frag" | sort -u)
	si "hyprlock $t: el fragmento define todas las variables que usa hyprlock.conf" test -z "$(comm -23 <(echo "$usadas") <(echo "$definidas"))"
	si "hyprlock $t: sin variables de más" test -z "$(comm -13 <(echo "$usadas") <(echo "$definidas"))"
done
si "hyprlock: los valores por defecto de hyprlock.conf son los del fragmento default" eval 'diff <(grep -E "^\\$(fondo|campo|texto)[a-z_]* =" "'"$lock"'" | sort) <(grep -E "^\\$[a-z_]+ =" "'"$repo"'/.config/hypr/temas/hyprlock-default.conf" | sort)'
si "hyprlock: hace source del fragmento antes de usar las variables" eval '[[ $(grep -n "^source = ~/.local/state/escritorio/hyprlock-tema.conf" "'"$lock"'" | cut -d: -f1) -lt $(grep -n "^background {" "'"$lock"'" | cut -d: -f1) ]]'
si "hyprlock: los dos fragmentos pintan lo mismo en los mismos sitios (sólo cambian los valores)" cmp -s <(grep -oE '^\$[a-z_]+' "$repo/.config/hypr/temas/hyprlock-default.conf") <(grep -oE '^\$[a-z_]+' "$repo/.config/hypr/temas/hyprlock-liquido.conf")
si "hyprlock liquido: borde del campo blanco neutro translúcido, sin iridiscencia" grep -qE '^\$campo_borde = rgba\(255, 255, 255, 0\.[0-9]+\)$' "$repo/.config/hypr/temas/hyprlock-liquido.conf"

# Neovim ya no depende del tema: sin «aurora» ni vigilante, Horizon siempre.
si "nvim: no hay colorscheme aurora ni config/tema.lua" test ! -e "$repo/.config/nvim/colors/aurora.lua" -a ! -e "$repo/.config/nvim/lua/config/tema.lua"
si "nvim: la configuración no menciona el tema del escritorio" eval '! grep -rqi "aurora\|config.tema\|escritorio/tema" "'"$repo"'/.config/nvim"'
if command -v nvim >/dev/null && [[ -d ${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/LazyVim ]]; then
	nv=$tmp/nvim
	mkdir -p "$nv/cfg" "$nv/estado"
	ln -s "$repo/.config/nvim" "$nv/cfg/nvim"
	for t in default liquido; do
		mkdir -p "$nv/estado/escritorio"
		printf '%s\n' "$t" >"$nv/estado/escritorio/tema"
		salida=$(XDG_CONFIG_HOME=$nv/cfg XDG_STATE_HOME=$nv/estado timeout 120 nvim --headless -c 'lua vim.defer_fn(function() io.stdout:write("CS=" .. vim.g.colors_name .. " MSG=[" .. vim.api.nvim_exec2("messages", { output = true }).output .. "]\n"); vim.cmd("qa!") end, 3000)' 2>&1)
		si "nvim con el tema $t: Horizon y sin mensajes" grep -qx 'CS=horizon MSG=\[\]' <<<"$salida"
	done
else
	echo "OMITIDA  no hay nvim con LazyVim instalado en esta máquina"
fi

# ---------------------------------------------------------------------------
seccion "shared/Theme.qml"

mkdir -p "$tmp/qml"
cp "$aqui/shell.qml" "$tmp/qml/"
cp -r "$repo/.config/quickshell/shared" "$tmp/qml/shared"
# La carpeta del estado existe y el fichero no: así arranca una máquina nueva
# después de setup.sh.
rm -f "$fichero"
qml() {
	(cd "$tmp/qml" && PRUEBA_MODO=$1 PRUEBA_TEMA_SH=$tema_sh PRUEBA_IA_DEFAULT=$ia_default PRUEBA_IA_LIQUIDO=$ia_liquido \
		PRUEBA_FRANJA_ROJA=$franja_roja PRUEBA_FRANJA_CIAN=$franja_cian QT_QPA_PLATFORM=offscreen timeout 60 qs -p ./shell.qml 2>&1) |
		tee -a "$tmp/qs.log" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E "qml: " | sed -E 's/^.*qml: //'
}
resultado=$(qml "")
printf '%s\n' "$resultado" | grep -v '^Resultado:'
si "la prueba de Theme en caliente llega al final" grep -q '^Resultado:' <<<"$resultado"
printf 'liquido\n' >"$fichero"
resultado2=$(qml inicio)
printf '%s\n' "$resultado2" | grep -v '^Resultado:'
si "la prueba de Theme al arrancar llega al final" grep -q '^Resultado:' <<<"$resultado2"
if grep -qiE 'unresolvable|is not a type|ReferenceError|TypeError|Cannot assign' "$tmp/qs.log"; then
	ok 1 "qs no da errores de QML ($(grep -m1 -iE 'unresolvable|is not a type|ReferenceError|TypeError|Cannot assign' "$tmp/qs.log" | sed -E 's/\x1b\[[0-9;]*m//g'))"
else
	ok 0 "qs no da errores de QML"
fi
for r in "$resultado" "$resultado2"; do
	t=$(grep -c '^OK ' <<<"$r")
	f=$(grep -c '^FALLO ' <<<"$r")
	total=$((total + t + f))
	fallos=$((fallos + f))
done

echo
echo "Resultado: $total comprobaciones, $fallos fallos"
if [[ ${1:-} == --guardar ]]; then
	echo "Registros en $tmp"
else
	rm -rf "$tmp"
fi
((fallos == 0))
