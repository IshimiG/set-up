#!/usr/bin/env bash
# Esconder y sacar la barra entera, con SUPER+SHIFT+V.
#
# La barra son dos cosas: la isla de Quickshell en el centro
# (~/.config/quickshell/bar/) y waybar a los lados, con los escritorios y la
# telemetría. Tienen que irse juntas; esconder sólo una dejaría la otra mitad
# flotando sin nada en medio.
#
# Quien decide es la isla, y waybar la sigue. Si se hicieran dos interruptores
# independientes acabarían desparejados en cuanto uno de los dos fallara —que es
# exactamente lo que pasaba con el botón de sesión y sus señales SIGRTMIN—.

set -uo pipefail

readonly CONFIG="bar"

estado=$(qs -c "$CONFIG" ipc call "$CONFIG" toggleBar 2>/dev/null)

case "$estado" in
oculta)
	pkill -x waybar
	;;
visible)
	pgrep -x waybar >/dev/null || setsid waybar >/dev/null 2>&1 &
	;;
*)
	# La isla no está levantada (aún no ha arrancado, o se ha caído). Sin ella
	# no hay a quién preguntar, así que waybar se apaña sola con su propio
	# interruptor, que es lo que este atajo hacía antes de que existiera la
	# isla.
	if pgrep -x waybar >/dev/null; then
		pkill -x waybar
	else
		setsid waybar >/dev/null 2>&1 &
	fi
	;;
esac

exit 0
