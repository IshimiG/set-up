#!/usr/bin/env bash
# Cambia el escritorio del portátil de Omarchy al setup de la torre.
#
#   ~/Projects/set-up/portatil/aplicar.sh
#
# Es el paso 2 de portatil/LEEME.md. Sin sudo. Lo que hace, en orden:
#
#   1. Comprueba que estén los programas (si no, pide ejecutar paquetes.sh).
#   2. Hace una copia nueva de Omarchy en ~/Templates/omarchy-respaldo, para
#      que restaurar.sh devuelva exactamente lo que había justo antes.
#   3. Aparta la configuración de escritorio de Omarchy (hypr, waybar, walker,
#      elephant, mako, swayosd) dentro de esa copia. No borra nada.
#   4. Enlaza la de la torre desde este repo, como en la torre: ~/.config apunta
#      aquí, así que un git pull o un cambio en el repo se nota al momento.
#   5. Lo pone en marcha sin cerrar sesión (hyprctl reload full-reset pasa
#      Hyprland de hyprland.conf a hyprland.lua en caliente).
#
# Lo que se queda de Omarchy, a propósito: ~/.local/share/omarchy (scripts y
# temas, que ya nada del escritorio usa), ~/.config/omarchy (los temas de nvim,
# btop y la terminal siguen leyendo de ahí), ~/.config/uwsm (la sesión arranca
# con uwsm) y el aviso de batería baja (omarchy-battery-monitor.timer).

set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
respaldo="$HOME/Templates/omarchy-respaldo"

aviso() { printf '\033[33m%s\033[0m\n' "$*"; }
fallo() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
paso() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# Mueve una ruta de $HOME dentro de $retiro conservando su sitio relativo.
apartar() {
	local r=$1
	if [[ -e "$HOME/$r" || -L "$HOME/$r" ]]; then
		mkdir -p "$retiro/$(dirname "$r")"
		mv "$HOME/$r" "$retiro/$r"
		echo "  apartado  ~/$r"
	fi
}

# Enlaza ~/<r> al mismo camino dentro del repo. Si ya hay algo que no es ese
# enlace, se aparta antes.
enlazar() {
	local r=$1
	[[ -e "$repo/$r" ]] || fallo "No existe en el repo: $r"
	if [[ -L "$HOME/$r" && $(readlink "$HOME/$r") == "$repo/$r" ]]; then
		echo "  ya estaba ~/$r"
		return
	fi
	apartar "$r"
	mkdir -p "$(dirname "$HOME/$r")"
	ln -s "$repo/$r" "$HOME/$r"
	echo "  enlazado  ~/$r -> $repo/$r"
}

# Lanza algo como hijo de Hyprland, igual que lo haría el hyprland.start de
# hyprland.lua, para que no muera al cerrar la terminal desde la que se aplica.
lanzar() {
	hyprctl dispatch "hl.dsp.exec_cmd(\"$1\")" >/dev/null
}

# ---------------------------------------------------------------------------
paso "1. Requisitos"

