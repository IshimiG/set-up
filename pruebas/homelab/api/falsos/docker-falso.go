// docker-falso: un Docker Engine de mentira para el panel local de las pruebas
// (pruebas/homelab/panel-local.sh). El panel lee el socket de Docker, y el de
// verdad es root en la máquina: aquí no se le da nunca. Esto contesta lo justo
// para que el panel arranque y pinte un servidor con problemas:
//
//   - GET /_ping, para la negociación de versión;
//   - GET /containers/json y /containers/{id}/json, con la lista fija de abajo;
//   - GET /containers/{id}/logs, unas líneas;
//   - GET /events, que se queda abierto sin mandar nada;
//   - cualquier POST, 204 sin hacer nada.
//
// Escucha en un socket Unix (-sock), dentro del contenedor del panel, así que
// no abre ningún puerto. Solo biblioteca estándar: se compila con
// «go build docker-falso.go» en el contenedor de Go.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
)

type falso struct {
	nombre, stack, servicio string
	estado                  string // running, exited, restarting…
	salud                   string // "", healthy, unhealthy
	codigo                  int
	reinicios               int
	oneOff                  bool // docker compose run
	autoRemove              bool // docker run --rm
}

// La lista: 6 contenedores de servicio (3 en marcha) y 3 problemas
// (immich_server unhealthy, immich_ml reiniciándose y vaultwarden parado con
// código 1); syncthing-relay parado con 0 no es un problema; tr-sync y
// pdftotext son de un solo uso y no cuentan.
var contenedores = []falso{
	{nombre: "caddy", stack: "homelab", servicio: "caddy", estado: "running", salud: "healthy"},
	{nombre: "vaultwarden", stack: "homelab", servicio: "vaultwarden", estado: "exited", codigo: 1},
	{nombre: "syncthing", stack: "sync", servicio: "syncthing", estado: "running"},
	{nombre: "syncthing-relay", stack: "sync", servicio: "relay", estado: "exited", codigo: 0},
	{nombre: "immich_server", stack: "immich", servicio: "immich-server", estado: "running", salud: "unhealthy"},
	{nombre: "immich_ml", stack: "immich", servicio: "immich-machine-learning", estado: "restarting", reinicios: 5},
	{nombre: "traderepublic-tr-sync-run-1a2b3c", stack: "traderepublic", servicio: "tr-sync", estado: "exited", oneOff: true},
	{nombre: "pdftotext-prueba", estado: "running", autoRemove: true},
}

func (c falso) labels() map[string]string {
	l := map[string]string{}
	if c.stack != "" {
		l["com.docker.compose.project"] = c.stack
		l["com.docker.compose.service"] = c.servicio
		l["com.docker.compose.oneoff"] = "False"
		if c.oneOff {
			l["com.docker.compose.oneoff"] = "True"
		}
	}
	return l
}

func (c falso) resumen() map[string]any {
	m := map[string]any{
		"Id":      "id-" + c.nombre,
		"Names":   []string{"/" + c.nombre},
		"Image":   "prueba/" + c.nombre + ":latest",
		"ImageID": "sha256:0",
		"Command": "/bin/true",
		"Created": 1792400000,
		"Ports":   []any{},
		"Labels":  c.labels(),
		"State":   c.estado,
		"Status":  c.estado,
	}
	if c.salud != "" {
		m["Health"] = map[string]any{"Status": c.salud, "FailingStreak": 0}
	}
	return m
}

func (c falso) inspect() map[string]any {
	st := map[string]any{
		"Status":     c.estado,
		"Running":    c.estado == "running",
		"Restarting": c.estado == "restarting",
		"Dead":       c.estado == "dead",
		"ExitCode":   c.codigo,
		"StartedAt":  "2026-10-20T08:00:00Z",
		"FinishedAt": "0001-01-01T00:00:00Z",
	}
	if c.estado != "running" {
		st["FinishedAt"] = "2026-10-20T09:00:00Z"
	}
	if c.salud != "" {
		st["Health"] = map[string]any{"Status": c.salud, "FailingStreak": 0, "Log": []any{}}
	}
	return map[string]any{
		"Id":           "id-" + c.nombre,
		"Name":         "/" + c.nombre,
		"RestartCount": c.reinicios,
		"State":        st,
		"HostConfig":   map[string]any{"AutoRemove": c.autoRemove},
		"Config":       map[string]any{"Tty": true, "Labels": c.labels()},
	}
}

func buscar(id string) (falso, bool) {
	for _, c := range contenedores {
		if c.nombre == id || "id-"+c.nombre == id {
			return c, true
		}
	}
	return falso{}, false
}

func escribirJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func manejar(w http.ResponseWriter, r *http.Request) {
	p := r.URL.Path
	// Sin el prefijo de versión: /v1.52/containers/json → /containers/json.
	if strings.HasPrefix(p, "/v") {
		if i := strings.Index(p[1:], "/"); i >= 0 {
			p = p[i+1:]
		}
	}
	w.Header().Set("Api-Version", "1.52")
	w.Header().Set("Ostype", "linux")
	switch {
	case p == "/_ping":
		w.Write([]byte("OK"))
	case r.Method == http.MethodPost:
		w.WriteHeader(http.StatusNoContent)
	case p == "/containers/json":
		lista := []map[string]any{}
		for _, c := range contenedores {
			lista = append(lista, c.resumen())
		}
		escribirJSON(w, http.StatusOK, lista)
	case p == "/events":
		// Abierto y callado hasta que el panel se vaya.
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
		<-r.Context().Done()
	case strings.HasPrefix(p, "/containers/") && strings.HasSuffix(p, "/json"):
		c, ok := buscar(strings.TrimSuffix(strings.TrimPrefix(p, "/containers/"), "/json"))
		if !ok {
			escribirJSON(w, http.StatusNotFound, map[string]string{"message": "No such container"})
			return
		}
		escribirJSON(w, http.StatusOK, c.inspect())
	case strings.HasPrefix(p, "/containers/") && strings.HasSuffix(p, "/logs"):
		fmt.Fprint(w, "2026-10-20T08:00:00.000000000Z línea de prueba del contenedor\n")
	default:
		escribirJSON(w, http.StatusNotFound, map[string]string{"message": "docker-falso: " + r.Method + " " + p})
	}
}

func main() {
	sock := flag.String("sock", "/tmp/docker-falso.sock", "socket Unix donde escuchar")
	flag.Parse()
	log.SetFlags(0)
	os.Remove(*sock) // el de un arranque anterior del mismo contenedor
	ln, err := net.Listen("unix", *sock)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("docker-falso en %s", *sock)
	log.Fatal(http.Serve(ln, http.HandlerFunc(manejar)))
}
