#!/usr/bin/env bash
# Deja una máquina (Arch o CachyOS) con el escritorio de este repo.
#
#   ~/Projects/set-up/setup.sh                   pregunta: ¿torre o portátil?
#   ~/Projects/set-up/setup.sh --torre           (o --portatil) sin preguntar
#   ~/Projects/set-up/setup.sh --comprobar       sólo dice qué haría, sin tocar nada
#
# Sin sudo: lo pide él cuando instala paquetes. Se puede repetir las veces que
# haga falta; lo que ya está bien lo deja como está. En orden:
#
#   0. Qué máquina es. Lo común vive en main y lo de cada equipo en su rama
#      (setup/torre, setup/portatil), que es main más lo suyo. Si el repo no
#      está en la rama del equipo elegido, se cambia a ella y el script vuelve
#      a empezar desde allí: así se monta todo junto, lo común y lo del equipo.
#   1. Paquetes: los que falten de la lista común, con pacman, y los del AUR
#      con yay o paru.
#   2. Enlaces: ~/.config y ~/.local/bin apuntan al repo, así que un git pull se
#      nota al momento. Las carpetas de CARPETAS se enlazan enteras; del resto,
#      cada fichero. Lo que hubiera en su sitio y no sea ese enlace se aparta a
#      ~/.local/share/set-up-apartado/<fecha>/, no se borra.
#   3. El tema del escritorio: la carpeta donde tema.sh guarda el tema activo
#      (${XDG_STATE_HOME:-~/.local/state}/escritorio). El tema no se toca: sin
#      fichero, es default. Lo de las aplicaciones (Ghostty, Neovim, fuzzel,
#      foot, btop) se escribe para el tema activo con tema-apps.sh, y btop se
#      apunta a él: themes/escritorio.theme y color_theme = "escritorio" en
#      btop.conf (lo que hubiera se aparta antes, como en los enlaces).
#   4. El fondo de pantalla, sólo si la máquina no tiene ya hyprpaper.conf.
#   5. Los servicios de usuario del repo.
#   6. Memoria: earlyoom (mata antes el navegador que Hyprland si se agota la
#      RAM) y, si la máquina usa zram, los sysctl que recomienda la Arch Wiki.
#      Escribe en /etc, así que usa sudo.
#   7. Zen Browser: si hay perfil, enlaza .config/zen/user.js en el perfil por
#      defecto (ajustes de memoria). No toca prefs.js ni nada más del perfil.
#   8. fish como shell.
#   9. Lo del equipo: si la rama trae equipo.sh (sólo las ramas de cada
#      máquina), se ejecuta al final con los mismos argumentos, igual que
#      hyprland.lua carga equipo.lua.
#
# El tema de la pantalla de login va aparte, porque toca /usr: sudo sddm/install.sh

set -uo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
comprobar=false
perfil=""
for a in "$@"; do
	case $a in
	--comprobar) comprobar=true ;;
	--torre) perfil=torre ;;
	--portatil | --portátil) perfil=portatil ;;
	*)
		echo "No conozco la opción $a (valen --torre, --portatil y --comprobar)" >&2
		exit 1
		;;
	esac
done
apartado="$HOME/.local/share/set-up-apartado/$(date +%Y-%m-%d_%H%M%S)"

aviso() { printf '\033[33m%s\033[0m\n' "$*"; }
fallo() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
paso() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
# Ejecuta, o en --comprobar sólo lo enseña.
hacer() {
	if $comprobar; then
		echo "  haría: $*"
	else
		"$@"
	fi
}

# ---------------------------------------------------------------------------
# Lo común. Lo de una sola máquina va en el equipo.sh de su rama.

# Del repo oficial (extra y core), en Arch y en CachyOS con el mismo nombre.
PACMAN=(
	# El escritorio
	hyprland uwsm xdg-desktop-portal-hyprland quickshell hyprpaper hyprlock
	hyprpicker hyprshutdown wireplumber
	# Lo que usan la barra y los scripts
	grim slurp satty wl-clipboard jq libnotify pacman-contrib pavucontrol
	playerctl btop
	# Mata el proceso más gordo (antes el navegador) si se agota la memoria
	earlyoom
	# El panel del homelab (quickshell/homelab): la contraseña de cada equipo
	# va en el llavero y se lee con secret-tool
	gnome-keyring libsecret
	# Terminal, shell y editor
	ghostty fish starship zoxide eza direnv fastfetch neovim tree-sitter-cli
	nodejs npm ripgrep fd lazygit git curl
	# Letras: Noto Sans Mono para la terminal, JetBrainsMono para la barra, y
	# las de la terminal en los temas (.config/escritorio/temas): Fira Code en
	# tokyonight, Hack en gruvbox y Terminus (Terminess Nerd Font) en phosphor
	noto-fonts ttf-jetbrains-mono-nerd ttf-fira-code ttf-hack ttf-terminus-nerd
	# El gestor de archivos de SUPER+E
	dolphin
)

