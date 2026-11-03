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
#   3. El fondo de pantalla, sólo si la máquina no tiene ya hyprpaper.conf.
#   4. Los servicios de usuario del repo.
#   5. Memoria: earlyoom (mata antes el navegador que Hyprland si se agota la
#      RAM) y, si la máquina usa zram, los sysctl que recomienda la Arch Wiki.
#      Escribe en /etc, así que usa sudo.
#   6. Zen Browser: si hay perfil, enlaza .config/zen/user.js en el perfil por
#      defecto (ajustes de memoria). No toca prefs.js ni nada más del perfil.
#   7. fish como shell.
#   8. Lo del equipo: si la rama trae equipo.sh (sólo las ramas de cada
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
	# Letras: Noto Sans Mono para la terminal, JetBrainsMono para la barra
	noto-fonts ttf-jetbrains-mono-nerd
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
)

# Se enlazan aparte, no con el resto de .config: .config/zen es el perfil vivo
# de Zen y user.js se enlaza dentro del perfil por defecto (paso 6).
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
paso "3. Fondo de pantalla"

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
paso "4. Servicios de usuario"

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
paso "5. Memoria"

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
paso "6. Zen Browser"

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
paso "7. fish como shell"

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
	paso "8. Lo de este equipo (equipo.sh)"
	"$repo/equipo.sh" $($comprobar && echo --comprobar)
else
	paso "8. Sin equipo.sh en esta rama: sólo lo común"
fi

echo
$comprobar && echo "Comprobado; no se ha tocado nada." || echo "Hecho. Si es la primera vez, cierra sesión y vuelve a entrar."
