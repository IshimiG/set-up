// caddy-falso: hace de Caddy delante del panel local de las pruebas
// (pruebas/homelab/panel-local.sh), para probar el cajón con usuario y
// contraseña como en el NUC sin tocar el Caddy de verdad:
//
//   - pide basic_auth: sin cabecera o con una contraseña que no es, 401 con
//     «WWW-Authenticate: Basic», como Caddy;
//   - con la buena, pasa la petición al panel con X-Remote-User (pisando la que
//     mande el cliente), y el panel decide los permisos con él;
//   - si el panel no responde, 502, como Caddy.
//
// Los usuarios y sus contraseñas, de prueba, se leen de un fichero
// (-credenciales, una línea «usuario:contraseña» por usuario), nunca de la
// línea de órdenes. El registro apunta método, ruta, estado y usuario, nunca la
// contraseña. Solo biblioteca estándar.
package main

import (
	"bufio"
	"crypto/subtle"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
)

func leerCredenciales(ruta string) map[string]string {
	f, err := os.Open(ruta)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	out := map[string]string{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		u, c, ok := strings.Cut(sc.Text(), ":")
		if ok && u != "" {
			out[u] = c
		}
	}
	return out
}

type registro struct {
	http.ResponseWriter
	code int
}

func (r *registro) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

// Flush deja pasar el vaciado del proxy, que /api/events necesita.
func (r *registro) Flush() {
	if f, ok := r.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8791", "dirección donde escuchar")
	upstream := flag.String("upstream", "http://127.0.0.1:8790", "el panel")
	ruta := flag.String("credenciales", "", "fichero con «usuario:contraseña» por línea")
	flag.Parse()
	log.SetFlags(log.Ltime)
	creds := leerCredenciales(*ruta)
	destino, err := url.Parse(*upstream)
	if err != nil {
		log.Fatal(err)
	}
	proxy := httputil.NewSingleHostReverseProxy(destino)
	proxy.FlushInterval = -1 // los eventos, en cuanto llegan
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		w.WriteHeader(http.StatusBadGateway)
	}
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rw := &registro{ResponseWriter: w, code: http.StatusOK}
		u, c, ok := r.BasicAuth()
		bien, existe := creds[u]
		if !ok || !existe || subtle.ConstantTimeCompare([]byte(c), []byte(bien)) != 1 {
			w.Header().Set("WWW-Authenticate", `Basic realm="restricted"`)
			rw.WriteHeader(http.StatusUnauthorized)
			log.Printf("%s %s → 401 (usuario %q)", r.Method, r.URL.Path, u)
			return
		}
		r.Header.Del("Authorization")
		r.Header.Set("X-Remote-User", u)
		proxy.ServeHTTP(rw, r)
		log.Printf("%s %s → %d (usuario %q)", r.Method, r.URL.Path, rw.code, u)
	})
	log.Printf("caddy-falso en %s → %s", *listen, *upstream)
	log.Fatal(http.ListenAndServe(*listen, h))
}
