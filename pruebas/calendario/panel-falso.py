#!/usr/bin/env python3
# Un panel del homelab falso para pruebas/calendario/prueba.sh: lo justo de
# /api/tareas para que bar/Tareas.qml lea, cree, mueva y cambie la prioridad o
# el 🚫🤖 de una tarea de verdad, por HTTP, sin el NUC.
#
#   panel-falso.py <fichero del puerto> <fichero de la contraseña>
#
# Escucha en 127.0.0.1, en un puerto libre que escribe en el primer fichero
# cuando ya acepta conexiones. Pide la cabecera Basic del usuario «prueba» con
# la contraseña del segundo (la misma que da el secret-tool falso de la
# prueba) y X-Panel-Request, como el de verdad; si no, 401.
#
# Para la prueba, sin credenciales:
#   GET  /__registro  lo que se le ha pedido a /api, en orden: [{ metodo,
#                     ruta, cuerpo, auth }]
#   POST /__ajustes   { retraso: ms antes de contestar a una escritura,
#                     fallos: [{ estado, error }] para las siguientes }
#
# No escribe nada en ningún log: ni los textos de las tareas ni la contraseña.
import base64
import json
import os
import re
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PRIOS = ["highest", "high", "medium", "low", "lowest"]
DIA = re.compile(r"^\d{4}-\d\d-\d\d$")
HOY = "2026-10-21"


def efectiva(prio, vence):
    # Como effectivePrio en el panel: sube la prioridad cerca de la fecha.
    if not DIA.match(vence or ""):
        return prio
    n = round((time.mktime(time.strptime(vence, "%Y-%m-%d")) - time.mktime(time.strptime(HOY, "%Y-%m-%d"))) / 86400)
    suelo = "highest" if n <= 1 else "high" if n <= 3 else "medium" if n <= 7 else ""
    rango = {p: i for i, p in enumerate(PRIOS)}
    if suelo and rango[suelo] < rango.get(prio, 5):
        return suelo
    return prio


def tarea(id, texto, vence, prio, area="", claude_off=False):
    return {"id": id, "line": 0, "done": False, "area": area, "text": texto, "priority": prio,
            "due": vence, "start": "", "scheduled": "", "doneDate": "", "effective": efectiva(prio, vence),
            "raised": "", "overdue": False, "dueToday": vence == HOY, "details": [], "subtasks": [],
            "pinned": False, "claude_off": claude_off}


cerrojo = threading.Lock()
estado = {
    "enabled": True, "path": "00 Inicio.md", "version": "v1", "today": HOY, "error": "", "areas": ["Clase"],
    # Clase va primero: una tarea creada en el calendario tiene que ir a
    # General, no a la primera sección.
    "sections": [
        {"id": "clase", "title": "Clase", "emoji": "", "tasks": [
            tarea("c1", "MIA: Tarea quinta", "2026-10-30", "", "Clase", True)]},
        {"id": "general", "title": "General", "emoji": "", "tasks": [
            tarea("g1", "Revisar el informe", "2026-10-30", "low"),
            tarea("g2", "Llamar al taller", "2026-10-22", "low")]},
        {"id": "en-pausa", "title": "En pausa", "emoji": "", "tasks": []},
    ],
}
registro = []
ajustes = {"retraso": 0, "fallos": []}
siguiente = [0]
clave = ""


def buscar(id):
    for s in estado["sections"]:
        for t in s["tasks"]:
            if t["id"] == id:
                return t
    return None


