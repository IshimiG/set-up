import QtQuick
import Quickshell
import Quickshell.Io
import "shared/AgendaFormato.js" as Formato

// El cliente mínimo del panel del NUC para el calendario: lee las tareas con
// fecha (GET /api/tareas), crea una para un día (POST /api/tareas, con sus
// horas si las tiene y en la sección que se elija) y cambia una de día, de
// prioridad o su 🚫🤖 «Claude no la hace» (POST /api/tareas/{id} con
// { fecha }, { prioridad } o { claude_off }), la borra (DELETE
// /api/tareas/{id}) o lo que se haya tocado en la hoja de editarla (cambiar():
// el texto, las horas, la prioridad, el 🚫🤖 y la categoría, que es la
// sección: { seccion }, y la pasa a otra). Es el equivalente
// reducido de lo que hace homelab/Api.qml, que es otro proceso de qs y no se
// comparte: el cajón sigue siendo quien escribe el fichero de la agenda, y
// esto solo se usa mientras el calendario está abierto.
//
// Las credenciales, como en el cajón: el usuario de Caddy sale del llavero
// («secret-tool search servicio homelab-panel»), la contraseña se lee una vez
// con «secret-tool lookup» y se queda en memoria; va solo en la cabecera
// Authorization y nunca a un log. HOMELAB_PANEL_URL cambia la dirección (las
// pruebas).
//
// Sin sondeo: se lee al abrir el calendario (refrescar()), si lo que hay tiene
// más de frescoMs, y después de cada escritura, que ya contesta con el estado
// nuevo. Mover, la prioridad, el 🚫🤖 y editar en la hoja son optimistas: la
// vista cambia al momento y, si el POST falla, se revierte a lo anterior.
// Crear no: la tarea
// sale cuando el panel la ha escrito, que es cuando tiene id (y se puede
// mover).
//
// datos tiene el mismo formato que bar/Agenda.qml (shared/AgendaFormato.js, con
// el id de cada evento, sus horas) y cuatro campos más en cada
// evento, que el fichero no lleva: claudeOff, prioridadPropia, texto y
// seccionId (abajo, en agendaDe); null mientras no se haya podido leer nada.
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
    // Las categorías que se pueden elegir en la hoja, en el orden del panel:
    // { id, nombre, color ("#rrggbb" o "") }. No salen «Clase» (las entregas
    // de Aules, que son de solo lectura y que el panel rellena solo) ni «En
    // pausa» (la tarea se iría del calendario y de la isla, que no la cuenta).
    readonly property var categorias: cli.categoriasDe(p.crudas)

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

    function categoriasDe(crudas) {
        return ((crudas && crudas.sections) || []).filter(s => s.id !== "clase" && s.id !== "en-pausa").map(s => ({
                    id: String(s.id),
                    nombre: String(s.title || s.id),
                    color: /^#[0-9a-fA-F]{6}$/.test(s.color || "") ? s.color : ""
                }));
    }

    function plano(texto) {
        return String(texto || "").replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_, a, b) => (b || a.split("#")[0].split("/").pop()).trim()).replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, "$1").replace(/\*\*|~~|`/g, "");
    }

    // De la respuesta de /api/tareas a la agenda del calendario. Las horas
    // (time_start y time_end) de cada tarea pasan por
    // AgendaFormato.deTareas como horaInicio y horaFin. Cada
    // evento con id lleva además lo que el calendario necesita para editarlo y
    // el fichero de la agenda no lleva (shared/AgendaFormato.js lo quitaría al
    // leerlo): claudeOff, el 🚫🤖 «Claude no la hace»; prioridadPropia, la que
    // tiene puesta ("maxima".."minima" o ""), que puede no ser la del punto:
    // esa es la de hoy, que el panel sube cerca de la fecha; y texto, el de la
    // nota tal cual, con su Markdown, que es lo que se edita en la hoja (el
    // título va sin él); y seccionId, el id de su sección (la categoría).
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
                                prioridad: cli.nombrePrio[t.priority] || "",
                                texto: String(t.text || ""),
                                seccion: String(s.id)
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
                            area: String(t.area || ""),
                            horaInicio: String(t.time_start || ""),
                            horaFin: String(t.time_end || "")
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
            e.texto = x ? x.texto : e.titulo;
            e.seccionId = x ? x.seccion : "";
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
        cli.ejecutar(["sh", "-c", "secret-tool search --all servicio homelab-panel 2>&1 >/dev/null"], (codigo, texto) => {
            // Como el cajón (Api.qml): HOMELAB_PANEL_USUARIO si está, después
            // los de cada equipo, y «movil» (el del móvil, sin permisos aquí) el último.
            const fijado = Quickshell.env("HOMELAB_PANEL_USUARIO") || "";
            const rango = u => u === fijado ? 0 : (u === "movil" ? 2 : 1);
            const usuarios = [];
            const re = /^attribute\.usuario = (.+)$/gm;
            let m;
            while ((m = re.exec(texto)) !== null)
                usuarios.push(m[1].trim());
            usuarios.sort((a, b) => rango(a) - rango(b));
            if (codigo !== 0 || usuarios.length === 0) {
                p.leyendo = false;
                p.estado = "sin-credenciales";
                return;
            }
            const usuario = usuarios[0];
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

    // Por qué no se puede mandar un cuerpo de POST (con los nombres del panel:
    // texto, prioridad, hora_inicio, hora_fin y seccion), o "". Lo mismo que
    // rechazaría el panel; la hoja del calendario ya no deja llegar aquí nada
    // de esto, pero el cliente no se fía.
    function motivoDe(cuerpo) {
        if ("texto" in cuerpo && (cuerpo.texto === "" || cuerpo.texto.length > 300))
            return "El texto debe tener entre 1 y 300 caracteres";
        if ("prioridad" in cuerpo && cuerpo.prioridad !== "" && !(cuerpo.prioridad in cli.rangoPrio))
            return "Prioridad no válida";
        if ("seccion" in cuerpo && !((p.crudas && p.crudas.sections) || []).some(s => String(s.id) === cuerpo.seccion))
            return "Categoría no válida";
        if ("hora_inicio" in cuerpo || "hora_fin" in cuerpo) {
            const m = Formato.motivoHoras(cuerpo.hora_inicio, cuerpo.hora_fin);
            if (m !== "")
                return m;
        }
        return "";
    }

    // Crea una tarea para un día, en la sección que se diga o, si no, la de
    // siempre (seccionPorDefecto), y sin área. `d`: { texto, dia
    // ("2026-10-30") y, si se quiere, seccion (el id), prioridad (la del panel; media si no se dice, "" sin ninguna), claudeOff
    // (apagado si no se dice), horaInicio y horaFin ("HH:MM", las dos o
    // ninguna: todo el día) }. Las horas solo van en el cuerpo si las hay. No es optimista:
    // la tarea aparece cuando el panel contesta con la lista nueva, que ya la
    // lleva con su id. alAcabar(ok) al terminar; si no, error dice por qué.
    function crear(d, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        d = d || {};
        const dia = String(d.dia || "");
        const seccion = d.seccion === undefined ? cli.seccionPorDefecto() : String(d.seccion || "");
        const cuerpo = {
            seccion: seccion,
            texto: String(d.texto || "").replace(/\s+/g, " ").trim(),
            area: "",
            fecha: dia,
            prioridad: d.prioridad === undefined ? "medium" : String(d.prioridad || ""),
            claude_off: d.claudeOff === true
        };
        const inicio = String(d.horaInicio || "");
        const final = String(d.horaFin || "");
        if (inicio !== "" || final !== "") {
            cuerpo.hora_inicio = inicio;
            cuerpo.hora_fin = final;
        }
        // Sin ninguna sección no hay nada que decir: no se manda y ya.
        const motivo = seccion === "" ? "" : cli.motivoDe(cuerpo);
        if (!cli.puedeEscribir || motivo !== "" || !/^\d{4}-\d\d-\d\d$/.test(dia) || seccion === "") {
            if (motivo !== "")
                p.error = motivo;
            fin(false);
            return;
        }
        p.error = "";
        p.escribiendo = true;
        cli.pedir("POST", "/api/tareas", cuerpo, (estado, respuesta) => {
            p.escribiendo = false;
            if (cli.aceptada(estado, respuesta)) {
                fin(true);
                return;
            }
            cli.rechazada(estado, respuesta, "No se pudo crear la tarea");
            fin(false);
        });
    }

    // Lo que se ha tocado en la hoja de editar la tarea `id`, de una vez:
    // `c` lleva solo lo que cambia, de { texto, prioridad (la del panel, o ""
    // para quitarla), claudeOff, seccion (el id de la categoría a la que pasa),
    // horaInicio y horaFin (las dos juntas; "" las dos para dejarla de todo el
    // día) }. Lo que no
    // trae no se toca ni se manda. Optimista, como mover.
    function cambiar(id, c, alAcabar) {
        c = c || {};
        const cuerpo = {};
        if ("texto" in c)
            cuerpo.texto = String(c.texto || "").replace(/\s+/g, " ").trim();
        if ("prioridad" in c)
            cuerpo.prioridad = String(c.prioridad || "");
        if ("claudeOff" in c)
            cuerpo.claude_off = c.claudeOff === true;
        if ("seccion" in c)
            cuerpo.seccion = String(c.seccion || "");
        if ("horaInicio" in c || "horaFin" in c) {
            cuerpo.hora_inicio = String(c.horaInicio || "");
            cuerpo.hora_fin = String(c.horaFin || "");
        }
        const motivo = Object.keys(cuerpo).length === 0 ? "No hay nada que cambiar" : cli.motivoDe(cuerpo);
        if (motivo !== "") {
            p.error = motivo;
            if (alAcabar)
                alAcabar(false);
            return;
        }
        const hoy = String((p.crudas && p.crudas.today) || "").slice(0, 10);
        cli.editar(id, cuerpo, (t, nuevas) => {
            if ("texto" in cuerpo)
                t.text = cuerpo.texto;
            if ("prioridad" in cuerpo) {
                t.priority = cuerpo.prioridad;
                t.effective = cli.efectiva(cuerpo.prioridad, String(t.due || "").slice(0, 10), hoy);
            }
            if ("claude_off" in cuerpo)
                t.claude_off = cuerpo.claude_off;
            if ("hora_inicio" in cuerpo) {
                t.time_start = cuerpo.hora_inicio;
                t.time_end = cuerpo.hora_fin;
            }
            // A la otra sección, al final (como la deja el panel).
            if ("seccion" in cuerpo) {
                const secs = nuevas.sections || [];
                const origen = secs.find(s => (s.tasks || []).includes(t));
                const destino = secs.find(s => String(s.id) === cuerpo.seccion);
                if (origen && destino && origen !== destino) {
                    origen.tasks.splice(origen.tasks.indexOf(t), 1);
                    destino.tasks = (destino.tasks || []).concat([t]);
                }
            }
        }, "No se pudo guardar la tarea", alAcabar);
    }

    // Borra la tarea `id` (DELETE /api/tareas/{id}). No es optimista, como
    // crear: la tarea se va cuando el panel contesta con la lista nueva. Sin
    // cuerpo. alAcabar(ok) al terminar; si no, error dice por qué.
    function eliminar(id, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        if (!cli.puedeEscribir || !id) {
            fin(false);
            return;
        }
        p.error = "";
        p.escribiendo = true;
        cli.pedir("DELETE", "/api/tareas/" + encodeURIComponent(id), undefined, (estado, respuesta) => {
            p.escribiendo = false;
            if (cli.aceptada(estado, respuesta)) {
                fin(true);
                return;
            }
            cli.rechazada(estado, respuesta, "No se pudo eliminar la tarea");
            fin(false);
        });
    }

    // Lo común de mover, la prioridad, el 🚫🤖 y la hoja: cambia la tarea `id` en una
    // copia de lo último leído con aplicar(t, nuevas) (sobre la tarea tal como
    // la devuelve el panel, y la copia entera por si hay que cambiarla de
    // sección), la enseña, y manda `cuerpo` a POST /api/tareas/{id}.
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
        let hallada = null;
        for (const s of nuevas.sections || [])
            for (const t of s.tasks || [])
                if (String(t.id) === id && !hallada)
                    hallada = t;
        if (hallada)
            aplicar(hallada, nuevas);
        if (!hallada) {
            p.error = "La tarea ya no está en el panel";
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