[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || fallo "Ejecútalo desde dentro de la sesión de Hyprland."

rama=$(git -C "$repo" branch --show-current)
[[ $rama == setup/portatil ]] || aviso "El repo está en la rama '$rama', no en setup/portatil."

faltan=()
for b in qs ghostty hyprpaper hypridle hyprlock pavucontrol jq grim slurp satty \
	hyprpicker wl-copy notify-send checkupdates brightnessctl playerctl pactl; do
	command -v "$b" >/dev/null || faltan+=("$b")
done
[[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]] || faltan+=(polkit-gnome)
if ((${#faltan[@]})); then
	fallo "Faltan: ${faltan[*]}
Ejecuta antes: sudo $repo/portatil/paquetes.sh"
fi

Hyprland --verify-config -c "$repo/.config/hypr/hyprland.lua" 2>&1 | grep -q 'config ok' ||
	fallo "hyprland.lua no pasa Hyprland --verify-config; no se aplica nada."
echo "  todo en su sitio"

# ---------------------------------------------------------------------------
paso "2. Copia de Omarchy"

echo "Se va a sustituir el escritorio de Omarchy por el de la torre."
read -r -p "¿Seguir? [s/N] " ok
[[ $ok == [sS]* ]] || exit 0

"$respaldo/hacer-copia.sh" || fallo "La copia ha fallado; no se aplica nada."
snap=$(find "$respaldo" -mindepth 1 -maxdepth 1 -type d -name '20*' | sort | tail -n1)
retiro="$snap/retirado-por-aplicar"
mkdir -p "$retiro"

# ---------------------------------------------------------------------------
paso "3. Fuera el escritorio de Omarchy"

for r in .config/hypr .config/waybar .config/walker .config/elephant \
	.config/mako .config/swayosd .config/autostart/walker.desktop; do
	apartar "$r"
done

systemctl --user disable --now elephant.service swayosd-server.service 2>/dev/null
systemctl --user stop app-walker@autostart.service 2>/dev/null

# ---------------------------------------------------------------------------
paso "4. Setup de la torre"

mkdir -p "$HOME/.config/hypr"
for r in .config/hypr/hyprland.lua .config/hypr/hyprlock.conf .config/hypr/hypridle.conf \
	.config/hypr/scripts .config/quickshell \
	.config/systemd/user/notificaciones.service .config/systemd/user/notificaciones.timer \
	.local/bin/launch-or-focus; do
	enlazar "$r"
done

# Lo que es de este equipo y no va en el repo: los monitores que escribe
# nwg-displays y la config del portal (el selector al compartir pantalla).
for f in monitors.lua xdph.conf; do
	if [[ -f "$retiro/.config/hypr/$f" ]]; then
		cp -a "$retiro/.config/hypr/$f" "$HOME/.config/hypr/$f"
		echo "  conservado ~/.config/hypr/$f"
	fi
done

# El fondo: el mismo que tenía Omarchy, copiado fuera de su carpeta de temas
# para que no dependa de ella. hyprpaper.conf lleva la ruta absoluta porque
# sddm/install.sh la lee tal cual para hacer el fondo del login.
origen=$(readlink -f "$HOME/.config/omarchy/current/background" 2>/dev/null)
if [[ -f $origen ]]; then
	mkdir -p "$HOME/Wallpapers"
	fondo="$HOME/Wallpapers/$(basename "$origen")"
	cp -n "$origen" "$fondo"
else
	aviso "No encuentro el fondo de Omarchy; uso el de Hyprland por defecto."
	fondo=/usr/share/hypr/wall0.png
fi
cat >"$HOME/.config/hypr/hyprpaper.conf" <<EOF
# Fondo de este equipo. No va en el repo: la ruta cambia de una máquina a otra.
# sddm/install.sh lee el "path" de aquí para el fondo de la pantalla de login.

splash = false

wallpaper {
    monitor =
    path = $fondo
    fit_mode = cover
}
EOF
echo "  fondo     $fondo"

systemctl --user daemon-reload
systemctl --user enable --now notificaciones.timer >/dev/null 2>&1 &&
	echo "  activado  notificaciones.timer"

# ---------------------------------------------------------------------------
paso "5. En marcha"

# Lo que arrancó el autostart de Omarchy. mako tiene que irse antes de que
# arranque la barra: es quien tiene ahora org.freedesktop.Notifications, y la
# isla no podría quedarse con el nombre.
pkill -x waybar
pkill -x mako
pkill -x swaybg
pkill -x walker
pkill -x hypridle
sleep 0.5

# Sin hyprland.conf en ~/.config/hypr, Hyprland sólo encuentra hyprland.lua.
hyprctl reload full-reset >/dev/null
sleep 1
errores=$(hyprctl configerrors 2>/dev/null)
if [[ -n ${errores//[[:space:]]/} && $errores != *"no errors"* ]]; then
	aviso "Hyprland avisa de errores en la config:"
	printf '%s\n' "$errores"
fi

# Lo mismo que el hyprland.start de hyprland.lua, que en una recarga no se
# dispara. El agente de polkit no se relanza: sigue vivo desde el arranque.
lanzar "hyprpaper"
lanzar "qs -c bar -d"
lanzar "hypridle"
lanzar "$HOME/.config/hypr/scripts/loopback.sh restore"
lanzar "$HOME/.config/hypr/scripts/updates-notify.sh"
sleep 2

duenyo=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^Comm=//p')
if [[ $duenyo == qs* || $duenyo == quickshell* ]]; then
	echo "  las notificaciones las lleva la barra"
else
	aviso "Las notificaciones las lleva '${duenyo:-nadie}', no la barra. Cierra sesión y vuelve a entrar."
fi

cat <<EOF

Hecho. Omarchy está apartado en:
  $retiro
y la copia completa para volver atrás, en:
  $snap

Si algo se ve raro, cierra sesión (SUPER+M) y vuelve a entrar: el arranque
limpio pasa por hyprland.start, que una recarga en caliente no ejecuta.

Para volver a Omarchy:  $respaldo/restaurar.sh
Paso 3 (login):         sudo $repo/sddm/install.sh
EOF
