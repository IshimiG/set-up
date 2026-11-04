#!/usr/bin/env bash
# Prueba sin pantalla del tema en Neovim, con la configuración del repo entera
# (LazyVim) en un HOME y unos XDG de prueba:
#   - arranca con el colorscheme de cada tema, con el fondo transparente;
#   - sin descargar gruvbox ni kanagawa si no son el tema activo;
#   - en caliente: tema-apps.sh cambia el tema y el Neovim abierto lo cambia,
#     sin perder la transparencia;
#   - con red: un tema cuyo plugin no está se instala en caliente (gruvbox) y
#     al arrancar (kanagawa).
# Los plugins se copian de los de verdad (${PRUEBA_NVIM_LAZY:-~/.local/share/nvim/lazy}),
# así que no se descarga casi nada y no se toca el Neovim de verdad: ni su
# carpeta de plugins ni su lazy-lock.json. No se hace ningún Lazy sync.
#
#   pruebas/temas/nvim.sh            la prueba, y la carpeta se borra
#   pruebas/temas/nvim.sh --guardar  la deja
#
# Hace falta nvim y git. Sale con 1 si algo falla.
set -uo pipefail

aqui=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$aqui/../..")
apps_sh=$repo/.config/hypr/scripts/tema-apps.sh
lazy_real=${PRUEBA_NVIM_LAZY:-$HOME/.local/share/nvim/lazy}

for orden in nvim git; do
	if ! command -v "$orden" >/dev/null; then
		echo "FALLO  falta $orden" >&2
		exit 1
	fi
done
if [[ ! -d $lazy_real/lazy.nvim || ! -d $lazy_real/LazyVim ]]; then
	echo "OMITIDA  no hay plugins que copiar en $lazy_real (abre Neovim una vez, o PRUEBA_NVIM_LAZY)"
	exit 0
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/prueba-temas-nvim.XXXXXX")
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_STATE_HOME
export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_DATA_HOME=$tmp/data XDG_CACHE_HOME=$tmp/cache
export TEMA_APPS_RECARGAR=0
mkdir -p "$HOME/.local/state/escritorio" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME/nvim" "$XDG_CACHE_HOME"
cp -r "$repo/.config/nvim" "$XDG_CONFIG_HOME/nvim"
# Sin buscar actualizaciones de los plugins en segundo plano.
sed -i 's/^\(\s*\)enabled = true, -- check for plugin updates.*/\1enabled = false,/' "$XDG_CONFIG_HOME/nvim/lua/config/lazy.lua"
cp -r --reflink=auto "$lazy_real" "$XDG_DATA_HOME/nvim/lazy"
rm -rf "$XDG_DATA_HOME/nvim/lazy/gruvbox.nvim" "$XDG_DATA_HOME/nvim/lazy/kanagawa.nvim"
lazy=$XDG_DATA_HOME/nvim/lazy

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
esperar() { # hasta $2 décimas (30 si no) a que se cumpla $1, que se evalúa cada vez
	local i
	for i in $(seq "${2:-30}"); do
		eval "$1" && return 0
		sleep 0.1
	done
	return 1
}

# Lo que mira la prueba desde dentro: cada ColorScheme (cuando ya han pasado
# los demás, como el de la transparencia) y, al estar listo, cómo ha quedado.
# UIEnter hace de pantalla: sin él, LazyVim no llega a VeryLazy, que es cuando
# carga config/autocmds.lua (la transparencia).
cat >"$tmp/mirar.lua" <<'FIN'
local salida = io.open(vim.env.PRUEBA_SALIDA, "a")
local function estado()
  local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  return tostring(vim.g.colors_name) .. " " .. (hl.bg and "fondo" or "transparente")
end
local function di(s)
  salida:write(s .. "\n")
  salida:flush()
end
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.schedule(function() di("colorscheme " .. estado()) end)
  end,
})
vim.api.nvim_exec_autocmds("UIEnter", {})
vim.defer_fn(function() di("listo " .. estado()) end, 1500)
local reloj = (vim.uv or vim.loop).new_timer()
reloj:start(100, 100, vim.schedule_wrap(function()
  if (vim.uv or vim.loop).fs_stat(vim.env.PRUEBA_FIN) then
    salida:close()
    vim.cmd("qa!")
  end
end))
FIN

