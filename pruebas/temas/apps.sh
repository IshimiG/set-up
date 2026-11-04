#!/usr/bin/env bash
# Prueba sin pantalla del tema en las aplicaciones (hypr/scripts/tema-apps.sh):
#   - la lista de temas de tema.sh y sus datos (.config/escritorio/temas);
#   - lo que escribe en cada tema (ghostty.conf, nvim.lua, fuzzel.ini, foot.ini
#     y btop.theme) y que Ghostty, foot y fuzzel lo dan por bueno, con los de
#     verdad si están (+validate-config, +show-config, --check-config);
#   - que default, y liquido, dejan todo como antes de haber temas: la
#     configuración efectiva de Ghostty es la misma con y sin ghostty.conf, y
#     sus literales, los de fuzzel, foot, btop y Neovim, los de antes;
#   - que repetirlo no toca nada, que un tema que no existe es default, que
#     unos datos malos no escriben nada y la letra de reserva;
#   - tema.sh, que lo llama al poner un tema;
#   - el aviso a lo abierto (SIGUSR2), con procesos de mentira: sólo a los de
#     este HOME que la atrapan, y sólo si algo cambió;
#   - lua/config/tema.lua de Neovim sin plugins (nvim --clean): lee el fichero,
#     el cond de los plugins y el vigilante, que cambia el colorscheme en
#     caliente. Neovim entero, con LazyVim, en pruebas/temas/nvim.sh.
# Todo va con un HOME de prueba (y su ~/.local/state): no toca ni avisa a nada
# de la sesión de verdad.
#
#   pruebas/temas/apps.sh            la prueba, y la carpeta se borra
#   pruebas/temas/apps.sh --guardar  la deja, para mirar lo que escribe
#
# Hace falta bash y lua; ghostty, foot, fuzzel y nvim, si están. Sale con 1 si
# algo falla.
set -uo pipefail

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
tema_sh=$repo/.config/hypr/scripts/tema.sh
apps_sh=$repo/.config/hypr/scripts/tema-apps.sh
temas_dir=$repo/.config/escritorio/temas
readonly TEMAS=(default liquido catppuccin tokyonight gruvbox kanagawa phosphor)
readonly FICHEROS=(ghostty.conf nvim.lua fuzzel.ini foot.ini btop.theme)

if ! command -v lua >/dev/null; then
	echo "FALLO  falta lua" >&2
	exit 1
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-temas-apps.XXXXXX")
mkdir -p "$tmp/home" "$tmp/bin" "$tmp/gen" "$tmp/falsos"

# Nada de esto puede llegar a la sesión de verdad: otro HOME, sin sesión ni bus,
# y sin avisar a nadie salvo donde se prueba el aviso.
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS
unset XDG_STATE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
export HOME=$tmp/home TEMA_APPS_RECARGAR=0
estado=$HOME/.local/state/escritorio

# Las letras, todas «instaladas» (si no, lo que se escribe dependería de la
# máquina); con PRUEBA_SIN_LETRAS, ninguna.
cat >"$tmp/bin/fc-list" <<'FIN'
#!/bin/sh
[ -n "${PRUEBA_SIN_LETRAS:-}" ] || echo "Letra de mentira"
FIN
chmod +x "$tmp/bin/fc-list"
export PATH=$tmp/bin:$PATH

# La configuración del repo, en el HOME de prueba, como la deja setup.sh.
mkdir -p "$HOME/.config/ghostty" "$HOME/.config/fuzzel" "$HOME/.config/foot"
ln -s "$repo/.config/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
ln -s "$repo/.config/fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"
ln -s "$repo/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"

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
si() {
	local msg=$1
	shift
	"$@" >/dev/null 2>&1
	ok $? "$msg"
}
seccion() { printf '\n== %s\n' "$*"; }

