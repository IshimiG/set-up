#!/usr/bin/env python3
# Un panel del homelab falso para pruebas/calendario/prueba.sh: lo justo de
# /api/tareas para que bar/Tareas.qml lea, cree, mueva y cambie la prioridad,
# el 🚫🤖, el texto o las horas de una tarea, y la borre, de verdad, por HTTP,
# sin el NUC.
#
# Sigue el contrato del panel: cada tarea trae time_start y time_end ("HH:MM";
# "" las dos, todo el día) y color ("#rrggbb" o ""); al crear se pueden mandar
# hora_inicio, hora_fin y color, y al editar también (ausente = no se toca;
# "" = quitar). DELETE /api/tareas/{id} la borra y contesta con la lista nueva
# (409 si ya no está). Al crear va la sección en «seccion» (422 si no existe) y
# al editar «seccion» mueve la tarea a otra (422 si no existe). Cada sección trae su color ("#rrggbb" o ""). Las horas van siempre en pareja y el fin después del inicio;
# si no, 422 con el motivo. Nada se aplica si algo del cuerpo no vale.
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
#                     fallos: [{ estado, error }] para las siguientes,
#                     secciones: [[id, título, color]] las secciones que hay
#                     entre General y En pausa (las tareas de las que se
#                     quitan pasan a General), mover: { id de tarea: id de
#                     sección } }
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
HORA = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")
COLOR = re.compile(r"^#[0-9a-f]{6}$")
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


def tarea(id, texto, vence, prio, area="", claude_off=False, inicio="", fin="", color=""):
    return {"id": id, "line": 0, "done": False, "area": area, "text": texto, "priority": prio,
            "due": vence, "start": "", "scheduled": "", "doneDate": "", "effective": efectiva(prio, vence),
            "raised": "", "overdue": False, "dueToday": vence == HOY, "details": [], "subtasks": [],
            "pinned": False, "claude_off": claude_off, "time_start": inicio, "time_end": fin, "color": color}


def mal_texto(q):
    texto = str(q.get("texto") or "").strip()
    if not 1 <= len(texto) <= 300 or "\n" in texto:
        return "El texto debe tener entre 1 y 300 caracteres, en una sola línea."
    return None


def norm_hora(h):
    # "H:MM" o "HH:MM" a "HH:MM", como normHora en el panel; None si no vale.
    m = re.match(r"^(\d{1,2}):(\d\d)$", h.strip())
    if not m or int(m.group(1)) > 23 or int(m.group(2)) > 59:
        return None
    return "%02d:%s" % (int(m.group(1)), m.group(2))


def horas(q):
    # Las dos o ninguna; las dos "" es todo el día. (motivo, inicio, fin),
    # con los mismos mensajes que el panel.
    if "hora_inicio" not in q and "hora_fin" not in q:
        return None, None, None
    inicio, fin = str(q.get("hora_inicio") or "").strip(), str(q.get("hora_fin") or "").strip()
    if "hora_inicio" not in q or "hora_fin" not in q or (inicio == "") != (fin == ""):
        return "La hora de inicio y la de fin van juntas: las dos, o ninguna para todo el día.", None, None
    if inicio == "":
        return None, "", ""
    a, b = norm_hora(inicio), norm_hora(fin)
    if a is None or b is None:
        return "La hora debe ser HH:MM, de 00:00 a 23:59.", None, None
    if b <= a:
        return "La hora de fin debe ser posterior a la de inicio.", None, None
    return None, a, b


def mal_horas(q):
    return horas(q)[0]


def mal_color(q):
    # Como validColor en el panel: cualquier caja, y se guarda en minúsculas.
    if "color" in q and str(q["color"]).strip() != "" and not COLOR.match(str(q["color"]).strip().lower()):
        return "El color debe ser #rrggbb."
    return None


cerrojo = threading.Lock()
estado = {
    "enabled": True, "path": "00 Inicio.md", "version": "v1", "today": HOY, "error": "", "areas": ["Clase"],
    # Clase va primero: una tarea creada en el calendario tiene que ir a
    # General, no a la primera sección.
    "sections": [
        {"id": "clase", "title": "Clase", "emoji": "", "color": "", "tasks": [
            tarea("c1", "MIA: Tarea quinta", "2026-10-30", "", "Clase", True)]},
        {"id": "general", "title": "General", "emoji": "", "color": "#e67c73", "tasks": [
            tarea("g1", "Revisar el informe", "2026-10-30", "low"),
            tarea("g2", "Llamar al taller", "2026-10-22", "low"),
            # Con hora; el color suelto de la tarea ya no lo usa la barra.
            tarea("g3", "Tutoría de **FOL**", "2026-10-30", "high", "", False, "16:00", "17:00", "#039be5")]},
        # Proyectos con su color: los de la hoja del calendario («Categoría»).
        {"id": "homelab", "title": "Homelab", "emoji": "", "color": "#33b679", "tasks": []},
        {"id": "tfg", "title": "Proyecto de fin de ciclo", "emoji": "", "color": "#8e24aa", "tasks": []},
        {"id": "en-pausa", "title": "En pausa", "emoji": "", "color": "", "tasks": []},
    ],
}
registro = []
ajustes = {"retraso": 0, "fallos": []}
siguiente = [0]
clave = ""