# Del AUR.
AUR=(
	# El navegador de los atajos (SUPER+B)
	zen-browser-bin
)

# Las carpetas que se enlazan enteras: lo que se añada dentro aparece solo.
# Del resto de .config y .local/bin se enlaza cada fichero, para no pisar lo
# que cada programa escribe junto a su configuración (fish_variables,
# lazy-lock.json, hyprpaper.conf…).
CARPETAS=(
	.config/hypr/scripts
	.config/quickshell
	.config/nvim
	.config/escritorio
)

# Se enlazan aparte, no con el resto de .config: .config/zen es el perfil vivo
# de Zen y user.js se enlaza dentro del perfil por defecto (paso 7).
SIN_ENLAZAR=(
	.config/zen
)

# El fondo de las dos máquinas.
FONDO_URL="https://w.wallhaven.cc/full/rd/wallhaven-rd3pjw.jpg"
FONDO="$HOME/Pictures/wallpapers/wallhaven-rd3pjw.jpg"

# ---------------------------------------------------------------------------
paso "0. Qué máquina es"

rama=$(git -C "$repo" branch --show-current)
# La rama ya dice qué equipo es: setup/torre* o setup/portatil*.
if [[ -z $perfil ]]; then
	case $rama in
	setup/torre*) perfil=torre ;;
	setup/portatil*) perfil=portatil ;;
	esac
fi
while [[ -z $perfil ]]; do
	read -r -p "¿Es una torre o un portátil? [t/p] " r
	case $r in
	[tT]*) perfil=torre ;;
	[pP]*) perfil=portatil ;;
	esac
done
echo "  $perfil"

objetivo=setup/$perfil
if [[ $rama != "$objetivo"* ]]; then
	if $comprobar; then
		echo "  haría: git switch $objetivo y volvería a empezar desde esa rama"
		echo "  (lo de abajo es lo de la rama actual, $rama)"
	else
		[[ -z $(git -C "$repo" status --porcelain) ]] ||
			fallo "El repo tiene cambios sin commit; no cambio de rama. Guárdalos y repite."
		git -C "$repo" fetch -q origin
		git -C "$repo" switch -q "$objetivo" 2>/dev/null ||
			git -C "$repo" switch -q -c "$objetivo" --track "origin/$objetivo" ||
			fallo "No puedo cambiar a la rama $objetivo."
		echo "  repo en $objetivo; vuelvo a empezar desde ella"
		exec "$repo/setup.sh" "$@" "--$perfil"
	fi
fi

# ---------------------------------------------------------------------------
paso "1. Paquetes"

command -v pacman >/dev/null || fallo "No hay pacman: esto es para Arch o CachyOS."