def crear(q):
    s = next((s for s in estado["sections"] if s["id"] == q.get("seccion")), None)
    if s is None:
        return 422, {"error": "Sección desconocida."}
    texto = str(q.get("texto") or "").strip()
    if not 1 <= len(texto) <= 300 or "\n" in texto:
        return 422, {"error": "El texto debe tener entre 1 y 300 caracteres, en una sola línea."}
    fecha = str(q.get("fecha") or "")
    if fecha and not DIA.match(fecha):
        return 422, {"error": "La fecha debe ser AAAA-MM-DD y existir."}
    prio = str(q.get("prioridad") or "")
    if prio and prio not in PRIOS:
        return 422, {"error": "Prioridad no válida."}
    siguiente[0] += 1
    s["tasks"].append(tarea("n%d" % siguiente[0], texto, fecha, prio, str(q.get("area") or ""), q.get("claude_off") is True))
    return 200, None


def editar(id, q):
    t = buscar(id)
    if t is None:
        return 409, {"error": "La tarea ha cambiado en tus notas; recarga."}
    if "fecha" in q:
        if q["fecha"] and not DIA.match(str(q["fecha"])):
            return 422, {"error": "La fecha debe ser AAAA-MM-DD y existir."}
        t["due"] = str(q["fecha"])
    if "prioridad" in q:
        if q["prioridad"] and q["prioridad"] not in PRIOS:
            return 422, {"error": "Prioridad no válida."}
        t["priority"] = str(q["prioridad"])
    if "claude_off" in q:
        t["claude_off"] = q["claude_off"] is True
    t["effective"] = efectiva(t["priority"], t["due"])
    t["dueToday"] = t["due"] == HOY
    return 200, None


class Manejador(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def contestar(self, codigo, cuerpo):
        datos = json.dumps(cuerpo).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    def leer(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n == 0:
            return None
        try:
            return json.loads(self.rfile.read(n))
        except ValueError:
            return None

    def autorizado(self):
        esperada = "Basic " + base64.b64encode(("prueba:" + clave).encode()).decode()
        return self.headers.get("Authorization") == esperada and self.headers.get("X-Panel-Request") == "1"

    def atender(self, metodo):
        cuerpo = self.leer() if metodo == "POST" else None
        ruta = self.path.split("?")[0]
        if ruta == "/__registro":
            with cerrojo:
                return self.contestar(200, registro)
        if ruta == "/__ajustes":
            with cerrojo:
                ajustes.update(cuerpo or {})
            return self.contestar(200, {})
        auth = self.autorizado()
        with cerrojo:
            registro.append({"metodo": metodo, "ruta": ruta, "cuerpo": cuerpo, "auth": auth})
            retraso = ajustes["retraso"] if metodo == "POST" else 0
            fallo = ajustes["fallos"].pop(0) if metodo == "POST" and ajustes["fallos"] else None
        if not auth:
            return self.contestar(401, {"error": "No autorizado"})
        if retraso:
            time.sleep(retraso / 1000)
        if fallo:
            return self.contestar(int(fallo.get("estado", 500)), {"error": fallo.get("error", "")})
        with cerrojo:
            if metodo == "GET" and ruta == "/api/tareas":
                codigo, error = 200, None
            elif metodo == "POST" and ruta == "/api/tareas":
                codigo, error = crear(cuerpo or {})
            elif metodo == "POST" and ruta.startswith("/api/tareas/"):
                codigo, error = editar(ruta[len("/api/tareas/"):], cuerpo or {})
            else:
                codigo, error = 404, {"error": "No existe"}
            if codigo == 200 and metodo == "POST":
                estado["version"] = "v%d" % (len(registro) + 1)
            respuesta = json.loads(json.dumps(estado)) if codigo == 200 else error
        self.contestar(codigo, respuesta)

    def do_GET(self):
        self.atender("GET")

    def do_POST(self):
        self.atender("POST")


def main():
    global clave
    with open(sys.argv[2]) as f:
        clave = f.read().strip()
    servidor = ThreadingHTTPServer(("127.0.0.1", 0), Manejador)
    with open(sys.argv[1] + ".tmp", "w") as f:
        f.write(str(servidor.server_address[1]))
    os.replace(sys.argv[1] + ".tmp", sys.argv[1])
    servidor.serve_forever()


if __name__ == "__main__":
    main()