def poner_secciones(lista):
    """Las secciones de entre General y En pausa pasan a ser `lista`."""
    if lista is None:
        return
    fijas = ("clase", "general", "en-pausa")
    general = next(s for s in estado["sections"] if s["id"] == "general")
    previas = {s["id"]: s for s in estado["sections"] if s["id"] not in fijas}
    nuevas = []
    for id, titulo, color in lista:
        s = previas.pop(id, None) or {"id": id, "title": titulo, "emoji": "", "color": color, "tasks": []}
        s["title"], s["color"] = titulo, color
        nuevas.append(s)
    for s in previas.values():
        general["tasks"].extend(s["tasks"])
    clase, pausa = estado["sections"][0], estado["sections"][-1]
    estado["sections"] = [clase, general] + nuevas + [pausa]


def mover(q):
    """Lleva cada tarea de `q` a su sección, sin pasar por la API."""
    for id, destino in (q or {}).items():
        t = buscar(id)
        d = next((s for s in estado["sections"] if s["id"] == destino), None)
        if t is None or d is None:
            continue
        for s in estado["sections"]:
            if t in s["tasks"]:
                s["tasks"].remove(t)
        d["tasks"].append(t)


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
    fecha = str(q.get("fecha") or "")
    prio = str(q.get("prioridad") or "")
    motivo = (mal_texto(q) or ("La fecha debe ser AAAA-MM-DD y existir." if fecha and not DIA.match(fecha) else None)
              or ("Prioridad no válida." if prio and prio not in PRIOS else None) or mal_horas(q) or mal_color(q))
    if motivo:
        return 422, {"error": motivo}
    siguiente[0] += 1
    _, inicio, fin = horas(q)
    s["tasks"].append(tarea("n%d" % siguiente[0], str(q["texto"]).strip(), fecha, prio, str(q.get("area") or ""),
                            q.get("claude_off") is True, inicio or "", fin or "", str(q.get("color") or "").strip().lower()))
    return 200, None


def editar(id, q):
    t = buscar(id)
    if t is None:
        return 409, {"error": "La tarea ha cambiado en tus notas; recarga."}
    destino = None
    if "seccion" in q:
        destino = next((s for s in estado["sections"] if s["id"] == q["seccion"]), None)
        if destino is None:
            return 422, {"error": "Sección desconocida."}
    motivo = ((mal_texto(q) if "texto" in q else None)
              or ("La fecha debe ser AAAA-MM-DD y existir." if q.get("fecha") and not DIA.match(str(q["fecha"])) else None)
              or ("Prioridad no válida." if q.get("prioridad") and q["prioridad"] not in PRIOS else None)
              or mal_horas(q) or mal_color(q))
    if motivo:
        return 422, {"error": motivo}
    if "texto" in q:
        t["text"] = str(q["texto"]).strip()
    if "fecha" in q:
        t["due"] = str(q["fecha"])
    if "prioridad" in q:
        t["priority"] = str(q["prioridad"])
    if "claude_off" in q:
        t["claude_off"] = q["claude_off"] is True
    if "hora_inicio" in q:
        _, t["time_start"], t["time_end"] = horas(q)
    if "color" in q:
        t["color"] = str(q["color"]).strip().lower()
    if destino is not None:
        for s in estado["sections"]:
            if t in s["tasks"]:
                s["tasks"].remove(t)
        destino["tasks"].append(t)
    t["effective"] = efectiva(t["priority"], t["due"])
    t["dueToday"] = t["due"] == HOY
    return 200, None


def borrar(id):
    for s in estado["sections"]:
        for t in s["tasks"]:
            if t["id"] == id:
                s["tasks"].remove(t)
                return 200, None
    return 409, {"error": "La tarea ha cambiado en tus notas; recarga."}


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
                cuerpo = dict(cuerpo or {})
                poner_secciones(cuerpo.pop("secciones", None))
                mover(cuerpo.pop("mover", None))
                ajustes.update(cuerpo)
            return self.contestar(200, {})
        auth = self.autorizado()
        with cerrojo:
            registro.append({"metodo": metodo, "ruta": ruta, "cuerpo": cuerpo, "auth": auth})
            escribe = metodo in ("POST", "DELETE")
            retraso = ajustes["retraso"] if escribe else 0
            fallo = ajustes["fallos"].pop(0) if escribe and ajustes["fallos"] else None
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
            elif metodo == "DELETE" and ruta.startswith("/api/tareas/"):
                codigo, error = borrar(ruta[len("/api/tareas/"):])
            else:
                codigo, error = 404, {"error": "No existe"}
            if codigo == 200 and metodo != "GET":
                estado["version"] = "v%d" % (len(registro) + 1)
            respuesta = json.loads(json.dumps(estado)) if codigo == 200 else error
        self.contestar(codigo, respuesta)

    def do_GET(self):
        self.atender("GET")

    def do_POST(self):
        self.atender("POST")

    def do_DELETE(self):
        self.atender("DELETE")


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