nv() { # arranca Neovim en segundo plano
	: >"$tmp/salida"
	rm -f "$tmp/fin"
	PRUEBA_SALIDA=$tmp/salida PRUEBA_FIN=$tmp/fin timeout 180 nvim --headless -c "luafile $tmp/mirar.lua" >>"$tmp/nvim.log" 2>&1 &
	nvim_pid=$!
}
parar() {
	touch "$tmp/fin"
	wait "$nvim_pid" 2>/dev/null
}
ultimo() { grep -E '^(colorscheme|listo) ' "$tmp/salida" | tail -n1 | cut -d' ' -f2-; }

# ---------------------------------------------------------------------------
seccion "Al arrancar"

declare -A esperado=([default]=horizon [liquido]=horizon [catppuccin]=catppuccin-mocha [tokyonight]=tokyonight-night [phosphor]=phosphor)
for t in default liquido catppuccin tokyonight phosphor; do
	"$apps_sh" "$t" >/dev/null 2>&1
	nv
	esperar 'grep -q "^listo" "$tmp/salida"' 600
	si "$t: arranca con ${esperado[$t]}, con el fondo transparente" test "$(grep '^listo' "$tmp/salida" | cut -d' ' -f2-)" = "${esperado[$t]} transparente"
	parar
done
si "gruvbox y kanagawa no se han descargado (no eran el tema activo)" test ! -e "$lazy/gruvbox.nvim" -a ! -e "$lazy/kanagawa.nvim"
rm -f "$HOME/.local/state/escritorio/nvim.lua"
nv
esperar 'grep -q "^listo" "$tmp/salida"' 600
si "sin nvim.lua (antes de tema-apps.sh), horizon, como siempre" test "$(grep '^listo' "$tmp/salida" | cut -d' ' -f2-)" = "horizon transparente"
parar

# ---------------------------------------------------------------------------
seccion "En caliente"

"$apps_sh" default >/dev/null 2>&1
nv
esperar 'grep -q "^listo" "$tmp/salida"' 600
for t in catppuccin tokyonight phosphor default; do
	"$apps_sh" "$t" >/dev/null 2>&1
	si "a $t: el Neovim abierto pasa a ${esperado[$t]}, transparente" esperar 'test "$(ultimo)" = "${esperado[$t]} transparente"' 50
done
si "y ningún tema ha descargado nada" test ! -e "$lazy/gruvbox.nvim" -a ! -e "$lazy/kanagawa.nvim"

hay_red=false
timeout 15 git ls-remote https://github.com/ellisonleao/gruvbox.nvim HEAD >/dev/null 2>&1 &&
	timeout 15 git ls-remote https://github.com/rebelot/kanagawa.nvim HEAD >/dev/null 2>&1 && hay_red=true
if $hay_red; then
	"$apps_sh" gruvbox >/dev/null 2>&1
	si "a gruvbox, sin instalar: lo instala y lo pone, transparente (con red)" esperar 'test "$(ultimo)" = "gruvbox transparente"' 600
	si "  en la carpeta de lazy.nvim, sin dejar temporales" eval "test -d '$lazy/gruvbox.nvim/colors' && test -z \"\$(find '$lazy' -maxdepth 1 -name '*.tema-*')\""
	parar
	"$apps_sh" kanagawa >/dev/null 2>&1
	nv
	esperar 'grep -q "^listo" "$tmp/salida"' 900
	si "kanagawa activo y sin instalar: lazy.nvim lo instala al arrancar y lo pone (kanagawa-wave se llama kanagawa; con red)" test "$(grep '^listo' "$tmp/salida" | cut -d' ' -f2-)" = "kanagawa transparente"
	parar
	"$apps_sh" gruvbox >/dev/null 2>&1
	nv
	esperar 'grep -q "^listo" "$tmp/salida"' 600
	si "gruvbox, ya instalado, al arrancar" test "$(grep '^listo' "$tmp/salida" | cut -d' ' -f2-)" = "gruvbox transparente"
	parar
else
	parar
	echo "OMITIDA  sin red: la instalación de gruvbox y kanagawa"
fi
si "Neovim no ha dado errores de Lua" eval "! grep -qE 'E5108|stack traceback|attempt to' '$tmp/nvim.log'"

echo
echo "Resultado: $total comprobaciones, $fallos fallos"
if [[ ${1:-} == --guardar ]]; then
	echo "Registros en $tmp"
else
	rm -rf "$tmp"
fi
((fallos == 0))
