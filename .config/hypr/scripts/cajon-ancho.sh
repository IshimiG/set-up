#!/bin/sh
# SUPER+' / SUPER+¡ (con ALT o CTRL para el paso fino o grueso): con el cajón del
# homelab abierto cambian su ancho; si no, redimensionan la ventana activa.
# Uso: cajon-ancho.sh <paso en px, + ensancha, - estrecha>
paso="$1"
estado=$(qs -c homelab ipc call homelab estado 2>/dev/null)
case "$estado" in
abierto | fijado)
	exec qs -c homelab ipc call homelab ancho "$paso" >/dev/null 2>&1
	;;
esac
# ' ensancha la ventana hacia la izquierda (x negativo en Hyprland).
exec hyprctl dispatch "hl.dsp.window.resize({ x = $((-paso)), y = 0, relative = true })" >/dev/null 2>&1
