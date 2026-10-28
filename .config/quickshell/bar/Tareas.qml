import QtQuick
import Quickshell
import Quickshell.Io
import "shared/AgendaFormato.js" as Formato

// El cliente mínimo del panel del NUC para el calendario: lee las tareas con
// fecha (GET /api/tareas), crea una para un día (POST /api/tareas) y cambia
// una de día, de prioridad o su 🚫🤖 «Claude no la hace» (POST
// /api/tareas/{id} con { fecha }, { prioridad } o { claude_off }). Es el
// equivalente reducido de lo que hace homelab/Api.qml, que es otro proceso de
// qs y no se comparte: el cajón sigue siendo quien escribe el fichero de la
// agenda, y esto solo se usa mientras el calendario está abierto.
//
// Las credenciales, como en el cajón: el usuario de Caddy sale del llavero
// («secret-tool search servicio homelab-panel»), la contraseña se lee una vez
// con «secret-tool lookup» y se queda en memoria; va solo en la cabecera
// Authorization y nunca a un log. HOMELAB_PANEL_URL cambia la dirección (las
// pruebas).
//
// Sin sondeo: se lee al abrir el calendario (refrescar()), si lo que hay tiene
// más de frescoMs, y después de cada escritura, que ya contesta con el estado
// nuevo. Mover, la prioridad y el 🚫🤖 son optimistas: la vista cambia al
// momento y, si el POST falla, se revierte a lo anterior. Crear no: la tarea
// sale cuando el panel la ha escrito, que es cuando tiene id (y se puede
// mover).
//
// datos tiene el mismo formato que bar/Agenda.qml (shared/AgendaFormato.js, con
// el id de cada evento) y dos campos más en cada evento, que el fichero no
// lleva: claudeOff y prioridadPropia (abajo, en agendaDe); null mientras no se
// haya podido leer nada.
Scope {
    id: cli

    readonly property var datos: p.datos
    // "inactivo", "conectando", "conectado", "sin-conexion", "sin-credenciales"
    // o "no-autorizado".
    readonly property string estado: p.estado
    readonly property bool escribiendo: p.escribiendo
    // Se puede escribir (crear, mover, la prioridad, el 🚫🤖): hay datos del
    // panel y conexión, y no hay otra escritura a medias.
    readonly property bool puedeEscribir: p.estado === "conectado" && p.datos !== null && !p.escribiendo
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

    // El orden de las prioridades en el panel (PrioRank del repo homelab): 0
    // la más alta; sin prioridad, la última.
    readonly property var rangoPrio: ({
            highest: 0,
            high: 1,
            medium: 2,
            low: 3,
            lowest: 4
        })

    // La prioridad de hoy, como la calcula el panel (effectivePrio, en el repo
    // homelab): la propia, subida a máxima si vence en un día o menos, a alta
    // si en tres y a media si en siete. Solo sirve para que el punto no cambie
    // dos veces al elegir una prioridad; la buena llega con la respuesta.
    function efectiva(prio, vence, hoy) {
        const d = Formato.fechaDe(vence);
        const h = Formato.fechaDe(hoy);
        if (!d || !h)
            return prio;
        const n = Math.round((d - h) / 86400000);
        const suelo = n <= 1 ? "highest" : n <= 3 ? "high" : n <= 7 ? "medium" : "";
        return suelo !== "" && cli.rangoPrio[suelo] < (cli.rangoPrio[prio] ?? 5) ? suelo : prio;
    }

    function plano(texto) {
        return String(texto || "").replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_, a, b) => (b || a.split("#")[0].split("/").pop()).trim()).replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, "$1").replace(/\*\*|~~|`/g, "");
    }

    // De la respuesta de /api/tareas a la agenda del calendario. Cada evento
    // con id lleva además lo que el calendario necesita para editarlo y el
    // fichero de la agenda no lleva (shared/AgendaFormato.js lo quitaría al
    // leerlo): claudeOff, el 🚫🤖 «Claude no la hace», y prioridadPropia, la
    // que tiene puesta ("maxima".."minima" o ""), que puede no ser la del
    // punto: esa es la de hoy, que el panel sube cerca de la fecha.
    function agendaDe(d, conectado) {
        if (!d || typeof d !== "object")
            return null;
        const hoy = String(d.today || "").slice(0, 10);
        const propias = {};
        const secciones = (d.sections || []).map(s => ({
                    id: String(s.id),
                    titulo: String(s.title || ""),
                    color: s.color || "",
                    pausa: s.id === "en-pausa",
                    tareas: (s.tasks || []).map(t => {
                        const vence = String(t.due || "").slice(0, 10);
                        const hecha = !!t.done;
                        if (t.id)
                            propias[String(t.id)] = {
                                claudeOff: t.claude_off === true,
                                prioridad: cli.nombrePrio[t.priority] || ""
                            };
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
        const agenda = a ? Formato.leer(JSON.stringify(a)) : null;
        // porDia lleva los mismos objetos que eventos: basta con ponerlo aquí.
        for (const e of agenda ? agenda.eventos : []) {
            const x = propias[e.id];
            e.claudeOff = !!x && x.claudeOff;
            e.prioridadPropia = x ? x.prioridad : "";
        }
        return agenda;
    }

    // La sección en la que entra una tarea creada desde el calendario: la
    // misma que el cajón cuando no se elige (General, o la primera que no
    // esté en pausa).
    function seccionPorDefecto() {
        const ss = (p.crudas && p.crudas.sections) || [];
        const s = ss.find(x => x.id === "general") || ss.find(x => x.id !== "en-pausa") || ss[0];
        return s ? String(s.id) : "";
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

    // Mueve la tarea `id` al día `dia` ("2026-10-22"). Optimista, como las
    // dos de abajo: cambia la vista al momento y la revierte si el POST falla.
    // alAcabar(ok) al terminar.
    function mover(id, dia, alAcabar) {
        if (!/^\d{4}-\d\d-\d\d$/.test(dia)) {
            if (alAcabar)
                alAcabar(false);
            return;
        }
        cli.editar(id, {
            fecha: dia
        }, t => {
            t.due = dia;
        }, "No se pudo mover la tarea", alAcabar);
    }

    // Pone a la tarea `id` la prioridad `valor` (la del panel: "highest",
    // "high", "medium", "low" o "lowest").
    function prioridad(id, valor, alAcabar) {
        if (!(valor in cli.rangoPrio)) {
            if (alAcabar)
                alAcabar(false);
            return;
        }
        const hoy = String((p.crudas && p.crudas.today) || "").slice(0, 10);
        cli.editar(id, {
            prioridad: valor
        }, t => {
            t.priority = valor;
            t.effective = cli.efectiva(valor, String(t.due || "").slice(0, 10), hoy);
        }, "No se pudo cambiar la prioridad", alAcabar);
    }

    // Enciende o apaga el 🚫🤖 «Claude no la hace» de la tarea `id`.
    function claudeOff(id, activo, alAcabar) {
        cli.editar(id, {
            claude_off: !!activo
        }, t => {
            t.claude_off = !!activo;
        }, "No se pudo cambiar «Claude no la hace»", alAcabar);
    }

    // Crea una tarea con el texto `texto` para el día `dia`, en la sección de
    // siempre (seccionPorDefecto), sin área, con prioridad media y sin 🚫🤖.
    // No es optimista: la tarea aparece cuando el panel contesta con la lista
    // nueva, que ya la lleva con su id. alAcabar(ok) al terminar.
    function crear(texto, dia, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        const limpio = String(texto || "").replace(/\s+/g, " ").trim();
        const seccion = cli.seccionPorDefecto();
        if (!cli.puedeEscribir || limpio === "" || !/^\d{4}-\d\d-\d\d$/.test(dia) || seccion === "") {
            fin(false);
            return;
        }
        p.error = "";
        p.escribiendo = true;
        cli.pedir("POST", "/api/tareas", {
            seccion: seccion,
            texto: limpio,
            area: "",
            fecha: dia,
            prioridad: "medium",
            claude_off: false
        }, (estado, respuesta) => {
            p.escribiendo = false;
            if (cli.aceptada(estado, respuesta)) {
                fin(true);
                return;
            }
            cli.rechazada(estado, respuesta, "No se pudo crear la tarea");
            fin(false);
        });
    }

    // Lo común de mover, la prioridad y el 🚫🤖: cambia la tarea `id` en una
    // copia de lo último leído con aplicar(t) (sobre la tarea tal como la
    // devuelve el panel), la enseña, y manda `cuerpo` a POST /api/tareas/{id}.
    // Si falla, vuelve lo anterior y `que` dice qué no se pudo hacer.
    function editar(id, cuerpo, aplicar, que, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        if (!cli.puedeEscribir || !id) {
            fin(false);
            return;
        }
        const antes = p.crudas;
        const nuevas = JSON.parse(JSON.stringify(antes));
        let hallada = false;
        for (const s of nuevas.sections || [])
            for (const t of s.tasks || [])
                if (String(t.id) === id) {
                    aplicar(t);
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
        cli.pedir("POST", "/api/tareas/" + encodeURIComponent(id), cuerpo, (estado, texto) => {
            p.escribiendo = false;
            if (cli.aceptada(estado, texto)) {
                fin(true);
                return;
            }
            // Fallo: vuelve lo anterior, si no ha llegado nada más nuevo.
            if (sec === p.sec)
                cli.poner(antes, estado !== 0);
            cli.rechazada(estado, texto, que);
            fin(false);
        });
    }

    // La respuesta de una escritura que fue bien trae la lista nueva: se
    // pone (y lo que se estuviera leyendo antes ya no vale). true si fue así.
    function aceptada(estado, texto) {
        const d = cli.leerJSON(estado, texto);
        if (estado !== 200 || !d)
            return false;
        p.sec++;
        p.cargadas = Date.now();
        p.estado = "conectado";
        cli.poner(d, true);
        return true;
    }

    // Por qué no se pudo escribir, en error. Si la nota cambió por debajo
    // (409), se relee; si el panel lo rechaza con un motivo (un texto de más
    // de 300 caracteres, una fecha que no existe…), se dice el suyo, que ya
    // va en español y nunca lleva el texto de una tarea.
    function rechazada(estado, texto, que) {
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
            let motivo = "";
            try {
                motivo = String(JSON.parse(texto).error || "");
            } catch (e) {}
            p.error = estado >= 400 && estado < 500 && motivo !== "" ? motivo.slice(0, 160) : que + " (HTTP " + estado + ")";
        }
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
