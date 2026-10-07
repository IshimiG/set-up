#!/usr/bin/env bash
# La wifi de la barra, contra iwd por D-Bus. La usa quickshell/bar/Wifi.qml.
#
# Va contra iwd directamente porque es lo que hay en las dos máquinas: no hay
# NetworkManager, y el módulo Quickshell.Networking sólo sabe hablar con él.
#
#   wifi.sh estado            JSON con la radio, la conexión y las redes a la vista
#   wifi.sh vigilar           una línea por cada señal de iwd (para no muestrear)
#   wifi.sh escanear
#   wifi.sh conectar RUTA     red abierta o ya guardada (RUTA = objeto Network)
#   wifi.sh clave             WPA personal: WIFI_SSID y WIFI_CLAVE en el entorno
#   wifi.sh empresa           802.1X (WIFI_EDU, eduroam): WIFI_SSID, WIFI_METODO
#                             (PEAP o TTLS), WIFI_USUARIO y WIFI_CLAVE en el entorno
#   wifi.sh desconectar
#   wifi.sh olvidar RUTA      la red deja de estar guardada
#   wifi.sh radio on|off
#
# Las contraseñas llegan por el entorno y no como argumentos: los argumentos de
# un proceso los puede leer cualquiera con `ps`, el entorno sólo su dueño. La
# excepción es la WPA personal, que va a iwctl como argumento porque es la única
# forma de pasársela sin registrar un agente de D-Bus propio.
#
# Cuando algo falla se escribe el motivo, en una línea y en castellano, por la
# salida estándar, y se sale con error: Wifi.qml lo enseña tal cual.

set -uo pipefail

iwd=net.connman.iwd
yo=$(readlink -f "$0")

llamar() { busctl --system --json=short call "$iwd" "$@"; }

objetos() { llamar / org.freedesktop.DBus.ObjectManager GetManagedObjects; }

# El primer dispositivo wifi. Existe aunque la radio esté apagada; lo que
# desaparece entonces es su interfaz Station.
dispositivo() {
	objetos | jq -r '.data[0] | to_entries[] | select(.value["net.connman.iwd.Device"]) | .key' | head -n1
}

nombre_dispositivo() {
	busctl --system --json=short get-property "$iwd" "$1" "$iwd.Device" Name | jq -r .data
}

# Traduce el error de busctl o de iwctl a algo que se pueda enseñar.
explicar() {
	local m
	m=$(sed 's/\x1b\[[0-9;]*m//g; s/^Call failed: //' <<<"$1" | grep -v '^[[:space:]]*$' | tail -n1)
	case $m in
	*"Operation failed"* | *"Failed"*) echo "No se ha podido conectar. ¿Contraseña o usuario incorrectos?" ;;
	*"aborted"* | *"Aborted"*) echo "Conexión cancelada" ;;
	*"Not configured"* | *"NotConfigured"*) echo "Esta red necesita usuario y contraseña" ;;
	*"No Agent"* | *"NoAgent"*) echo "Esta red necesita contraseña" ;;
	*"in progress"* | *"Busy"*) echo "Ya hay una conexión en marcha" ;;
	*"Timeout"* | *"timed out"*) echo "La red no contesta" ;;
	*"Not found"* | *"NotFound"*) echo "La red ya no está a la vista" ;;
	"") echo "No se ha podido conectar" ;;
	*) echo "$m" ;;
	esac
}

fallar() {
	echo "$1"
	exit 1
}

estado() {
	local objs dev ip="" rssi="{}" diag="{}"
	objs=$(objetos 2>/dev/null) || {
		echo '{"iwd":false}'
		return
	}
	dev=$(jq -r '.data[0] | to_entries[] | select(.value["net.connman.iwd.Device"]) | .key' <<<"$objs" | head -n1)

	if [[ -n $dev ]] && jq -e --arg d "$dev" '.data[0][$d]["net.connman.iwd.Station"]' <<<"$objs" >/dev/null; then
		# La intensidad sólo sale de aquí: los objetos Network no la llevan.
		# Viene en centésimas de dBm.
		rssi=$(llamar "$dev" "$iwd.Station" GetOrderedNetworks 2>/dev/null |
			jq -c '.data[0] | map({key: .[0], value: .[1]}) | from_entries') || rssi="{}"
		# Sin conexión esto falla, y entonces no hay frecuencia que enseñar.
		diag=$(llamar "$dev" "$iwd.StationDiagnostic" GetDiagnostics 2>/dev/null |
			jq -c '.data[0] | map_values(.data)') || diag="{}"
		ip=$(ip -4 -o addr show dev "$(nombre_dispositivo "$dev")" 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')
	fi

	jq -cn --argjson o "$objs" --argjson r "$rssi" --argjson d "$diag" --arg dev "$dev" --arg ip "$ip" '
		# De dBm a porcentaje, con la misma regla que usa NetworkManager:
		# -100 dBm es 0 % y -50 dBm o más es 100 %.
		def pct: if . == null then 0 else (. / 100 + 100) * 2 | floor | if . > 100 then 100 elif . < 0 then 0 else . end end;
		($o.data[0]) as $t
		| ($t[$dev] // {}) as $obj
		| {
			iwd: true,
			hay: ($dev != ""),
			encendida: ($obj["net.connman.iwd.Device"].Powered.data // false),
			estado: ($obj["net.connman.iwd.Station"].State.data // "apagada"),
			escaneando: ($obj["net.connman.iwd.Station"].Scanning.data // false),
			frecuencia: ($d.Frequency // 0),
			ip: $ip,
			redes: ([
				$t | to_entries[]
				| select(.value["net.connman.iwd.Network"] and .value["net.connman.iwd.Network"].Device.data == $dev)
				| .value["net.connman.iwd.Network"] as $n
				| {
					ruta: .key,
					nombre: $n.Name.data,
					tipo: $n.Type.data,
					conectada: ($n.Connected.data // false),
					guardada: ($n.KnownNetwork != null),
					senal: ($r[.key] | pct)
				}
			] | sort_by([(if .conectada then 0 else 1 end), -.senal, .nombre]))
		}'
}

conectar() {
	local salida
	[[ -n ${1:-} ]] || fallar "Falta la red"
	salida=$(llamar "$1" "$iwd.Network" Connect 2>&1) || fallar "$(explicar "$salida")"
}

clave() {
	local dev salida
	[[ -n ${WIFI_SSID:-} && -n ${WIFI_CLAVE:-} ]] || fallar "Falta la contraseña"
	dev=$(dispositivo)
	[[ -n $dev ]] || fallar "No hay tarjeta wifi"
	salida=$(iwctl --passphrase "$WIFI_CLAVE" station "$(nombre_dispositivo "$dev")" connect "$WIFI_SSID" 2>&1) ||
		fallar "$(explicar "$salida")"
	# iwctl no siempre sale con error cuando falla: también hay que mirar lo
	# que ha dicho.
	if grep -qiE 'failed|invalid|not found|aborted' <<<"$salida"; then
		fallar "$(explicar "$salida")"
	fi
}

# 802.1X. iwd no deja dar de alta una red de empresa por D-Bus: hace falta su
# fichero en /var/lib/iwd, que es de root. Así que el fichero lo escribe una
# segunda llamada a este mismo script con pkexec (el agente de polkit pide la
# contraseña de administrador), y la conexión se hace después, ya como usuario.
empresa() {
	local dev ruta salida i codigo
	[[ -n ${WIFI_SSID:-} && -n ${WIFI_USUARIO:-} && -n ${WIFI_CLAVE:-} ]] || fallar "Faltan el usuario o la contraseña"

	# pkexec vacía el entorno, así que los datos le llegan por la entrada.
	printf '%s\n' "$WIFI_SSID" "${WIFI_METODO:-PEAP}" "$WIFI_USUARIO" "$WIFI_CLAVE" |
		pkexec "$yo" escribir-8021x
	codigo=$?
	case $codigo in
	0) ;;
	126 | 127) fallar "Sin permiso: se canceló la contraseña de administrador" ;;
	*) fallar "No se ha podido guardar la configuración de la red" ;;
	esac

	# iwd vigila /var/lib/iwd y la red pasa a estar guardada al momento, pero
	# no en el mismo instante: se espera a verla antes de conectar.
	dev=$(dispositivo)
	for i in 1 2 3 4 5 6 7 8 9 10; do
		ruta=$(objetos | jq -r --arg s "$WIFI_SSID" --arg d "$dev" '.data[0] | to_entries[]
			| select(.value["net.connman.iwd.Network"].Name.data == $s
				and .value["net.connman.iwd.Network"].Type.data == "8021x"
				and .value["net.connman.iwd.Network"].Device.data == $d) | .key' | head -n1)
		[[ -n $ruta ]] && break
		sleep 0.3
	done
	[[ -n $ruta ]] || fallar "La red ya no está a la vista"

	salida=$(llamar "$ruta" "$iwd.Network" Connect 2>&1) || fallar "$(explicar "$salida")"
}

# Como root, desde empresa(). Lee ssid, método, usuario y contraseña, una por
# línea, y escribe el fichero de la red.
#
# Si la red ya estaba configurada se cambian sólo el usuario y la contraseña y
# se respeta todo lo demás (el método, el certificado de la CA, el dominio del
# servidor...): así cambiar la contraseña de la universidad no rompe una
# configuración que funcionaba. Si no existía, se escribe una nueva con el
# método elegido, que es lo que piden casi todas: PEAP con MSCHAPv2 o TTLS con
# PAP.
escribir_8021x() {
	local ssid metodo usuario clave fichero tmp anonimo hex
	IFS= read -r ssid || exit 2
	IFS= read -r metodo || exit 2
	IFS= read -r usuario || exit 2
	IFS= read -r clave || exit 2
	[[ -n $ssid && -n $usuario && -n $clave ]] || exit 2
	[[ $metodo == PEAP || $metodo == TTLS ]] || exit 2
	# Un retorno de carro colaría una línea más en el fichero.
	[[ $ssid$usuario$clave != *$'\r'* ]] || exit 2

	# El nombre del fichero es el SSID tal cual si sólo lleva letras, cifras,
	# espacios, - y _; si no, "=" y el SSID en hexadecimal. Es la regla de iwd.
	# Las letras son las ASCII: en un locale UTF-8, [A-Za-z] también deja
	# pasar la "é" de "Café", y iwd buscaría otro fichero.
	local LC_ALL=C
	if [[ $ssid =~ ^[A-Za-z0-9\ _-]+$ ]]; then
		fichero="/var/lib/iwd/$ssid.8021x"
	else
		hex=$(printf '%s' "$ssid" | od -An -tx1 | tr -d ' \n')
		fichero="/var/lib/iwd/=$hex.8021x"
	fi

	# iwd interpreta las barras invertidas de los valores como escapes.
	usuario=${usuario//\\/\\\\}
	clave=${clave//\\/\\\\}

	umask 077
	tmp=$(mktemp /var/lib/iwd/.wifi-sh.XXXXXX) || exit 3
	trap 'rm -f "$tmp"' EXIT

	if [[ -f $fichero ]] && grep -qE '^EAP-[A-Za-z]+-Phase2-Password=' "$fichero"; then
		# Con substr y no con sub(): en el reemplazo de sub() un "&" vale por
		# el texto encontrado, y una contraseña puede llevarlo.
		U=$usuario C=$clave awk '
			/^EAP-[A-Za-z]+-Phase2-Identity=/ { $0 = substr($0, 1, index($0, "=")) ENVIRON["U"] }
			/^EAP-[A-Za-z]+-Phase2-Password=/ { $0 = substr($0, 1, index($0, "=")) ENVIRON["C"] }
			{ print }' "$fichero" >"$tmp" || exit 3
	else
		# La identidad de fuera va anónima cuando el usuario lleva dominio: es
		# la que viaja sin cifrar, y el servidor sólo necesita el dominio para
		# saber a qué institución preguntar.
		if [[ $usuario == *@* ]]; then
			anonimo="anonymous@${usuario#*@}"
		else
			anonimo=$usuario
		fi
		{
			echo "[Security]"
			echo "EAP-Method=$metodo"
			echo "EAP-Identity=$anonimo"
			if [[ $metodo == PEAP ]]; then
				echo "EAP-PEAP-Phase2-Method=MSCHAPV2"
				echo "EAP-PEAP-Phase2-Identity=$usuario"
				echo "EAP-PEAP-Phase2-Password=$clave"
			else
				echo "EAP-TTLS-Phase2-Method=Tunneled-PAP"
				echo "EAP-TTLS-Phase2-Identity=$usuario"
				echo "EAP-TTLS-Phase2-Password=$clave"
			fi
			echo
			echo "[Settings]"
			echo "AutoConnect=true"
		} >"$tmp" || exit 3
	fi

	chmod 600 "$tmp"
	mv -f "$tmp" "$fichero" || exit 3
	trap - EXIT
}

desconectar() {
	local dev salida
	dev=$(dispositivo)
	[[ -n $dev ]] || fallar "No hay tarjeta wifi"
	salida=$(llamar "$dev" "$iwd.Station" Disconnect 2>&1) || fallar "$(explicar "$salida")"
}

olvidar() {
	local guardada salida
	[[ -n ${1:-} ]] || fallar "Falta la red"
	guardada=$(busctl --system --json=short get-property "$iwd" "$1" "$iwd.Network" KnownNetwork 2>/dev/null | jq -r .data)
	[[ -n $guardada && $guardada != null ]] || fallar "Esa red no estaba guardada"
	salida=$(llamar "$guardada" "$iwd.KnownNetwork" Forget 2>&1) || fallar "$(explicar "$salida")"
}

radio() {
	local dev valor=false salida
	[[ ${1:-} == on ]] && valor=true
	# Con la radio bloqueada por rfkill (la tecla de modo avión), encenderla
	# desde iwd no basta.
	[[ $valor == true ]] && rfkill unblock wifi 2>/dev/null
	dev=$(dispositivo)
	[[ -n $dev ]] || fallar "No hay tarjeta wifi"
	salida=$(busctl --system set-property "$iwd" "$dev" "$iwd.Device" Powered b "$valor" 2>&1) ||
		fallar "$(explicar "$salida")"
}

case ${1:-} in
estado) estado ;;
vigilar) exec gdbus monitor --system --dest "$iwd" ;;
escanear) llamar "$(dispositivo)" "$iwd.Station" Scan >/dev/null 2>&1 || true ;;
conectar) conectar "${2:-}" ;;
clave) clave ;;
empresa) empresa ;;
escribir-8021x) escribir_8021x ;;
desconectar) desconectar ;;
olvidar) olvidar "${2:-}" ;;
radio) radio "${2:-}" ;;
*)
	echo "uso: $0 estado|vigilar|escanear|conectar RUTA|clave|empresa|desconectar|olvidar RUTA|radio on|off" >&2
	exit 2
	;;
esac
