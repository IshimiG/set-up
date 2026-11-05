#!/usr/bin/env bash
# Lo que sólo necesita un portátil. Lo ejecuta setup.sh al final, con sus
# mismos argumentos (--comprobar incluido); no hace falta lanzarlo a mano.
#
# Vale para cualquier portátil de esta rama, no sólo para ishimiPort: los
# monitores los escribe nwg-displays en cada uno (~/.config/hypr/monitors.lua,
# fuera del repo) y la barra enseña la wifi y la batería si las hay.

# hypridle  atenuar, bloquear y apagar la pantalla en reposo (equipo.lua)
# iwd, impala  la wifi de la barra habla con iwd; impala, en el clic derecho
# nwg-displays  colocar los monitores, sobre todo al enchufar uno externo
# polkit-gnome  el agente de polkit (equipo.lua lo arranca)
# brightnessctl  las teclas de brillo
# upower  la batería de la barra
# bluetui  el panel de Bluetooth que abre el botón de la barra (bluez ya viene)
PAQUETES=(hypridle iwd impala nwg-displays polkit-gnome brightnessctl upower bluetui)

set -uo pipefail

comprobar=false
[[ ${1:-} == --comprobar ]] && comprobar=true

aviso() { printf '\033[33m%s\033[0m\n' "$*"; }
hacer() {
	if $comprobar; then
		echo "  haría: $*"
	else
		"$@"
	fi
}

mapfile -t faltan < <(pacman -T "${PAQUETES[@]}")
if ((${#faltan[@]})); then
	echo "  faltan: ${faltan[*]}"
	hacer sudo pacman -S --needed "${faltan[@]}"
else
	echo "  todo instalado"
fi

# La wifi de la barra va contra iwd. Si la máquina usa NetworkManager, no se
# activa: los dos a la vez se pelean por la tarjeta.
if systemctl is-active --quiet NetworkManager; then
	aviso "  NetworkManager está activo: la wifi de la barra necesita iwd; no lo activo"
elif systemctl is-enabled --quiet iwd; then
	echo "  iwd ya activo"
else
	hacer sudo systemctl enable --now iwd
fi

# ---------------------------------------------------------------------------
# Menos RAM: programas que no hacen falta en cada inicio de sesión. Se pueden
# abrir a mano cuando se quieran. ~/.config/autostart no está enlazado al repo
# (tiene también entradas de otras apps), así que se escribe desde aquí, de
# forma idempotente, en vez de versionar los .desktop.
autostart="$HOME/.config/autostart"

# Entradas del sistema (/etc/xdg/autostart): un .desktop con el mismo nombre y
# Hidden=true en el del usuario las anula. limine-restore-notify no se toca.
for e in localsearch-3 print-applet limine-snapper-notify; do
	f="$autostart/$e.desktop"
	if grep -qx 'Hidden=true' "$f" 2>/dev/null; then
		echo "  autostart de $e ya desactivado"
	else
		echo "  desactivo el autostart de $e"
		if ! $comprobar; then
			mkdir -p "$autostart"
			printf '[Desktop Entry]\nType=Application\nName=%s (desactivado)\nHidden=true\n' "$e" >"$f"
		fi
	fi
done

# 1Password crea su propia entrada de usuario (y puede reescribirla al
# arrancar): se le añade Hidden=true, guardando antes el original.
op="$autostart/com.onepassword.OnePassword.desktop"
if [[ ! -f $op ]]; then
	echo "  1Password sin entrada de autostart: nada que hacer"
elif grep -qx 'Hidden=true' "$op"; then
	echo "  autostart de 1Password ya desactivado"
else
	echo "  desactivo el autostart de 1Password"
	if ! $comprobar; then
		respaldo="$autostart/.respaldo-$(date +%Y-%m-%d)"
		mkdir -p "$respaldo"
		[[ -e $respaldo/${op##*/} ]] || cp -p "$op" "$respaldo/"
		sed -i '/^Hidden=/d' "$op"
		printf 'Hidden=true\n' >>"$op"
	fi
fi

# localsearch (indexador) arranca por D-Bus cuando alguien lo pide, no por
# autostart. Enmascarados no arrancan; Nautilus pierde la búsqueda por
# contenido, pero no la de nombres.
for s in localsearch-3 localsearch-control-3 localsearch-writeback-3; do
	if [[ $(systemctl --user is-enabled "$s.service" 2>/dev/null) == masked ]]; then
		echo "  $s ya enmascarado"
	elif systemctl --user cat "$s.service" >/dev/null 2>&1; then
		hacer systemctl --user mask "$s.service"
	fi
done

# xe: el controlador nuevo de Intel, cargado sin usarse (la Iris Xe de Raptor
# Lake-P va con i915). Lo escribe root; el initramfs/UKI (hook modconf) copia
# /etc/modprobe.d, así que hay que regenerarlo para que no cargue xe al inicio.
if grep -qxs 'blacklist xe' /etc/modprobe.d/blacklist-xe.conf; then
	echo "  xe ya en lista negra"
else
	hacer sudo sh -c "echo 'blacklist xe' >/etc/modprobe.d/blacklist-xe.conf"
	command -v limine-update >/dev/null && hacer sudo limine-update
fi
