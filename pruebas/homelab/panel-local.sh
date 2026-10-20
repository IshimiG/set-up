#!/bin/sh
# Un panel del homelab de prueba, en local, para probar el cajón (Api.qml) sin
# tocar el NUC ni panel.lab.ishimi.es.
#
# Compila el panel de ~/Projects/homelab/panel (sin tocar nada allí: se monta
# de solo lectura) en el contenedor de Go, igual que deploy/build.sh, y lo
# arranca en otro contenedor con:
#
#   - un vault falso: un «00 Inicio.md» con tareas vencidas, de hoy, futuras,
#     hechas y en pausa, y una nota de proyecto con otra tarea vencida;
#   - un Docker falso (api/falsos/docker-falso.go) dentro del contenedor: el
#     socket de verdad nunca se le da, porque sus acciones son root;
#   - una alerta de disco desde el principio (diskAlertPercent 1 con «/»), y
#     las de los contenedores falsos;
#   - sin tokens de GitHub ni de Google y sin FINANZAS_DSN.
#
# Delante, un Caddy falso (api/falsos/caddy-falso.go) con usuario y contraseña
# de prueba, como el del NUC: 401 sin la contraseña buena, 502 con el panel
# parado y X-Remote-User para el panel.
#
#   panel-local.sh arrancar      compila si hace falta y arranca los dos
#   panel-local.sh parar         los para y los borra (con la carpeta)
#   panel-local.sh parar-panel   para solo el panel (el Caddy falso da 502)
#   panel-local.sh seguir-panel  vuelve a arrancar el panel parado
#   panel-local.sh alerta        una alerta nueva (una actualización de paquetes
#                                que falla); el panel la ve en unos 3 s
#   panel-local.sh congelar      congela el panel (docker pause): las conexiones
#                                siguen abiertas pero callan, como tras una
#                                suspensión o un cambio de red
#   panel-local.sh descongelar   lo deja seguir
#   panel-local.sh estado        cómo están los contenedores
#
# Direcciones: http://127.0.0.1:8791 (el Caddy falso, con contraseña) y
# http://127.0.0.1:8790 (el panel directo, sin contraseña: usuario «-»).
#
# Variables (todas opcionales):
#   PANEL_LOCAL_DIR           la carpeta de trabajo (vault, estado, registro)
#   PANEL_LOCAL_CREDENCIALES  un fichero «usuario:contraseña» para el Caddy
#                             falso; sin él se inventa uno en la carpeta
#   PANEL_SRC                 el código del panel (~/Projects/homelab/panel)
#
# Los contenedores se llaman prueba-fase2-*, y «parar» los quita.
set -eu

aqui=$(dirname "$(readlink -f "$0")")
dir=${PANEL_LOCAL_DIR:-${TMPDIR:-/tmp}/homelab-panel-local}
src=${PANEL_SRC:-$HOME/Projects/homelab/panel}
imagen=golang:1.27.1-trixie
cache=${XDG_CACHE_HOME:-$HOME/.cache}/homelab-panel-build
bin=${XDG_CACHE_HOME:-$HOME/.cache}/set-up-pruebas/homelab-panel
panel=prueba-fase2-panel
caddy=prueba-fase2-caddy
puerto_panel=8790
puerto_caddy=8791

# Espera a que una dirección responda con ese código, hasta $3 décimas.
esperar() {
	i=0
	while [ "$(curl -s -o /dev/null -w '%{http_code}' "$1" 2>/dev/null)" != "$2" ]; do
		i=$((i + 1))
		if [ "$i" -ge "$3" ]; then
			echo "No responde $1 con $2" >&2
			return 1
		fi
		sleep 0.1
	done
}

compilar() {
	mkdir -p "$cache/mod" "$cache/build" "$bin"
	# Se compila otra vez solo si algo es más nuevo que lo compilado.
	if [ -x "$bin/homelab-panel" ] && [ -x "$bin/docker-falso" ] && [ -x "$bin/caddy-falso" ] &&
		[ -z "$(find "$src" "$aqui/api/falsos" -newer "$bin/homelab-panel" \( -name '*.go' -o -name '*.js' -o -name '*.css' -o -name '*.html' -o -name go.mod \) -print -quit)" ]; then
		return
	fi
	echo "Compilando el panel y los falsos en $imagen…"
	docker run --rm --name prueba-fase2-compilar \
		--user "$(id -u):$(id -g)" \
		-v "$src:/src:ro" -v "$aqui/api/falsos:/falsos:ro" -v "$bin:/out" \
		-v "$cache/mod:/go/pkg/mod" -v "$cache/build:/tmp/gocache" \
		-e GOCACHE=/tmp/gocache -e CGO_ENABLED=0 -e GOTOOLCHAIN=local -e GOFLAGS=-buildvcs=false \
		-w /src "$imagen" \
		sh -c 'go build -trimpath -o /out/homelab-panel ./cmd/homelab-panel &&
			cd /falsos && go build -o /out/docker-falso docker-falso.go && go build -o /out/caddy-falso caddy-falso.go'
}