# pacman -T devuelve los que no están instalados, sin tocar nada.
mapfile -t faltan < <(pacman -T "${PACMAN[@]}")
if ((${#faltan[@]})); then
	echo "  faltan: ${faltan[*]}"
	hacer sudo pacman -S --needed "${faltan[@]}"
else
	echo "  todo instalado"
fi

aur=""
for h in yay paru; do
	command -v "$h" >/dev/null && aur=$h && break
done
mapfile -t faltanAur < <(pacman -T "${AUR[@]}")
if ((${#faltanAur[@]})); then
	if [[ -n $aur ]]; then
		echo "  faltan del AUR: ${faltanAur[*]}"
		hacer "$aur" -S --needed "${faltanAur[@]}"
	else
		aviso "  faltan del AUR (${faltanAur[*]}) y no hay yay ni paru para instalarlos"
	fi
else
	echo "  todo lo del AUR instalado"
fi

# ---------------------------------------------------------------------------
paso "2. Enlaces"

# Enlaza ~/<r> al mismo camino dentro del repo. Si ya hay algo que no es ese
# enlace, se aparta antes.
enlazar() {
	local r=$1 destino="$HOME/$1"
	if [[ -L $destino && $(readlink "$destino") == "$repo/$r" ]]; then
		return
	fi
	if [[ -e $destino || -L $destino ]]; then
		if $comprobar; then
			echo "  apartaría ~/$r"
		else
			mkdir -p "$apartado/$(dirname "$r")"
			mv "$destino" "$apartado/$r"
			echo "  apartado  ~/$r"
		fi
	fi
	if $comprobar; then
		echo "  enlazaría ~/$r"
	else
		mkdir -p "$(dirname "$destino")"
		ln -s "$repo/$r" "$destino"
		echo "  enlazado  ~/$r"
	fi
}

# Si un camino del repo está dentro de SIN_ENLAZAR.
aparte() {
	local c
	for c in "${SIN_ENLAZAR[@]}"; do
		[[ $1 == "$c"/* ]] && return 0
	done
	return 1
}

# Si un camino del repo está dentro de una de CARPETAS.
en_carpeta() {
	local c
	for c in "${CARPETAS[@]}"; do
		[[ $1 == "$c"/* ]] && return 0
	done
	return 1
}

antes=$(find "$HOME/.local/share/set-up-apartado" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
for c in "${CARPETAS[@]}"; do
	[[ -d $repo/$c ]] && enlazar "$c"
done
while IFS= read -r f; do
	r=${f#"$repo"/}
	en_carpeta "$r" || aparte "$r" || enlazar "$r"
done < <(find "$repo/.config" "$repo/.local/bin" \( -type f -o -type l \) 2>/dev/null | sort)
echo "  todos los enlaces en su sitio"
if ! $comprobar && (($(find "$HOME/.local/share/set-up-apartado" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l) > antes)); then
	aviso "  lo apartado está en $apartado"
fi

# ---------------------------------------------------------------------------
paso "3. Tema del escritorio"

# tema.sh (SUPER+SHIFT+T) guarda aquí el tema activo, y la paleta de
# Quickshell (shared/Theme.qml) vigila el fichero para cambiar en caliente. La
# carpeta tiene que existir antes de que arranque Quickshell: su vigilante no
# ve aparecer un fichero en una carpeta que no existía. El tema en sí no se
# toca; sin fichero, es default.
estado_tema="${XDG_STATE_HOME:-$HOME/.local/state}/escritorio"
if [[ -d $estado_tema ]]; then
	echo "  $estado_tema ya está (tema: $("$repo/.config/hypr/scripts/tema.sh"))"
else
	hacer mkdir -p "$estado_tema"
fi

# Lo de las aplicaciones, para el tema activo: lo que cargan config.ghostty,
# Neovim, fuzzel.ini y foot.ini (estos dos dan error si falta su include). Si
# ya está igual, tema-apps.sh no toca nada.
if $comprobar; then
	echo "  haría: tema-apps.sh (Ghostty, Neovim, fuzzel, foot y btop con el tema activo)"
elif "$repo/.config/hypr/scripts/tema-apps.sh"; then
	echo "  aplicaciones con el tema activo"
else
	aviso "  tema-apps.sh ha fallado: las aplicaciones no tienen el tema"
fi

# btop no tiene include: su tema es un fichero de themes/ y su nombre va en
# color_theme. themes/escritorio.theme apunta al que escribe tema-apps.sh.
btop_dir="${XDG_CONFIG_HOME:-$HOME/.config}/btop"
btop_tema="$btop_dir/themes/escritorio.theme"
if [[ -L $btop_tema && $(readlink "$btop_tema") == "$estado_tema/btop.theme" ]]; then
	echo "  btop: themes/escritorio.theme ya enlazado"
else
	if [[ -e $btop_tema || -L $btop_tema ]]; then
		if $comprobar; then
			echo "  apartaría $btop_tema"
		else
			mkdir -p "$apartado/btop/themes"
			mv "$btop_tema" "$apartado/btop/themes/"
			aviso "  $btop_tema apartado en $apartado/btop/themes"
		fi
	fi
	if $comprobar; then
		echo "  enlazaría $btop_tema"
	else
		mkdir -p "$btop_dir/themes" && ln -s "$estado_tema/btop.theme" "$btop_tema" &&
			echo "  enlazado  $btop_tema"
	fi
fi
# btop escribe su btop.conf al salir: si está abierto, pisaría el cambio.
btop_conf="$btop_dir/btop.conf"
if [[ -f $btop_conf ]] && grep -qx 'color_theme = "escritorio"' "$btop_conf"; then
	echo "  btop.conf ya usa el tema del escritorio"
elif $comprobar; then
	echo "  pondría color_theme = \"escritorio\" en $btop_conf"
elif pgrep -u "$(id -u)" -x btop >/dev/null; then
	aviso "  btop está abierto: ciérralo y repite para ponerle el tema del escritorio"
elif [[ -f $btop_conf ]]; then
	mkdir -p "$apartado/btop" && cp -p "$btop_conf" "$apartado/btop/btop.conf"
	if grep -q '^color_theme *=' "$btop_conf"; then
		sed -i 's/^color_theme *=.*/color_theme = "escritorio"/' "$btop_conf"
	else
		printf 'color_theme = "escritorio"\n' >>"$btop_conf"
	fi
	aviso "  btop.conf con color_theme = \"escritorio\" (el de antes, copiado en $apartado/btop)"
else
	mkdir -p "$btop_dir" &&
		printf '# Lo empezó set-up/setup.sh; btop pone lo demás al salir.\ncolor_theme = "escritorio"\n' >"$btop_conf" &&
		echo "  escrito $btop_conf (sólo color_theme)"
fi

# ---------------------------------------------------------------------------
paso "4. Fondo de pantalla"

# hyprpaper.conf es de cada máquina y no va en el repo: si ya existe, se
# respeta. sddm/install.sh lee de aquí el "path" para el fondo del login.
if [[ -f $HOME/.config/hypr/hyprpaper.conf ]]; then
	echo "  ya hay hyprpaper.conf; no se toca"
else
	if [[ ! -f $FONDO ]]; then
		hacer mkdir -p "$(dirname "$FONDO")"
		hacer curl -fsSL -o "$FONDO" "$FONDO_URL"
	fi
	if $comprobar; then
		echo "  escribiría ~/.config/hypr/hyprpaper.conf con $FONDO"
	else
		cat >"$HOME/.config/hypr/hyprpaper.conf" <<EOF
# El fondo de esta máquina. Lo escribió setup.sh; no va en el repo.
# sddm/install.sh lee el "path" de aquí para el fondo de la pantalla de login.

splash = false

wallpaper {
    monitor =
    path = $FONDO
    fit_mode = cover
}
EOF
		echo "  escrito ~/.config/hypr/hyprpaper.conf"
	fi
fi

# ---------------------------------------------------------------------------
paso "5. Servicios de usuario"

hacer systemctl --user daemon-reload
for t in "$repo"/.config/systemd/user/*.timer; do
	[[ -e $t ]] || continue
	u=$(basename "$t")
	if systemctl --user is-enabled "$u" >/dev/null 2>&1; then
		echo "  $u ya activo"
	else
		hacer systemctl --user enable --now "$u"
	fi
done

# ---------------------------------------------------------------------------
paso "6. Memoria"

# Escribe un fichero de /etc con sudo si no tiene ya ese contenido.
poner_etc() {
	local destino=$1 contenido=$2
	if [[ -f $destino && $(<"$destino") == "${contenido%$'\n'}" ]]; then
		echo "  $destino ya está"
	elif $comprobar; then
		echo "  escribiría $destino"
	else
		printf '%s\n' "$contenido" | sudo tee "$destino" >/dev/null &&
			echo "  escrito $destino"
	fi
}

# earlyoom, con la configuración por defecto salvo a quién mata primero. Casan
# con el nombre del proceso (comm, 15 letras como mucho), en regex extendida.
# Sin comillas ni espacios: systemd parte EARLYOOM_ARGS por los espacios y no
# interpreta las comillas de dentro. "Web.Content" es "Web Content" y
# "Isolated.Web" es "Isolated Web Co", los procesos de pestaña de Zen.
EARLYOOM_CONF='# Lo escribe set-up/setup.sh.
# Antes el navegador y las apps Electron que el escritorio.
EARLYOOM_ARGS="-r 3600 --avoid ^(Hyprland|Xwayland|systemd|sddm|uwsm)$ --prefer ^(zen|zen-bin|Isolated.Web|Web.Content|WebExtensions|chromium|electron|Discord|discord|obsidian)$"'
if pacman -Q earlyoom >/dev/null 2>&1 || ! $comprobar; then
	poner_etc /etc/default/earlyoom "$EARLYOOM_CONF"
else
	echo "  escribiría /etc/default/earlyoom (cuando esté instalado earlyoom)"
fi
if systemctl is-enabled earlyoom >/dev/null 2>&1 &&
	systemctl is-active earlyoom >/dev/null 2>&1; then
	echo "  earlyoom ya activo"
else
	hacer sudo systemctl enable --now earlyoom
fi

# Con zram, la Arch Wiki recomienda otros valores: cambiar a swap comprimida en
# RAM sale casi gratis, así que se favorece frente a soltar la caché.
if [[ -d /sys/block/zram0 ]]; then
	ZRAM_CONF='# Lo escribe set-up/setup.sh. Valores de la Arch Wiki para zram.
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125'
	if [[ -f /etc/sysctl.d/99-zram.conf && $(</etc/sysctl.d/99-zram.conf) == "$ZRAM_CONF" ]]; then
		echo "  /etc/sysctl.d/99-zram.conf ya está"
		# Si el fichero está pero el kernel aún no lo aplicó (p. ej. otro
		# valor puesto a mano después), se vuelve a aplicar.
		if [[ $(sysctl -n vm.swappiness 2>/dev/null) != 180 ]]; then
			hacer sudo sysctl --system
		fi
	else
		poner_etc /etc/sysctl.d/99-zram.conf "$ZRAM_CONF"
		hacer sudo sysctl --system
	fi
else
	echo "  sin zram: no se tocan los sysctl"
fi

# ---------------------------------------------------------------------------
paso "7. Zen Browser"

# El perfil por defecto sale de profiles.ini: el Default= de la sección
# [Install*] (el que usa el Zen instalado) o, si no, el [Profile*] con
# Default=1. La ruta es relativa a ~/.config/zen salvo IsRelative=0.
zen_ini="$HOME/.config/zen/profiles.ini"
zen_perfil() {
	awk '
		/^\[/ { sec = $0; ruta = ""; next }
		{ k = $0; sub(/=.*/, "", k); v = $0; sub(/^[^=]*=/, "", v) }
		sec ~ /^\[Install/ && k == "Default" { inst = v }
		sec ~ /^\[Profile/ && k == "Path" { ruta = v; if (pd[sec]) alt = ruta }
		sec ~ /^\[Profile/ && k == "Default" && v == 1 { pd[sec] = 1; if (ruta != "") alt = ruta }
		END { print (inst != "" ? inst : alt) }' "$zen_ini"
}
if [[ ! -f $zen_ini ]]; then
	echo "  Zen sin perfil todavía (no hay $zen_ini); abre Zen una vez y repite"
else
	ruta=$(zen_perfil)
	if [[ -z $ruta ]]; then
		aviso "  no encuentro el perfil por defecto en profiles.ini"
	else
		[[ $ruta == /* ]] || ruta="$HOME/.config/zen/$ruta"
		origen="$repo/.config/zen/user.js"
		destino="$ruta/user.js"
		if [[ ! -d $ruta ]]; then
			aviso "  el perfil $ruta no existe; abre Zen una vez y repite"
		elif [[ -L $destino && $(readlink "$destino") == "$origen" ]]; then
			echo "  user.js ya enlazado en el perfil"
		else
			if [[ -e $destino || -L $destino ]]; then
				if $comprobar; then
					echo "  apartaría el user.js del perfil"
				else
					mkdir -p "$apartado/zen"
					mv "$destino" "$apartado/zen/user.js"
					aviso "  user.js apartado en $apartado/zen"
				fi
			fi
			if $comprobar; then
				echo "  enlazaría $destino"
			else
				ln -s "$origen" "$destino" && echo "  enlazado  $destino (vale al reiniciar Zen)"
			fi
		fi
	fi
fi

# ---------------------------------------------------------------------------
paso "8. fish como shell"

shell=$(getent passwd "$USER" | cut -d: -f7)
if [[ $shell == */fish ]]; then
	echo "  ya es fish"
elif command -v fish >/dev/null; then
	hacer chsh -s "$(command -v fish)"
else
	aviso "  fish no está instalado; repite cuando lo esté"
fi

# ---------------------------------------------------------------------------
if [[ -x $repo/equipo.sh ]]; then
	paso "9. Lo de este equipo (equipo.sh)"
	"$repo/equipo.sh" $($comprobar && echo --comprobar)
else
	paso "9. Sin equipo.sh en esta rama: sólo lo común"
fi

echo
$comprobar && echo "Comprobado; no se ha tocado nada." || echo "Hecho. Si es la primera vez, cierra sesión y vuelve a entrar."