pids=()
acabar() {
	((${#pids[@]})) && kill "${pids[@]}" 2>/dev/null
	wait 2>/dev/null
}
trap acabar EXIT

# Un dato de un tema, siguiendo su «como».
dato() {
	local f=$temas_dir/$1.conf como
	como=$(sed -n 's/^como=//p' "$f")
	[[ -n $como ]] && f=$temas_dir/$como.conf
	sed -n "s/^$2=//p" "$f" | tail -n1
}
# Las líneas que no son comentario ni blancas.
datos() { grep -vE '^[[:space:]]*(#|--|$)' "$1"; }
# Para ver si algo cambió: inodo y hora de cada fichero.
huella() { (cd "$estado" && stat -c '%n %i %Y.%y' "${FICHEROS[@]}" 2>&1); }
hay_ghostty=false
command -v ghostty >/dev/null && hay_ghostty=true
# La configuración efectiva de Ghostty en el HOME de prueba.
efectiva() { timeout 20 ghostty +show-config </dev/null 2>/dev/null; }

# ---------------------------------------------------------------------------
seccion "Los temas y sus datos"

si "tema.sh lista: los 7, en orden, con default marcado" test "$("$tema_sh" lista)" = "$(printf '* default'; printf '\n  %s' "${TEMAS[@]:1}")"
falta=""
for t in "${TEMAS[@]}"; do [[ -f $temas_dir/$t.conf ]] || falta+=" $t"; done
ok $([[ -z $falta ]]; echo $?) "cada tema tiene su temas/<tema>.conf${falta:+ (falta:$falta)}"
sobra=""
for f in "$temas_dir"/*.conf; do
	b=${f##*/}
	b=${b%.conf}
	[[ " ${TEMAS[*]} " == *" $b "* ]] || sobra+=" $b"
done
ok $([[ -z $sobra ]]; echo $?) "y no hay datos de un tema que tema.sh no tenga${sobra:+ (sobra:$sobra)}"
si "liquido usa los datos de default" test "$(sed -n 's/^como=//p' "$temas_dir/liquido.conf")" = default

# ---------------------------------------------------------------------------
seccion "Lo que escribe en cada tema"

for t in "${TEMAS[@]}"; do
	"$apps_sh" "$t" >"$tmp/gen/$t.out" 2>"$tmp/gen/$t.err"
	rc=$?
	mkdir -p "$tmp/gen/$t"
	for f in "${FICHEROS[@]}"; do cp -p "$estado/$f" "$tmp/gen/$t/" 2>/dev/null; done
	g=$tmp/gen/$t
	ok $([[ $rc == 0 && ! -s $tmp/gen/$t.err ]]; echo $?) "$t: tema-apps.sh sale bien y sin avisos$( ((rc)) && echo " (sale con $rc)")"
	falta=""
	for f in "${FICHEROS[@]}"; do [[ -s $g/$f && $(stat -c %a "$g/$f") == 644 ]] || falta+=" $f"; done
	ok $([[ -z $falta ]]; echo $?) "$t: escribe los cinco ficheros (644)${falta:+ (mal:$falta)}"

	# Ghostty: lo de los datos, tal cual.
	esperado=$(
		echo "theme = $(dato "$t" ghostty_tema)"
		echo "background = $(dato "$t" fondo)"
		echo "foreground = $(dato "$t" texto)"
		echo "cursor-color = $(dato "$t" cursor)"
		echo "selection-background = $(dato "$t" seleccion)"
		for i in {0..15}; do echo "palette = $i=$(dato "$t" "ansi$i")"; done
		echo "font-family = $(dato "$t" fuente)"
		echo "background-opacity = $(dato "$t" opacidad)"
		echo "background-blur-radius = $(dato "$t" desenfoque)"
	)
	faltan=$(grep -vxF -f "$g/ghostty.conf" <<<"$esperado")
	ok $([[ -z $faltan ]]; echo $?) "$t: ghostty.conf con el tema, los colores, la paleta, la letra y la transparencia de sus datos${faltan:+ (falta: ${faltan//$'\n'/, })}"
	si "$t: ghostty.conf da los 19 colores de la paleta (los 16 a 18, los suyos o los de xterm)" test "$(grep -c '^palette = ' "$g/ghostty.conf")" = 19
	si "$t: y vacía la lista de letras antes de poner la suya" grep -qxF 'font-family = ""' "$g/ghostty.conf"
	if $hay_ghostty; then
		si "$t: Ghostty tiene el tema de base «$(dato "$t" ghostty_tema)»" grep -qxF "$(dato "$t" ghostty_tema) (resources)" <(ghostty +list-themes --plain 2>/dev/null)
		r=$(timeout 20 ghostty +validate-config --config-file="$HOME/.config/ghostty/config.ghostty" </dev/null 2>&1)
		ok $([[ $? == 0 && -z $r ]]; echo $?) "$t: Ghostty da por buena la configuración con su ghostty.conf${r:+ ($r)}"
		efectiva >"$g/ghostty.efectiva"
		esperado=$(
			echo "theme = $(dato "$t" ghostty_tema)"
			echo "background = $(dato "$t" fondo)"
			echo "foreground = $(dato "$t" texto)"
			echo "font-family = $(dato "$t" fuente)"
			echo "palette = 1=$(dato "$t" ansi1)"
		)
		faltan=$(grep -vxF -f "$g/ghostty.efectiva" <<<"$esperado")
		ok $([[ -z $faltan ]]; echo $?) "$t: y es lo que Ghostty acaba usando (+show-config)${faltan:+ (falta: ${faltan//$'\n'/, })}"
		n=$(grep -c '^font-family = ' "$g/ghostty.efectiva")
		si "$t:   con una sola letra, la del tema ($n)" test "$n" = 1
	fi

	# Neovim.
	cs=$(lua - "$g/nvim.lua" <<<'local t = dofile(arg[1]); io.write(type(t) == "table" and tostring(t.colorscheme) or "")' 2>&1)
	si "$t: nvim.lua devuelve el colorscheme de sus datos (${cs})" test "$cs" = "$(dato "$t" nvim)"

	# fuzzel: sus colores, en el orden de los datos.
	esperado=$(datos "$temas_dir/$( [[ $t == liquido ]] && echo default || echo "$t").conf" | sed -n 's/^fuzzel_//p')
	si "$t: fuzzel.ini lleva [colors] con los fuzzel_ de sus datos, en orden" test "$(datos "$g/fuzzel.ini")" = "$(printf '[colors]\n%s' "$esperado")"
	if command -v fuzzel >/dev/null; then
		si "$t: fuzzel da por buena su configuración con el include" fuzzel --check-config
	fi

	# foot.
	si "$t: foot.ini va en [colors-dark] y pone la transparencia" grep -qxF "alpha=$(dato "$t" foot_alpha | grep . || dato "$t" opacidad)" "$g/foot.ini"
	if command -v foot >/dev/null; then
		si "$t: foot da por buena su configuración con el include" foot --check-config
	fi

	# btop: el tema de temas/btop, entero.
	si "$t: btop.theme es btop/$(dato "$t" btop).theme" test "$(datos "$g/btop.theme")" = "$(datos "$temas_dir/btop/$(dato "$t" btop).theme")"
done
si "no quedan temporales en la carpeta" test -z "$(find "$estado" -name '.*')"

seccion "Cada tema, distinto"
for a in catppuccin tokyonight gruvbox kanagawa phosphor; do
	si "$a: Ghostty, Neovim, fuzzel y btop, distintos de default" eval "! cmp -s '$tmp/gen/$a/ghostty.conf' '$tmp/gen/default/ghostty.conf' && ! cmp -s '$tmp/gen/$a/nvim.lua' '$tmp/gen/default/nvim.lua' && ! cmp -s '$tmp/gen/$a/fuzzel.ini' '$tmp/gen/default/fuzzel.ini' && ! cmp -s '$tmp/gen/$a/btop.theme' '$tmp/gen/default/btop.theme'"
	si "$a: foot, con los colores del tema" grep -qx "background=$(dato "$a" fondo | tr -d '#')" "$tmp/gen/$a/foot.ini"
done
si "gruvbox y phosphor, opacos y sin blur (en Ghostty y en foot)" eval "grep -qx 'background-opacity = 1.0' '$tmp/gen/gruvbox/ghostty.conf' && grep -qx 'background-blur-radius = 0' '$tmp/gen/phosphor/ghostty.conf' && grep -qx 'blur=no' '$tmp/gen/gruvbox/foot.ini' && grep -qx 'alpha=1.0' '$tmp/gen/phosphor/foot.ini'"
si "kanagawa pone sus colores 16 y 17, y el 18 vuelve al de xterm" eval "grep -qx 'palette = 16=#ffa066' '$tmp/gen/kanagawa/ghostty.conf' && grep -qx 'palette = 18=#000087' '$tmp/gen/kanagawa/ghostty.conf'"
si "catppuccin devuelve el 16 al de xterm (default lo cambia)" grep -qx 'palette = 16=#000000' "$tmp/gen/catppuccin/ghostty.conf"

# ---------------------------------------------------------------------------
seccion "default: lo de antes de haber temas"

# Lo que tenía config.ghostty antes de haber temas, tal cual.
literales='theme = Horizon
foreground = #e5e1e7
background = #131317
cursor-color = #c6c4e0
selection-background = #c6c4e0
palette = 0=#353434
palette = 1=#ac73ff
palette = 2=#44def5
palette = 3=#ffdcf2
palette = 4=#99aad8
palette = 5=#b49fea
palette = 6=#9dceff
palette = 7=#e8d3de
palette = 8=#ac9fa9
palette = 9=#c093ff
palette = 10=#89ecff
palette = 11=#fff0f6
palette = 12=#b5c1dd
palette = 13=#c9b5f4
palette = 14=#bae0ff
palette = 15=#ffffff
palette = 16=#c2c1ff
palette = 17=#c6c4e0
palette = 18=#f5b2e0
font-family = Noto Sans Mono
background-opacity = 0.85
background-blur-radius = 20'
del_tema='^(theme|foreground|background|cursor-color|cursor-text|selection-background|selection-foreground|palette|font-family|background-opacity|background-blur-radius) = '
si "config.ghostty guarda de reserva los literales de antes" test "$(grep -E "$del_tema" "$repo/.config/ghostty/config.ghostty" | sort)" = "$(sort <<<"$literales")"
si "y el ghostty.conf de default pone esos mismos" test "$(grep -E "$del_tema" "$tmp/gen/default/ghostty.conf" | grep -vxF 'font-family = ""' | sort)" = "$(sort <<<"$literales")"
si "liquido escribe lo mismo que default, byte a byte" eval 'for f in "${FICHEROS[@]}"; do cmp -s "$tmp/gen/liquido/$f" "$tmp/gen/default/$f" || exit 1; done'
si "config.ghostty carga el tema al final y antes que lo del equipo" test "$(grep '^config-file' "$repo/.config/ghostty/config.ghostty" | tr '\n' '|')" = "config-file = ?~/.local/state/escritorio/ghostty.conf|config-file = ?equipo.ghostty|"
if $hay_ghostty; then
	mv "$estado/ghostty.conf" "$tmp/ghostty.conf.aparte"
	efectiva >"$tmp/ghostty.sin-tema"
	mv "$tmp/ghostty.conf.aparte" "$estado/ghostty.conf"
	"$apps_sh" default >/dev/null 2>&1
	efectiva >"$tmp/ghostty.con-default"
	si "Ghostty, sin ghostty.conf: los literales de antes" test -z "$(grep -vxF -f "$tmp/ghostty.sin-tema" <<<"$(grep -v '^background-blur-radius' <<<"$literales"; echo 'background-blur = 20')")"
	si "Ghostty con el ghostty.conf de default: exactamente lo mismo que sin él (+show-config entero)" cmp -s "$tmp/ghostty.sin-tema" "$tmp/ghostty.con-default"
	"$apps_sh" liquido >/dev/null 2>&1
	si "  y con el de liquido, también" cmp -s "$tmp/ghostty.sin-tema" <(efectiva)
	"$apps_sh" default >/dev/null 2>&1
fi
si "Neovim en default: horizon" grep -qx 'return { colorscheme = "horizon" }' "$tmp/gen/default/nvim.lua"
# Los colores que tenía el fuzzel.ini de la torre antes de haber temas.
si "fuzzel en default: los colores de antes (Tokyo Night)" test "$(datos "$tmp/gen/default/fuzzel.ini")" = '[colors]
background=1a1b26a6
text=c0caf5ff
prompt=bb9af7ff
placeholder=565f89cc
input=c0caf5ff
match=7dcfffff
selection=c0caf526
selection-text=ffffffff
selection-match=7dcfffff
border=c0caf54d'
si "foot en default: sus colores de fábrica, al 78 % y con blur (lo de antes)" test "$(datos "$tmp/gen/default/foot.ini")" = $'[colors-dark]\nalpha=0.78\nblur=yes'
si "btop en default: el tema caelestia de antes" eval "grep -qx 'theme\[main_bg\]=#131317' '$tmp/gen/default/btop.theme' && grep -qx 'theme\[main_fg\]=#e5e1e7' '$tmp/gen/default/btop.theme' && test \$(datos '$tmp/gen/default/btop.theme' | wc -l) = 42"

# ---------------------------------------------------------------------------
seccion "Repetirlo no toca nada"

"$apps_sh" default >/dev/null 2>&1
antes=$(huella)
salida=$("$apps_sh" default 2>&1)
si "default otra vez: no dice nada" test -z "$salida"
si "  y no reescribe ningún fichero (mismo inodo y hora)" test "$(huella)" = "$antes"
salida=$("$apps_sh" liquido 2>&1)
si "de default a liquido: no cambia nada" test -z "$salida" -a "$(huella)" = "$antes"
"$apps_sh" catppuccin >/dev/null 2>&1
"$apps_sh" default >/dev/null 2>&1
si "default → catppuccin → default: los mismos ficheros que la primera vez" eval 'for f in "${FICHEROS[@]}"; do cmp -s "$estado/$f" "$tmp/gen/default/$f" || exit 1; done'
salida=$("$apps_sh" kanagawa 2>&1)
si "al cambiar, dice qué ha cambiado" grep -q "aplicaciones (kanagawa): ghostty.conf nvim.lua fuzzel.ini foot.ini btop.theme" <<<"$salida"
si "no quedan temporales en la carpeta" test -z "$(find "$estado" -name '.*')"

# ---------------------------------------------------------------------------
seccion "Lo que no es un tema"

"$apps_sh" catppuccin >/dev/null 2>&1
"$apps_sh" foo >/dev/null 2>"$tmp/error"
ok $? "un tema que no existe sale bien"
si "  y lo dice" grep -q "no hay ningún tema «foo»; pongo default" "$tmp/error"
si "  y pone default" eval 'for f in "${FICHEROS[@]}"; do cmp -s "$estado/$f" "$tmp/gen/default/$f" || exit 1; done'
"$apps_sh" catppuccin >/dev/null 2>&1
"$apps_sh" ../../etc/passwd >/dev/null 2>&1
si "un nombre con barras tampoco es un tema: default" cmp -s "$estado/nvim.lua" "$tmp/gen/default/nvim.lua"
printf 'catppuccin\n' >"$estado/tema"
"$apps_sh" >/dev/null 2>&1
si "sin nombre, el tema activo (catppuccin)" cmp -s "$estado/nvim.lua" "$tmp/gen/catppuccin/nvim.lua"
printf 'catppuccin de mentira\n' >"$estado/tema"
"$apps_sh" >/dev/null 2>&1
si "con basura en el fichero del tema, default" cmp -s "$estado/nvim.lua" "$tmp/gen/default/nvim.lua"
rm -f "$estado/tema"
"$apps_sh" catppuccin >/dev/null 2>&1
"$apps_sh" >/dev/null 2>&1
si "sin fichero del tema, default" cmp -s "$estado/nvim.lua" "$tmp/gen/default/nvim.lua"

# Datos malos, en una copia de los scripts y los temas.
copia=$tmp/copia/.config
mkdir -p "$copia/hypr/scripts" "$copia/escritorio"
cp "$tema_sh" "$apps_sh" "$copia/hypr/scripts/"
cp -r "$temas_dir" "$copia/escritorio/temas"
sed 's/^fondo=.*/fondo=#12345/' "$temas_dir/catppuccin.conf" >"$copia/escritorio/temas/roto.conf"
printf 'como=noexiste\n' >"$copia/escritorio/temas/huerfano.conf"
printf 'esto no es clave=valor\n' >"$copia/escritorio/temas/raro.conf"
grep -v '^btop=' "$temas_dir/catppuccin.conf" >"$copia/escritorio/temas/sinbtop.conf"
"$copia/hypr/scripts/tema-apps.sh" default >/dev/null 2>&1
antes=$(huella)
for t in roto huerfano raro sinbtop; do
	"$copia/hypr/scripts/tema-apps.sh" "$t" >/dev/null 2>"$tmp/error-$t"
	ok $(($? == 0)) "datos malos ($t): falla"
done
si "  y dice qué está mal" eval "grep -q 'fondo no es #rrggbb' '$tmp/error-roto' && grep -q 'no hay ningún tema «noexiste»' '$tmp/error-huerfano' && grep -q 'no es clave=valor' '$tmp/error-raro' && grep -q 'falta btop' '$tmp/error-sinbtop'"
si "  sin tocar ningún fichero" test "$(huella)" = "$antes"
PRUEBA_SIN_LETRAS=1 "$apps_sh" catppuccin >/dev/null 2>"$tmp/error"
si "si la letra del tema no está instalada, Ghostty va con la de default" grep -qx 'font-family = Noto Sans Mono' "$estado/ghostty.conf"
si "  y lo dice" grep -q "«JetBrainsMono Nerd Font» no está instalada" "$tmp/error"

# ---------------------------------------------------------------------------
seccion "tema.sh lo llama"

"$apps_sh" default >/dev/null 2>&1
salida=$("$tema_sh" catppuccin)
si "tema.sh catppuccin, sin sesión, sale bien" test $? = 0
si "  escribe el tema" test "$(cat "$estado/tema")" = catppuccin
si "  y las aplicaciones" cmp -s "$estado/ghostty.conf" "$tmp/gen/catppuccin/ghostty.conf"
si "  y lo dice" grep -q "aplicaciones (catppuccin)" <<<"$salida"
"$tema_sh" phosphor >/dev/null
"$tema_sh" alternar >/dev/null
si "alternar desde phosphor, el último, vuelve a default (y sus aplicaciones)" eval "test \"\$(cat '$estado/tema')\" = default && cmp -s '$estado/nvim.lua' '$tmp/gen/default/nvim.lua'"
"$tema_sh" alternar >/dev/null
si "y de default pasa a liquido" test "$("$tema_sh")" = liquido
"$tema_sh" foo >/dev/null 2>&1
si "un tema que tema.sh no tiene no llega a las aplicaciones" cmp -s "$estado/nvim.lua" "$tmp/gen/default/nvim.lua"

# ---------------------------------------------------------------------------
seccion "El aviso a lo abierto (SIGUSR2), con procesos de mentira"

# Un «ghostty» y un «btop» que apuntan cada SIGUSR2 que reciben, y otro btop
# que no la atrapa (a ése, SIGUSR2 lo mataría). #!/bin/bash, y no env: así el
# nombre del proceso es el del fichero.
falso() { # $1: nombre; $2: fichero donde apuntar (vacío: no la atrapa)
	cat >"$tmp/falsos/$1" <<FIN
#!/bin/bash
[[ -n "$2" ]] && trap 'echo usr2 >>"$2"' USR2
while :; do sleep 0.05; done
FIN
	chmod +x "$tmp/falsos/$1"
}
mkdir -p "$tmp/falsos/otro" "$tmp/otro-home"
falso ghostty "$tmp/senales-ghostty"
falso btop "$tmp/senales-btop"
cat >"$tmp/falsos/otro/ghostty" <<FIN
#!/bin/bash
trap 'echo usr2 >>"$tmp/senales-otro"' USR2
while :; do sleep 0.05; done
FIN
mkdir -p "$tmp/falsos/sordo"
cat >"$tmp/falsos/sordo/btop" <<'FIN'
#!/bin/bash
while :; do sleep 0.05; done
FIN
chmod +x "$tmp/falsos/otro/ghostty" "$tmp/falsos/sordo/btop"
: >"$tmp/senales-ghostty"
: >"$tmp/senales-btop"
: >"$tmp/senales-otro"
"$tmp/falsos/ghostty" &
pids+=($!)
"$tmp/falsos/btop" &
pids+=($!)
HOME=$tmp/otro-home "$tmp/falsos/otro/ghostty" &
pids+=($!)
"$tmp/falsos/sordo/btop" &
sordo=$!
pids+=($sordo)
atrapa() { (((16#$(sed -n 's/^SigCgt:[[:space:]]*//p' "/proc/$1/status") >> 11) & 1)); }
esperar() { # hasta 3 s a que se cumpla $1 (se evalúa cada vez)
	local i
	for i in $(seq 30); do
		eval "$1" && return 0
		sleep 0.1
	done
	return 1
}
esperar "atrapa ${pids[0]} && atrapa ${pids[1]} && atrapa ${pids[2]}"
si "los procesos de mentira se llaman ghostty y btop" test "$(cat "/proc/${pids[0]}/comm") $(cat "/proc/${pids[1]}/comm")" = "ghostty btop"
cuenta() { wc -l <"$1"; }

"$apps_sh" default >/dev/null 2>&1
TEMA_APPS_RECARGAR=1 "$apps_sh" catppuccin >/dev/null 2>&1
si "al cambiar de tema, Ghostty recibe un SIGUSR2" esperar 'test "$(cuenta "$tmp/senales-ghostty")" = 1'
si "  y btop, otro" esperar 'test "$(cuenta "$tmp/senales-btop")" = 1'
sleep 0.3
si "  el Ghostty de otro HOME, ninguno" test "$(cuenta "$tmp/senales-otro")" = 0
si "  y el btop que no la atrapa sigue vivo (no se le manda)" kill -0 "$sordo"
TEMA_APPS_RECARGAR=1 "$apps_sh" catppuccin >/dev/null 2>&1
sleep 0.3
si "el mismo tema otra vez: no avisa (no cambió nada)" test "$(cuenta "$tmp/senales-ghostty")" = 1
"$apps_sh" tokyonight >/dev/null 2>&1
sleep 0.3
si "con TEMA_APPS_RECARGAR=0, tampoco" test "$(cuenta "$tmp/senales-ghostty")" = 1
TEMA_APPS_RECARGAR=1 XDG_STATE_HOME=$tmp/otro-estado "$apps_sh" gruvbox >/dev/null 2>&1
sleep 0.3
si "con otro XDG_STATE_HOME (no el que leen Ghostty y btop), tampoco" test "$(cuenta "$tmp/senales-ghostty")" = 1
si "  aunque escribe allí" test -s "$tmp/otro-estado/escritorio/ghostty.conf"
"$apps_sh" default >/dev/null 2>&1
TEMA_APPS_RECARGAR=1 "$apps_sh" liquido >/dev/null 2>&1
sleep 0.3
si "de default a liquido (lo mismo), tampoco" test "$(cuenta "$tmp/senales-ghostty")" = 1
kill "${pids[@]}" 2>/dev/null
wait 2>/dev/null
pids=()

# ---------------------------------------------------------------------------
seccion "Neovim: lua/config/tema.lua, sin plugins"

if command -v nvim >/dev/null; then
	mkdir -p "$tmp/lazy/gruvbox.nvim/colors"
	cat >"$tmp/tema-nvim.lua" <<'FIN'
-- Sin LazyVim: el módulo solo, con lazy.nvim de mentira (sólo su carpeta).
vim.opt.rtp:prepend(vim.env.PRUEBA_NVIM_REPO)
package.loaded["lazy.core.config"] = { options = { root = vim.env.PRUEBA_LAZY } }
local salida = io.open(vim.env.PRUEBA_SALIDA, "a")
local function di(s)
  salida:write(s .. "\n")
  salida:flush()
end
local tema = require("config.tema")
tema.reserva = "habamax" -- horizon no está sin plugins
di("leer " .. tostring(tema.leer()))
di("cond gruvbox " .. tostring(tema.hace_falta("ellisonleao/gruvbox.nvim")()))
di("cond kanagawa " .. tostring(tema.hace_falta("rebelot/kanagawa.nvim")()))
if vim.env.PRUEBA_SOLO_COND then
  salida:close()
  vim.cmd("qa!")
end
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.schedule(function()
      local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      di("colorscheme " .. tostring(vim.g.colors_name) .. " " .. (hl.fg and string.format("#%06x", hl.fg) or "-"))
    end)
  end,
})
tema.arrancar()
di("vigila " .. tostring(tema.vigilante ~= nil))
local reloj = (vim.uv or vim.loop).new_timer()
reloj:start(100, 100, vim.schedule_wrap(function()
  if (vim.uv or vim.loop).fs_stat(vim.env.PRUEBA_FIN) then
    salida:close()
    vim.cmd("qa!")
  end
end))
FIN
	# El nvim.lua lo escribe tema-apps.sh en el estado de prueba.
	nv() { # lanza el Neovim de la prueba en segundo plano
		: >"$tmp/nvim.salida"
		rm -f "$tmp/nvim.fin"
		PRUEBA_NVIM_REPO=$repo/.config/nvim PRUEBA_LAZY=$tmp/lazy PRUEBA_SALIDA=$tmp/nvim.salida PRUEBA_FIN=$tmp/nvim.fin \
			timeout 60 nvim --headless --clean -c "luafile $tmp/tema-nvim.lua" >"$tmp/nvim.log" 2>&1 &
		nvim_pid=$!
	}
	ultimo() { grep '^colorscheme ' "$tmp/nvim.salida" | tail -n1; }

	"$apps_sh" phosphor >/dev/null 2>&1
	nv
	si "arranca con el del tema (phosphor), verde" esperar 'test "$(ultimo)" = "colorscheme phosphor #00ff00"'
	si "  y lee el fichero" grep -qx 'leer phosphor' "$tmp/nvim.salida"
	si "  y vigila la carpeta" grep -qx 'vigila true' "$tmp/nvim.salida"
	si "cond: gruvbox, instalado, sí; kanagawa, ni instalado ni activo, no (no se descarga)" eval "grep -qx 'cond gruvbox true' '$tmp/nvim.salida' && grep -qx 'cond kanagawa false' '$tmp/nvim.salida'"
	"$apps_sh" default >/dev/null 2>&1
	si "en caliente: default (horizon, que aquí no está) cae en el de reserva" esperar 'test "$(ultimo | cut -d" " -f2)" = habamax'
	"$apps_sh" phosphor >/dev/null 2>&1
	si "en caliente: phosphor otra vez" esperar 'test "$(ultimo)" = "colorscheme phosphor #00ff00"'
	n=$(grep -c '^colorscheme ' "$tmp/nvim.salida")
	"$apps_sh" phosphor >/dev/null 2>&1
	sleep 0.5
	si "el mismo tema otra vez: no lo vuelve a poner" test "$(grep -c '^colorscheme ' "$tmp/nvim.salida")" = "$n"
	printf 'return { colorscheme = 1 }\n' >"$estado/.nvim.basura"
	mv -f "$estado/.nvim.basura" "$estado/nvim.lua"
	si "con basura en nvim.lua, el de reserva" esperar 'test "$(ultimo | cut -d" " -f2)" = habamax'
	printf 'os.execute("touch %s/hackeado"); return { colorscheme = "phosphor" }\n' "$tmp" >"$estado/.nvim.basura"
	mv -f "$estado/.nvim.basura" "$estado/nvim.lua"
	sleep 0.5
	si "nvim.lua no puede ejecutar nada (sólo una tabla)" test ! -e "$tmp/hackeado"
	touch "$tmp/nvim.fin"
	wait "$nvim_pid" 2>/dev/null
	si "Neovim sale sin errores" test -z "$(grep -iE 'E[0-9]+:|error' "$tmp/nvim.log")"

	# Sólo el cond: sin arrancar, que con kanagawa activo y sin instalar se
	# pondría a clonarlo.
	"$apps_sh" kanagawa >/dev/null 2>&1
	PRUEBA_SOLO_COND=1 nv
	wait "$nvim_pid" 2>/dev/null
	si "cond: con kanagawa activo, kanagawa sí (lazy.nvim lo instalaría al arrancar)" grep -qx 'cond kanagawa true' "$tmp/nvim.salida"
else
	echo "OMITIDA  no hay nvim en esta máquina"
fi

echo
echo "Resultado: $total comprobaciones, $fallos fallos"
if [[ ${1:-} == --guardar ]]; then
	echo "Lo escrito, en $tmp"
else
	rm -rf "$tmp"
fi
((fallos == 0))