# El vault falso, con fechas relativas a hoy.
vault() {
	d() { date -d "$1 days" +%F; }
	mkdir -p "$dir/vault/10 Proyectos"
	cat >"$dir/vault/00 Inicio.md" <<-EOF
		---
		tipo: inicio
		---
		# Inicio

		## 📌 Pendientes

		### 🏠 Homelab

		- [ ] **Casa** · Cambiar el filtro del agua 📅 $(d 0)
		- [ ] Mirar los discos 🔼 📅 $(d 5)
		- [x] Una tarea ya hecha 📅 $(d -2) ✅ $(d -1)

		### 🎓 Clase

		- [ ] Entrega de [[prueba]] 🔺 📅 $(d -1)
		- [ ] Una sin fecha 🔽

		### General

		- [ ] Otra **vencida** 📅 $(d -11)

		### ⏸️ En pausa

		- [ ] Pausada que venció 🔽 📅 $(d -3)
		- [ ] Pausada de hoy 📅 $(d 0)
	EOF
	cat >"$dir/vault/10 Proyectos/Proyecto de prueba.md" <<-EOF
		---
		tipo: proyecto
		estado: activo
		prioridad: media
		---
		# Proyecto de prueba

		- [ ] Tarea en otra nota 📅 $(d -2)
	EOF
}

arrancar() {
	compilar
	if docker container inspect "$panel" >/dev/null 2>&1 || docker container inspect "$caddy" >/dev/null 2>&1; then
		echo "Ya hay un panel local; antes, $0 parar" >&2
		exit 1
	fi
	mkdir -p "$dir/estado" "$dir/apt"
	chmod 700 "$dir"
	vault
	: >"$dir/apt/history.log"
	# Los colores de dos secciones, como si se hubieran elegido en la web.
	printf '{"colores": {"homelab": "#6aa8ff", "clase": "#b48cff"}}\n' >"$dir/estado/estado.json"
	cat >"$dir/dev.json" <<-EOF
		{
		  "listen": "127.0.0.1:$puerto_panel",
		  "auditLog": "/estado/audit.log",
		  "diskAlertPercent": 1,
		  "disks": ["/"],
		  "vault": "/vault",
		  "finanzas": {"extractos": "/tmp/extractos"},
		  "clase": {"data": "/tmp/clase"}
		}
	EOF
	printf '#!/bin/sh\nexit 0\n' >"$dir/docker"
	chmod +x "$dir/docker"
	cat >"$dir/arranque.sh" <<-'EOF'
		#!/bin/sh
		/prueba/bin/docker-falso -sock /tmp/docker-falso.sock &
		i=0
		while [ ! -S /tmp/docker-falso.sock ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
		exec /prueba/bin/homelab-panel -config /prueba/dev.json
	EOF
	chmod +x "$dir/arranque.sh"
	if [ -n "${PANEL_LOCAL_CREDENCIALES:-}" ]; then
		cp "$PANEL_LOCAL_CREDENCIALES" "$dir/credenciales"
	elif [ ! -s "$dir/credenciales" ]; then
		umask 077
		printf 'equipo-prueba:%s\n' "$(head -c 12 /dev/urandom | base64 | tr -d '/+=')" >"$dir/credenciales"
	fi
	chmod 600 "$dir/credenciales"

	docker run -d --name "$panel" --network host \
		--user "$(id -u):$(id -g)" \
		-v "$bin:/prueba/bin:ro" -v "$dir/dev.json:/prueba/dev.json:ro" \
		-v "$dir/arranque.sh:/prueba/arranque.sh:ro" -v "$dir/docker:/usr/local/bin/docker:ro" \
		-v "$dir/vault:/vault" -v "$dir/estado:/estado" -v "$dir/apt:/var/log/apt" \
		-v /etc/localtime:/etc/localtime:ro \
		-e DOCKER_HOST=unix:///tmp/docker-falso.sock \
		"$imagen" /prueba/arranque.sh >/dev/null
	docker run -d --name "$caddy" --network host \
		--user "$(id -u):$(id -g)" \
		-v "$bin:/prueba/bin:ro" -v "$dir/credenciales:/prueba/credenciales:ro" \
		"$imagen" /prueba/bin/caddy-falso -listen "127.0.0.1:$puerto_caddy" \
		-upstream "http://127.0.0.1:$puerto_panel" -credenciales /prueba/credenciales >/dev/null
	esperar "http://127.0.0.1:$puerto_panel/api/yo" 200 200
	esperar "http://127.0.0.1:$puerto_caddy/api/yo" 401 50
	echo "Panel local en http://127.0.0.1:$puerto_caddy (usuario y contraseña en $dir/credenciales)"
}

parar() {
	docker unpause "$panel" >/dev/null 2>&1 || true
	docker rm -f "$panel" "$caddy" >/dev/null 2>&1 || true
	rm -rf "$dir"
}

parar_panel() {
	docker stop -t 5 "$panel" >/dev/null
}

seguir_panel() {
	docker start "$panel" >/dev/null
	esperar "http://127.0.0.1:$puerto_panel/api/yo" 200 200
}

# Una actualización de paquetes que falla, en el historial de apt que el panel
# sigue con inotify: «Falló una actualización de paquetes», de nivel error.
alerta() {
	ahora=$(date '+%F  %T')
	cat >>"$dir/apt/history.log" <<-EOF

		Start-Date: $ahora
		Commandline: apt-get install paquete-de-prueba-$(date +%s%N)
		Requested-By: prueba (1000)
		Error: Sub-process /usr/bin/dpkg returned an error code (1)
		End-Date: $ahora
	EOF
}

case ${1:-} in
arrancar) arrancar ;;
parar) parar ;;
parar-panel) parar_panel ;;
seguir-panel) seguir_panel ;;
alerta) alerta ;;
congelar) docker pause "$panel" >/dev/null ;;
descongelar) docker unpause "$panel" >/dev/null ;;
estado) docker ps -a --filter name=prueba-fase2- --format '{{.Names}}\t{{.Status}}' ;;
*)
	sed -n '2,/^set -eu/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac
