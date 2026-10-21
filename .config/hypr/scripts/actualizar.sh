#!/usr/bin/env bash
# Actualiza repos y AUR de una vez, en una terminal que se queda abierta al
# terminar. Lo usan el aviso de actualizaciones (quickshell/updates) y la
# entrada "Actualizar" del menú de sesión (quickshell/bar/PowerPanel.qml).
#
# No lleva sudo delante a propósito: el ayudante del AUR lo pide por su cuenta
# cuando le hace falta y se niega a arrancar como root, porque compilar
# paquetes del AUR con privilegios es justamente lo que no se debe hacer.
#
# paru en la torre (CachyOS) y yay en el portátil, que es el que trajo Omarchy.
# Los dos aceptan -Syu igual y piden sudo igual.
#
# Después, si la rama del equipo trae ~/.local/bin/actualizar-equipo, lo que ese
# equipo quiera hacer al actualizar. Corre aunque el ayudante falle o se
# cancele, porque no depende de los paquetes del sistema; lo común no sabe qué
# hace.

if command -v paru >/dev/null; then paru -Syu; else yay -Syu; fi

if [ -x "$HOME/.local/bin/actualizar-equipo" ]; then
	"$HOME/.local/bin/actualizar-equipo"
fi

printf '\n'
read -r -p 'Pulsa Enter para cerrar… '
