import QtQuick
import Quickshell
import Quickshell.Io
import "shared/AgendaFormato.js" as Formato

// El cliente mínimo del panel del NUC para el calendario: lee las tareas con
// fecha (GET /api/tareas) y mueve una de día (POST /api/tareas/{id} con
// { fecha }). Es el equivalente reducido de lo que hace homelab/Api.qml, que es
// otro proceso de qs y no se comparte: el cajón sigue siendo quien escribe el
// fichero de la agenda, y esto solo se usa mientras el calendario está abierto.
//
// Las credenciales, como en el cajón: el usuario de Caddy sale del llavero
// («secret-tool search servicio homelab-panel»), la contraseña se lee una vez
// con «secret-tool lookup» y se queda en memoria; va solo en la cabecera
// Authorization y nunca a un log. HOMELAB_PANEL_URL cambia la dirección (las
// pruebas).
//
// Sin sondeo: se lee al abrir el calendario (refrescar()), si lo que hay tiene
// más de frescoMs, y después de cada escritura, que ya contesta con el estado
// nuevo. Mover es optimista: la vista cambia al soltar y, si el POST falla, se
// revierte a lo anterior.
//
// datos tiene el mismo formato que bar/Agenda.qml (shared/AgendaFormato.js, con
// el id de cada evento); null mientras no se haya podido leer nada.
Scope {
    id: cli

    readonly property var datos: p.datos
    // "inactivo", "conectando", "conectado", "sin-conexion", "sin-credenciales"
    // o "no-autorizado".
    readonly property string estado: p.estado
    readonly property bool escribiendo: p.escribiendo
    // Se puede mover una tarea: hay datos del panel y conexión.
    readonly property bool puedeMover: p.estado === "conectado" && p.datos !== null && !p.escribiendo
    // Lo último que salió mal al escribir, o "".
    readonly property string error: p.error

    property string baseUrl: (Quickshell.env("HOMELAB_PANEL_URL") || "https://panel.lab.ishimi.es").replace(/\/+$/, "")
    property int esperaPeticion: 10000
    property int frescoMs: 30000

    QtObject {
        id: p
        property string usuario: ""
        property string clave: ""
        property bool leyendo: false
        property string estado: "inactivo"
        property var crudas: null
        property var datos: null
        property bool escribiendo: false
        property double cargadas: 0
        property int sec: 0
        property string error: ""
    }

    readonly property var nombrePrio: ({
            highest: "maxima",
            high: "alta",
            medium: "media",
            low: "baja",
            lowest: "minima"
        })

    function plano(texto) {
        return String(texto || "").replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_, a, b) => (b || a.split("#")[0].split("/").pop()).trim()).replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, "$1").replace(/\*\*|~~|`/g, "");
    }

    // De la respuesta de /api/tareas a la agenda del calendario.
    function agendaDe(d, conectado) {
        if (!d || typeof d !== "object")
            return null;
        const hoy = String(d.today || "").slice(0, 10);
        const secciones = (d.sections || []).map(s => ({
                    id: String(s.id),
                    titulo: String(s.title || ""),
                    color: s.color || "",
                    pausa: s.id === "en-pausa",
                    tareas: (s.tasks || []).map(t => {
                        const vence = String(t.due || "").slice(0, 10);
                        const hecha = !!t.done;
                        return {
                            id: String(t.id || ""),
                            vence: vence,
                            plano: cli.plano(t.text),
                            texto: String(t.text || ""),
                            hecha: hecha,
                            vencida: !hecha && vence !== "" && hoy !== "" && vence < hoy,
                            prioridad: cli.nombrePrio[t.priority] || "",
                            efectiva: cli.nombrePrio[t.effective] || "",
                            area: String(t.area || "")
                        };
                    })
                }));
        const a = Formato.deTareas({
            habilitado: d.enabled !== false,
            secciones: secciones
        }, conectado, new Date());
        return a ? Formato.leer(JSON.stringify(a)) : null;
    }

    function poner(crudas, conectado) {
        p.crudas = crudas;
        p.datos = cli.agendaDe(crudas, conectado);
    }

    // --- Credenciales --------------------------------------------------------

    function refrescar(forzar) {
        if (p.leyendo || p.escribiendo)
            return;
        if (!forzar && p.estado === "conectado" && Date.now() - p.cargadas < cli.frescoMs)
            return;
        if (p.clave !== "") {
            cli.cargar();
            return;
        }
        p.leyendo = true;
        p.estado = "conectando";
        // La salida normal de «search» lleva la contraseña: se tira. Los
        // atributos salen por la de errores.
        cli.ejecutar(["sh", "-c", "secret-tool search servicio homelab-panel 2>&1 >/dev/null"], (codigo, texto) => {
            const m = /^attribute\.usuario = (.+)$/m.exec(texto);
            if (codigo !== 0 || !m) {
                p.leyendo = false;
                p.estado = "sin-credenciales";
                return;
            }
            const usuario = m[1].trim();
            cli.ejecutar(["secret-tool", "lookup", "servicio", "homelab-panel", "usuario", usuario], (codigo2, clave) => {
                p.leyendo = false;
                clave = clave.replace(/\r?\n$/, "");
                if (codigo2 !== 0 || clave === "") {
                    p.estado = "sin-credenciales";
                    return;
                }
                p.usuario = usuario;
                p.clave = clave;
                cli.cargar();
            });
        });
    }

    // --- Peticiones ----------------------------------------------------------

    function cargar() {
        const sec = ++p.sec;
        cli.pedir("GET", "/api/tareas", undefined, (estado, texto) => {
            if (sec !== p.sec)
                return;
            if (estado === 401) {
                cli.noAutorizado();
                return;
            }
            const d = cli.leerJSON(estado, texto);
            if (!d) {
                p.estado = "sin-conexion";
                // Lo que hubiera se queda, marcado como posiblemente viejo.
                if (p.crudas)
                    p.datos = cli.agendaDe(p.crudas, false);
                return;
            }
            p.estado = "conectado";
            p.cargadas = Date.now();
            cli.poner(d, true);
        });
    }

    function noAutorizado() {
        p.estado = "no-autorizado";
        p.clave = "";
        p.usuario = "";
    }

    // Mueve la tarea `id` al día `dia` ("2026-10-22"). Cambia la vista al
    // momento y la revierte si el POST falla. alAcabar(ok) al terminar.
    function mover(id, dia, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        if (!cli.puedeMover || id === "" || !/^\d{4}-\d\d-\d\d$/.test(dia)) {
            fin(false);
            return;
        }
        const antes = p.crudas;
        const nuevas = JSON.parse(JSON.stringify(antes));
        let hallada = false;
        for (const s of nuevas.sections || [])
            for (const t of s.tasks || [])
                if (String(t.id) === id) {
                    t.due = dia;
                    hallada = true;
                }
        if (!hallada) {
            fin(false);
            return;
        }
        p.error = "";
        p.escribiendo = true;
        const sec = ++p.sec;
        cli.poner(nuevas, true);
        cli.pedir("POST", "/api/tareas/" + encodeURIComponent(id), {
            fecha: dia
        }, (estado, texto) => {
            p.escribiendo = false;
            const d = cli.leerJSON(estado === 409 ? 200 : estado, texto);
            if (estado === 200 && d) {
                p.sec++;
                p.cargadas = Date.now();
                p.estado = "conectado";
                cli.poner(d, true);
                fin(true);
                return;
            }
            // Fallo: vuelve lo anterior.
            if (sec === p.sec)
                cli.poner(antes, estado !== 0);
            if (estado === 401) {
                cli.noAutorizado();
                p.error = "El panel no acepta las credenciales";
            } else if (estado === 409) {
                p.error = "La nota cambió; he recargado las tareas";
                cli.cargar();
            } else if (estado === 0) {
                p.estado = "sin-conexion";
                p.error = "El NUC no contesta";
            } else {
                p.error = "No se pudo mover la tarea (HTTP " + estado + ")";
            }
            fin(false);
        });
    }

    function leerJSON(estado, texto) {
        if (estado !== 200)
            return null;
        try {
            return JSON.parse(texto);
        } catch (e) {
            return null;
        }
    }

    function pedir(metodo, ruta, cuerpo, alAcabar) {
        const xhr = new XMLHttpRequest();
        const reloj = relojes.createObject(cli, {
            interval: cli.esperaPeticion
        });
        let hecha = false;
        const acabar = (estado, texto) => {
            if (hecha)
                return;
            hecha = true;
            reloj.destroy();
            alAcabar(estado, texto);
        };
        // El XMLHttpRequest de QML no tiene tiempo máximo.
        reloj.triggered.connect(() => {
            acabar(0, "");
            xhr.abort();
        });
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                acabar(xhr.status, xhr.responseText);
        };
        xhr.open(metodo, cli.baseUrl + ruta);
        xhr.setRequestHeader("Authorization", "Basic " + cli.base64(p.usuario + ":" + p.clave));
        xhr.setRequestHeader("X-Panel-Request", "1");
        xhr.setRequestHeader("Accept", "application/json");
        if (cuerpo === undefined) {
            xhr.send();
        } else {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(cuerpo));
        }
    }

    Component {
        id: relojes
        Timer {
            running: true
        }
    }

    // Base64 de los bytes UTF-8, para la cabecera Basic (Qt.btoa con texto está
    // obsoleto en Qt 6.11).
    function base64(texto) {
        const b = [];
        for (const ch of texto) {
            const c = ch.codePointAt(0);
            if (c < 0x80)
                b.push(c);
            else if (c < 0x800)
                b.push(0xc0 | c >> 6, 0x80 | c & 63);
            else if (c < 0x10000)
                b.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63);
            else
                b.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63);
        }
        const t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let s = "";
        for (let i = 0; i < b.length; i += 3) {
            const n = b[i] << 16 | (b[i + 1] || 0) << 8 | (b[i + 2] || 0);
            s += t[n >> 18 & 63] + t[n >> 12 & 63] + (i + 1 < b.length ? t[n >> 6 & 63] : "=") + (i + 2 < b.length ? t[n & 63] : "=");
        }
        return s;
    }

    // --- Órdenes de una vez (secret-tool) ---------------------------------------
    Component {
        id: ordenes
        Process {
            id: orden
            signal leida(string texto)
            stdout: StdioCollector {
                onStreamFinished: orden.leida(this.text)
            }
        }
    }

    function ejecutar(comando, alAcabar) {
        const o = ordenes.createObject(cli, {
            command: comando
        });
        let codigo = -1, leida = false, hecha = false, texto = "";
        const acabar = () => {
            if (hecha || codigo < 0 || !leida)
                return;
            hecha = true;
            alAcabar(codigo, texto);
            o.destroy();
        };
        o.leida.connect(t => {
            texto = t;
            leida = true;
            acabar();
        });
        o.exited.connect(c => {
            codigo = c;
            acabar();
        });
        // Si no llega a arrancar (no está secret-tool), no hay «exited».
        o.runningChanged.connect(() => {
            if (!o.running)
                Qt.callLater(() => {
                    if (!hecha && codigo < 0) {
                        codigo = 127;
                        leida = true;
                        acabar();
                    }
                });
        });
        o.running = true;
    }
}
