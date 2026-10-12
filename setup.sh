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
#   5. fish como shell.
#   6. Lo del equipo: si la rama trae equipo.sh (sólo las ramas de cada
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
	en_carpeta "$r" || enlazar "$r"
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
paso "5. fish como shell"

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
	paso "6. Lo de este equipo (equipo.sh)"
	"$repo/equipo.sh" $($comprobar && echo --comprobar)
else
	paso "6. Sin equipo.sh en esta rama: sólo lo común"
fi

echo
$comprobar && echo "Comprobado; no se ha tocado nada." || echo "Hecho. Si es la primera vez, cierra sesión y vuelve a entrar."
