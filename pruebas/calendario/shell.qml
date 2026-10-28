import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "shared"
import "shared/AgendaFormato.js" as Formato
import "barra" as Barra
import "cajon" as Cajon

// Prueba sin pantalla de la agenda del calendario (la lanza prueba.sh, al
// lado). Tres partes: el formato, el fichero entre el cajón y la barra (con
// una API falsa y un $XDG_RUNTIME_DIR temporal) y el CalendarPanel.qml del
// repo con un shell falso, movido con TestEvent. Cada comprobación imprime OK
// o FALLO; al final, el recuento.
//
// Ninguna comprobación imprime el texto de una tarea ni el JSON: prueba.sh
// mira después que no haya ninguno en el log.
FloatingWindow {
    id: ventana

    implicitWidth: 420
    implicitHeight: 640
    color: "#1b2030"

    readonly property string dir: Quickshell.env("PRUEBA_DIR") + "/capturas/"
    readonly property string ruta: Quickshell.env("XDG_RUNTIME_DIR") + "/escritorio-agenda.json"

    // --- Datos falsos ----------------------------------------------------------

    // Las tareas como las deja Api.qml (api.tareas). «hecha» marca la entrega
    // de Aules como hecha.
    function tareasPrueba(hecha) {
        return {
            habilitado: true,
            error: "",
            version: "v1",
            hoy: "2026-10-21",
            areas: ["Casa"],
            secciones: [
                {
                    id: "trabajo",
                    titulo: "Trabajo",
                    color: "#4a90e2",
                    pausa: false,
                    tareas: [
                        {
                            plano: "Informe trimestral",
                            texto: "**Informe** trimestral",
                            area: "",
                            prioridad: "media",
                            efectiva: "maxima",
                            vence: "2026-10-19",
                            vencida: true,
                            hecha: false
                        },
                        {
                            plano: "Sin fecha",
                            area: "",
                            prioridad: "alta",
                            efectiva: "alta",
                            vence: "",
                            hecha: false
                        },
                        {
                            plano: "Fecha rota",
                            area: "",
                            prioridad: "alta",
                            efectiva: "alta",
                            vence: "21/10/2026",
                            hecha: false
                        },
                        {
                            plano: "Revisar   la\nPR",
                            area: "Casa",
                            prioridad: "baja",
                            efectiva: "alta",
                            vence: "2026-10-23",
                            vencida: false,
                            hecha: true
                        }
                    ]
                },
                {
                    id: "clase",
                    titulo: "Clase",
                    color: "",
                    pausa: false,
                    tareas: [
                        {
                            plano: "MIA: Entrega secreta 3",
                            area: "Clase",
                            prioridad: "",
                            efectiva: "alta",
                            vence: "2026-10-21",
                            vencida: false,
                            hecha: !!hecha
                        },
                        {
                            plano: "MIA: Tarea 4",
                            area: "Clase",
                            prioridad: "",
                            efectiva: "",
                            vence: "2026-11-02",
                            vencida: false,
                            hecha: false
                        }
                    ]
                },
                {
                    id: "en-pausa",
                    titulo: "En pausa",
                    color: "#zzzzzz",
                    pausa: true,
                    tareas: [
                        {
                            plano: "Aparcada",
                            area: "",
                            prioridad: "alta",
                            efectiva: "maxima",
                            vence: "2026-10-10",
                            vencida: true,
                            hecha: false
                        }
                    ]
                }
            ]
        };
    }

    function ev1(dia, titulo, extra) {
        return Object.assign({
            dia: dia,
            titulo: titulo,
            origen: "tarea",
            prioridad: "",
            todoElDia: true,
            hora: "",
            vencida: false,
            hecha: false,
            area: "",
            seccion: "Trabajo",
            color: ""
        }, extra || {});
    }

    // La agenda del calendario, como la dejaría el cajón.
    function agendaPanel(conectado) {
        const e = [ventana.ev1("2026-10-19", "Informe", {
                prioridad: "maxima",
                vencida: true
            }), ventana.ev1("2026-10-21", "MIA: Tarea 3", {
                origen: "clase",
                prioridad: "alta",
                area: "Clase",
                seccion: "Clase"
            }), ventana.ev1("2026-10-21", "Llamar al banco", {
                hecha: true,
                prioridad: "media",
                area: "Casa"
            }), ventana.ev1("2026-10-22", "Reunión", {
                origen: "google",
                todoElDia: false,
                hora: "10:30"
            }), ventana.ev1("2026-10-23", "Media", {
                prioridad: "media"
            }), ventana.ev1("2026-10-23", "Baja", {
                prioridad: "baja"
            }), ventana.ev1("2026-10-23", "Alta", {
                prioridad: "alta"
            }), ventana.ev1("2026-10-23", "Mínima", {
                prioridad: "minima"
            }), ventana.ev1("2026-11-02", "MIA: Tarea 4", {
                origen: "clase",
                area: "Clase"
            })];
        for (let i = 1; i <= 8; i++)
            e.push(ventana.ev1("2026-10-26", "Cosa " + i, {}));
        return Formato.leer(JSON.stringify({
            formato: 1,
            conectado: conectado,
            actualizado: "2026-10-21T10:00:00.000Z",
            eventos: e
        }));
    }

    // --- El cajón y la barra, con el fichero de verdad ---------------------------

    QtObject {
        id: apiFalsa
        property var tareas: null
        property var tareasCargadas: null
        property string conexion: "conectando"
    }

    Cajon.Agenda {
        id: escritor
        api: apiFalsa
        espera: 50
    }

    Barra.Agenda {
        id: lector
    }

    // Otra barra, que arranca cuando todavía no hay fichero (lo normal: la
    // barra arranca antes que el cajón).
    Loader {
        id: cargaLector2
        active: false
        sourceComponent: Component {
            Barra.Agenda {}
        }
    }

    // Mira el fichero desde fuera: su modo (o «no» si no está) y si se ha
    // quedado un temporal.
    property string visto: ""

    Process {
        id: mirar
        command: ["sh", "-c", "if [ -e \"$1\" ]; then stat -c %a -- \"$1\"; else echo no; fi; if [ -e \"$1.tmp\" ]; then echo tmp; fi", "sh", ventana.ruta]
        stdout: StdioCollector {
            onStreamFinished: ventana.visto = this.text.trim()
        }
    }

    // Algo que no es una agenda, escrito por otro.
    Process {
        id: estropear
        command: ["sh", "-c", "printf 'esto no es json' > \"$1\"", "sh", ventana.ruta]
    }

    property int escrituras0: 0

    // --- El calendario -----------------------------------------------------------

    QtObject {
        id: shellFalso
        // Miércoles 21 de octubre de 2026.
        property date now: new Date(2026, 9, 21, 12, 0)
        property string mode: "calendar"
        property var agenda: null
        property var tareas: null
    }

    // El cliente del panel (bar/Tareas.qml), falso: guarda las llamadas y
    // aplica el movimiento a su propia agenda, o falla.
    QtObject {
        id: tareasFalso
        property var evs: []
        property var datos: null
        property bool puedeMover: true
        property string error: ""
        property bool falla: false
        property int refrescos: 0
        property var llamadas: []
        function publicar() {
            datos = Formato.leer(JSON.stringify({
                formato: 1,
                conectado: true,
                actualizado: "",
                eventos: evs
            }));
        }
        function refrescar(forzar) {
            refrescos++;
        }
        function mover(id, dia, alAcabar) {
            llamadas = llamadas.concat([[id, dia]]);
            if (falla) {
                error = "El NUC no contesta";
                alAcabar(false);
                return;
            }
            evs = evs.map(e => e.id === id ? Object.assign({}, e, {
                    dia: dia
                }) : e);
            publicar();
            alAcabar(true);
        }
    }

    Item {
        id: envoltura
        anchors.fill: parent

        Rectangle {
            x: 20
            y: 20
            width: cal.width
            height: cal.height
            radius: Theme.radius
            color: Theme.glassTop
            border.color: Theme.edgeTop
        }

        Barra.CalendarPanel {
            id: cal
            x: 20
            y: 20
            width: implicitWidth
            height: implicitHeight
            shell: shellFalso
        }
    }

    TestEvent {
        id: ev
    }

    // --- Ayudas ------------------------------------------------------------------

    property var fallos: []
    property int hechas: 0

    function comprobar(ok, que, extra) {
        console.log((ok ? "OK     " : "FALLO  ") + que + (extra !== undefined && extra !== "" ? "  (" + extra + ")" : ""));
        ventana.hechas++;
        if (!ok)
            ventana.fallos.push(que);
    }

    function captura(nombre) {
        envoltura.grabToImage(r => r.saveToFile(ventana.dir + nombre + ".png"));
    }

    function recorrer(item, f) {
        f(item);
        for (let k = 0; k < item.children.length; k++)
            ventana.recorrer(item.children[k], f);
    }

    function todos(nombre) {
        const l = [];
        ventana.recorrer(cal, it => {
            if (it.objectName === nombre && it.visible)
                l.push(it);
        });
        return l;
    }

    function uno(nombre) {
        const l = ventana.todos(nombre);
        return l.length ? l[0] : null;
    }

    function hijos(raiz, nombre) {
        const l = [];
        ventana.recorrer(raiz, it => {
            if (it !== raiz && it.objectName === nombre && it.visible)
                l.push(it);
        });
        return l;
    }

    // Los puntos de la casilla de un día.
    function puntosDe(dia) {
        const c = ventana.uno("dia-" + dia);
        return c ? ventana.hijos(c, "punto") : null;
    }

    function clicDia(dia) {
        const c = ventana.uno("dia-" + dia);
        const p = c.mapToItem(envoltura, c.width / 2, c.height / 2);
        ev.mouseClick(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function clicEn(item) {
        const p = item.mapToItem(envoltura, item.width / 2, item.height / 2);
        ev.mouseClick(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function filas() {
        return ventana.todos("filaAgenda");
    }

    function etiquetas() {
        return ventana.filas().map(f => ventana.hijos(f, "etiquetaFila")[0].text);
    }

    function textoDe(nombre) {
        const t = ventana.uno(nombre);
        return t ? t.text : null;
    }

    function igual(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // --- Los pasos ---------------------------------------------------------------

    property var agendaF: null
    property real alto0: 0

    readonly property var pasos: [
        // --- El formato ---
        [100, () => {
                ventana.comprobar(Formato.ruta("/run/user/1000/") === "/run/user/1000/escritorio-agenda.json" && Formato.ruta("") === "" && Formato.ruta(undefined) === "", "la ruta del fichero sale del directorio de ejecución, y sin él no hay");
                ventana.comprobar(Formato.deTareas(null, true, null) === null && Formato.deTareas({
                    habilitado: false
                }, true, null) === null, "sin tareas, o con las tareas apagadas en el panel, no hay agenda");
                const cuando = new Date(Date.UTC(2026, 9, 21, 10, 0));
                const d = Formato.deTareas(ventana.tareasPrueba(false), true, cuando);
                const dias = d.eventos.map(e => e.dia);
                ventana.comprobar(d.formato === 1 && d.conectado === true && d.actualizado === "2026-10-21T10:00:00.000Z", "la agenda lleva el formato, la conexión y cuándo se leyó", d.actualizado);
                ventana.comprobar(ventana.igual(dias, ["2026-10-10", "2026-10-19", "2026-10-21", "2026-10-23", "2026-11-02"]), "solo entran las tareas con fecha válida, ordenadas por día", dias.join(" "));
                const porDia = {};
                d.eventos.forEach(e => porDia[e.dia] = e);
                const clase = porDia["2026-10-21"];
                ventana.comprobar(clase.origen === "clase" && clase.area === "Clase" && clase.seccion === "Clase" && clase.todoElDia === true && clase.hora === "", "una entrega de Aules sale con origen «clase» y su área");
                ventana.comprobar(porDia["2026-10-19"].origen === "tarea" && porDia["2026-10-19"].color === "#4a90e2" && porDia["2026-10-19"].seccion === "Trabajo", "una tarea de otra sección sale con origen «tarea», su sección y su color");
                ventana.comprobar(porDia["2026-10-19"].prioridad === "maxima" && porDia["2026-10-23"].prioridad === "baja" && porDia["2026-10-10"].prioridad === "pausa" && porDia["2026-11-02"].prioridad === "", "la prioridad: la de hoy si está abierta, la suya si está hecha, «pausa» en pausa");
                ventana.comprobar(porDia["2026-10-19"].vencida === true && porDia["2026-10-23"].vencida === false && porDia["2026-10-23"].hecha === true, "vencida y hecha pasan tal cual (una hecha nunca está vencida)");
                ventana.comprobar(porDia["2026-10-23"].titulo.indexOf("\n") < 0 && porDia["2026-10-23"].titulo.indexOf("  ") < 0 && porDia["2026-10-10"].color === "", "el título va en una línea y un color que no vale se queda en blanco");
                ventana.comprobar(Formato.deTareas(ventana.tareasPrueba(false), false, null).actualizado === "" && Formato.deTareas(ventana.tareasPrueba(false), false, null).conectado === false, "sin fecha de lectura, actualizado va vacío");
                // Ida y vuelta por el fichero.
                const a = Formato.leer(JSON.stringify(d));
                ventana.comprobar(a !== null && a.eventos.length === 5 && a.porDia["2026-10-21"].length === 1 && a.conectado === true && a.actualizado instanceof Date && a.actualizado.getTime() === cuando.getTime(), "lo que escribe el cajón lo lee la barra igual");
            }],
        [50, () => {
                ventana.comprobar(Formato.leer("esto no es json") === null && Formato.leer("") === null && Formato.leer("null") === null && Formato.leer("[]") === null, "un fichero roto no es una agenda (y no lanza)");
                ventana.comprobar(Formato.leer(JSON.stringify({
                    formato: 2,
                    eventos: []
                })) === null && Formato.leer(JSON.stringify({
                    formato: 1
                })) === null, "otro formato, o sin eventos, tampoco");
                const a = Formato.leer(JSON.stringify({
                    formato: 1,
                    conectado: "sí",
                    eventos: [null, 3, {
                            dia: "21-10-2026",
                            titulo: "x"
                        }, {
                            dia: "2026-10-21",
                            titulo: "   "
                        }, {
                            dia: "2026-10-21",
                            titulo: "Bien",
                            prioridad: "urgentísima",
                            color: "rojo",
                            hora: "9:00",
                            todoElDia: false,
                            vencida: "sí",
                            extra: 1
                        }]
                }));
                const e = a ? a.eventos[0] : null;
                ventana.comprobar(a !== null && a.eventos.length === 1 && a.conectado === false && a.actualizado === null, "los eventos que no valen se quitan, y lo raro toma su valor por defecto", a ? String(a.eventos.length) : "null");
                ventana.comprobar(e && e.prioridad === "" && e.color === "" && e.hora === "" && e.todoElDia === true && e.vencida === false && e.origen === "tarea" && e.area === "", "  una prioridad, un color o una hora que no valen se quedan en blanco");
            }],
        [50, () => {
                const hoy = "2026-10-21";
                const a = Formato.leer(JSON.stringify({
                    formato: 1,
                    conectado: true,
                    eventos: [ventana.ev1("2026-10-10", "Aparcada", {
                            prioridad: "pausa",
                            vencida: true
                        }), ventana.ev1("2026-10-19", "Vencida", {
                            vencida: true,
                            prioridad: "maxima"
                        }), ventana.ev1("2026-10-20", "De ayer", {}), ventana.ev1("2026-10-20", "Hecha ayer", {
                            hecha: true
                        }), ventana.ev1("2026-10-20", "Reunión de ayer", {
                            origen: "google",
                            todoElDia: false,
                            hora: "09:00"
                        }), ventana.ev1(hoy, "Con hora", {
                            origen: "google",
                            todoElDia: false,
                            hora: "08:00",
                            prioridad: "maxima"
                        }), ventana.ev1(hoy, "Hecha hoy", {
                            hecha: true,
                            prioridad: "maxima"
                        }), ventana.ev1(hoy, "Baja", {
                            prioridad: "baja"
                        }), ventana.ev1(hoy, "Alta", {
                            prioridad: "alta"
                        })]
                }));
                const deHoy = Formato.delDia(a, hoy, hoy);
                ventana.comprobar(ventana.igual(deHoy.map(e => e.titulo), ["Vencida", "De ayer", "Alta", "Baja", "Con hora", "Hecha hoy"]), "hoy: lo vencido de antes delante; luego lo de todo el día por prioridad, lo que tiene hora y lo hecho al final", deHoy.length + " filas");
                ventana.comprobar(deHoy[0].deAntes === true && deHoy[1].deAntes === true && !deHoy[2].deAntes, "  lo de otros días va marcado como de antes");
                ventana.comprobar(!deHoy.some(e => e.titulo === "Aparcada" || e.titulo === "Hecha ayer" || e.titulo === "Reunión de ayer"), "  ni lo de pausa, ni lo hecho, ni una reunión pasada cuentan como vencidos");
                const ayer = Formato.delDia(a, "2026-10-20", hoy);
                ventana.comprobar(Formato.tipo(ayer.find(e => e.titulo === "De ayer"), hoy) === "vencida", "una tarea sin hacer de un día pasado está vencida aunque el fichero diga que no (puede ser de ayer)");
                ventana.comprobar(Formato.tipo(ayer.find(e => e.titulo === "Hecha ayer"), hoy) === "hecha" && Formato.tipo(ayer.find(e => e.titulo === "Reunión de ayer"), hoy) === "" && Formato.tipo(Formato.delDia(a, "2026-10-10", hoy)[0], hoy) === "pausa", "  hecha es hecha, una reunión no vence y la pausa sale como pausa");
                ventana.comprobar(Formato.delDia(a, "2026-10-19", hoy).length === 1 && !Formato.delDia(a, "2026-10-19", hoy)[0].deAntes, "otro día: solo lo suyo");
                ventana.comprobar(ventana.igual(Formato.puntos(a, hoy, hoy, 3), ["alta", "baja", "maxima"]) && Formato.puntos(a, "2026-10-20", hoy, 3).length === 3 && Formato.puntos(a, "2026-10-20", hoy, 3)[0] === "vencida", "los puntos de una casilla: tres como mucho, en el orden de la lista", Formato.puntos(a, hoy, hoy, 3).join(" "));
                ventana.comprobar(Formato.puntos(null, hoy, hoy, 3).length === 0 && Formato.delDia(null, hoy, hoy).length === 0 && Formato.puntos(a, "2026-12-01", hoy, 3).length === 0, "sin agenda, o un día sin nada: ni puntos ni filas");
                ventana.comprobar(Formato.diaCorto("2026-10-19") === "19 oct" && Formato.diaCorto("2027-01-05") === "5 ene" && Formato.diaCorto("x") === "", "la fecha corta: «19 oct»");
            }],

        // --- El fichero: el cajón lo escribe, la barra lo lee ---
        [300, () => mirar.running = true],
        [300, () => {
                ventana.comprobar(ventana.visto === "no", "al arrancar, el cajón borra la agenda de otra vez", ventana.visto);
                ventana.comprobar(lector.datos === null, "  y la barra se queda sin agenda");
                ventana.escrituras0 = escritor.escrituras;
                // Como al conectar: la conexión y las tareas, casi juntas.
                apiFalsa.conexion = "conectado";
                apiFalsa.tareasCargadas = new Date(Date.UTC(2026, 9, 21, 10, 0));
                apiFalsa.tareas = ventana.tareasPrueba(false);
            }],
        [600, () => {
                const d = lector.datos;
                ventana.comprobar(escritor.escrituras === ventana.escrituras0 + 1, "la conexión y las tareas llegan casi juntas y se escribe una vez", String(escritor.escrituras - ventana.escrituras0));
                ventana.comprobar(d !== null && d.eventos.length === 5 && d.conectado === true && d.actualizado !== null && d.actualizado.getTime() === Date.UTC(2026, 9, 21, 10, 0), "con las tareas, la barra lee la agenda del fichero", d ? String(d.eventos.length) : "null");
                ventana.comprobar(d !== null && d.porDia["2026-10-21"][0].origen === "clase" && d.porDia["2026-10-21"][0].hecha === false, "  con la entrega de Aules de hoy");
                mirar.running = true;
            }],
        [300, () => {
                ventana.comprobar(ventana.visto === "600", "el fichero es solo del usuario (600) y no queda ningún temporal", ventana.visto);
                ventana.escrituras0 = escritor.escrituras;
                // Lo mismo otra vez, en otro objeto: no hace falta escribir.
                apiFalsa.tareas = ventana.tareasPrueba(false);
            }],
        [300, () => {
                ventana.comprobar(escritor.escrituras === ventana.escrituras0, "si la agenda no cambia, no se reescribe", String(escritor.escrituras - ventana.escrituras0));
                apiFalsa.tareasCargadas = new Date(Date.UTC(2026, 9, 21, 11, 0));
                apiFalsa.tareas = ventana.tareasPrueba(true);
            }],
        [400, () => {
                const d = lector.datos;
                ventana.comprobar(escritor.escrituras === ventana.escrituras0 + 1 && d !== null && d.porDia["2026-10-21"][0].hecha === true, "al marcar una tarea, la barra la ve hecha", d ? "" : "null");
                ventana.escrituras0 = escritor.escrituras;
                // El panel no pudo leer la nota.
                apiFalsa.tareas = {
                    habilitado: true,
                    error: "No se pudo leer 00 Inicio.md",
                    secciones: []
                };
            }],
        [400, () => {
                const d = lector.datos;
                ventana.comprobar(escritor.escrituras === ventana.escrituras0 && d !== null && d.eventos.length === 5, "si el panel no pudo leer la nota, se queda la última agenda buena");
                apiFalsa.conexion = "sin-conexion";
            }],
        [400, () => {
                const d = lector.datos;
                ventana.comprobar(d !== null && d.conectado === false && d.eventos.length === 5, "sin conexión con el panel, la agenda se queda pero lo dice");
                apiFalsa.conexion = "sin-credenciales";
                apiFalsa.tareas = null;
            }],
        [400, () => mirar.running = true],
        [300, () => {
                ventana.comprobar(ventana.visto === "no" && lector.datos === null, "sin tareas (sin credenciales), se borra el fichero y la barra se queda sin agenda", ventana.visto);
                apiFalsa.conexion = "conectado";
                apiFalsa.tareas = ventana.tareasPrueba(false);
            }],
        [400, () => {
                const d = lector.datos;
                ventana.comprobar(d !== null && d.eventos.length === 5 && d.conectado === true, "vuelven las tareas: el fichero vuelve y la barra lo ve (sigue vigilando después de borrarlo)");
                estropear.running = true;
            }],
        [400, () => {
                ventana.comprobar(lector.datos === null, "un fichero que no es una agenda es como no tenerlo");
                apiFalsa.tareas = ventana.tareasPrueba(true);
            }],
        [400, () => {
                const d = lector.datos;
                ventana.comprobar(d !== null && d.eventos.length === 5, "  y con el siguiente cambio el cajón lo deja bien otra vez");
                apiFalsa.tareas = {
                    habilitado: false,
                    error: "",
                    secciones: []
                };
            }],
        [400, () => mirar.running = true],
        [300, () => {
                ventana.comprobar(ventana.visto === "no" && lector.datos === null, "con las tareas apagadas en el panel, no hay fichero", ventana.visto);
                cargaLector2.active = true;
            }],
        [300, () => {
                ventana.comprobar(cargaLector2.item !== null && cargaLector2.item.datos === null, "una barra que arranca sin fichero se queda sin agenda, sin errores");
                apiFalsa.tareas = ventana.tareasPrueba(false);
            }],
        [400, () => {
                const d = cargaLector2.item ? cargaLector2.item.datos : null;
                ventana.comprobar(d !== null && d.eventos.length === 5, "  y cuando el cajón escribe la agenda, la ve");
                cargaLector2.active = false;
                apiFalsa.tareas = {
                    habilitado: false,
                    error: "",
                    secciones: []
                };
            }],
        [400, () => ventana.comprobar(lector.datos === null, "(otra vez sin fichero)")],

        // --- El calendario ---
        [200, () => {
                ventana.comprobar(ventana.todos("punto").length === 0, "sin agenda, ningún día lleva puntos");
                ventana.comprobar(ventana.uno("agendaDia") === null, "  ni hay lista del día");
                ventana.alto0 = cal.implicitHeight;
                ventana.clicDia("2026-10-23");
            }],
        [200, () => {
                ventana.comprobar(cal.elegido === "" && ventana.uno("botonHoy") === null, "  y pulsar un día no hace nada");
                ventana.captura("1-sin-agenda");
            }],
        // Una captura sale en el siguiente fotograma: lo siguiente, en otro paso.
        [200, () => shellFalso.agenda = ventana.agendaPanel(true)],
        [300, () => {
                const p19 = ventana.puntosDe("2026-10-19");
                const p23 = ventana.puntosDe("2026-10-23");
                ventana.comprobar(p23 && p23.length === 3, "un día con cuatro cosas lleva tres puntos", p23 ? String(p23.length) : "sin casilla");
                ventana.comprobar(p19 && p19.length === 1 && Qt.colorEqual(p19[0].color, Theme.prioMaxima), "  un día con una vencida, un punto rojo");
                ventana.comprobar(ventana.puntosDe("2026-10-21").length === 2 && ventana.puntosDe("2026-10-20").length === 0, "  hoy, dos; ayer, ninguno");
                ventana.comprobar(ventana.puntosDe("2026-11-02") !== null && ventana.puntosDe("2026-11-02").length === 1, "  y los días del mes de al lado también");
                ventana.comprobar(ventana.uno("agendaDia") !== null && ventana.textoDe("tituloDia") === "Hoy", "debajo, la lista de hoy");
                const f = ventana.filas();
                const et = ventana.etiquetas();
                ventana.comprobar(f.length === 3 && et[0] === "venció 19 oct" && et[1] === "Clase" && et[2] === "Casa", "  con lo vencido de antes delante, la entrega de Aules y lo hecho al final", f.length + " filas: " + et.join(", "));
                ventana.comprobar(f.length === 3 && Qt.colorEqual(ventana.hijos(f[0], "etiquetaFila")[0].color, Theme.prioMaxima) && ventana.hijos(f[2], "tituloFila")[0].font.strikeout, "  la vencida en rojo y la hecha tachada");
                ventana.comprobar(ventana.uno("sinConexion") === null && ventana.uno("masFilas") === null && ventana.uno("diaVacio") === null, "  sin avisos de más");
                ventana.alto0 = cal.implicitHeight;
                ventana.captura("2-hoy");
            }],
        [200, () => ventana.clicDia("2026-10-23")],
        [300, () => {
                ventana.comprobar(cal.elegido === "2026-10-23" && ventana.textoDe("tituloDia") === "Viernes 23 de octubre" && ventana.filas().length === 4, "al pulsar un día se ve lo suyo", ventana.textoDe("tituloDia") + ", " + ventana.filas().length + " filas");
                ventana.comprobar(ventana.uno("botonHoy") !== null, "  y sale el botón de volver a hoy");
                ventana.captura("3-dia-23");
            }],
        [200, () => ventana.clicDia("2026-10-23")],
        [300, () => {
                ventana.comprobar(cal.elegido === "" && ventana.textoDe("tituloDia") === "Hoy", "pulsar otra vez el mismo día vuelve a hoy");
                ventana.clicDia("2026-10-26");
            }],
        [300, () => {
                ventana.comprobar(ventana.filas().length === 6 && ventana.textoDe("masFilas") === "y 2 más", "un día con ocho cosas enseña seis y cuenta el resto", ventana.filas().length + " filas");
                ventana.captura("4-dia-26");
            }],
        [200, () => ventana.clicDia("2026-10-19")],
        [300, () => {
                ventana.comprobar(ventana.textoDe("tituloDia") === "Lunes 19 de octubre" && ventana.igual(ventana.etiquetas(), ["vencida"]), "un día pasado: su tarea sin hacer, marcada como vencida", ventana.etiquetas().join(", "));
                ventana.clicDia("2026-10-22");
            }],
        [300, () => {
                ventana.comprobar(ventana.textoDe("tituloDia") === "Mañana" && ventana.igual(ventana.etiquetas(), ["10:30"]), "mañana: una reunión con hora lleva la hora", ventana.etiquetas().join(", "));
                ventana.clicDia("2026-10-28");
            }],
        [300, () => {
                ventana.comprobar(ventana.filas().length === 0 && ventana.textoDe("diaVacio") === "Nada para este día", "un día sin nada lo dice");
                ventana.comprobar(cal.implicitHeight === ventana.alto0, "  y la isla no cambia de alto entre un día con tres cosas y uno sin nada", cal.implicitHeight + " y " + ventana.alto0);
                ventana.clicDia("2026-10-20");
            }],
        [300, () => {
                ventana.comprobar(ventana.textoDe("tituloDia") === "Ayer", "ayer se llama ayer");
                ventana.clicDia("2026-10-21");
            }],
        [300, () => {
                ventana.comprobar(cal.elegido === "" && ventana.uno("botonHoy") === null, "pulsar hoy vuelve a hoy y quita el botón");
                const p = cal.mapToItem(envoltura, cal.width / 2, cal.height / 2);
                ev.mouseWheel(envoltura, p.x, p.y, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 1 && ventana.uno("botonHoy") !== null, "la rueda pasa al mes siguiente y sale el botón de hoy", String(cal.monthOffset));
                ventana.comprobar(ventana.puntosDe("2026-11-02") !== null && ventana.puntosDe("2026-11-02").length === 1 && ventana.textoDe("tituloDia") === "Hoy", "  noviembre también lleva sus puntos, y la lista sigue siendo la de hoy");
                ventana.clicDia("2026-11-02");
            }],
        [300, () => {
                ventana.comprobar(cal.elegido === "2026-11-02" && ventana.textoDe("tituloDia") === "Lunes 2 de noviembre", "se puede pulsar un día de otro mes");
                ventana.clicEn(ventana.uno("botonHoy"));
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 0 && cal.elegido === "" && ventana.textoDe("tituloDia") === "Hoy", "el botón de hoy vuelve al mes y al día de hoy");
                ventana.clicDia("2026-10-23");
            }],
        [300, () => {
                ventana.comprobar(cal.elegido === "2026-10-23", "(con un día pulsado)");
                shellFalso.mode = "";
            }],
        [200, () => {
                ventana.comprobar(cal.elegido === "", "al cerrar la isla se olvida el día pulsado");
                shellFalso.mode = "calendar";
                shellFalso.agenda = ventana.agendaPanel(false);
            }],
        [300, () => {
                ventana.comprobar(ventana.uno("sinConexion") !== null, "si el cajón no tenía conexión, la lista lo dice");
                ventana.captura("5-sin-conexion");
            }],
        // --- Mes y año, y arrastrar tareas ---
        [200, () => {
                shellFalso.mode = "";
            }],
        [200, () => {
                shellFalso.mode = "calendar";
                ventana.comprobar(tareasFalso.refrescos >= 0, "(abierto otra vez)");
                tareasFalso.evs = [ventana.ev1("2026-10-23", "Media", {
                        id: "b",
                        prioridad: "media"
                    }), ventana.ev1("2026-10-23", "Alta", {
                        id: "c",
                        prioridad: "alta"
                    }), ventana.ev1("2026-10-19", "Sin id", {})];
                tareasFalso.publicar();
                shellFalso.tareas = tareasFalso;
                shellFalso.agenda = Qt.binding(() => tareasFalso.datos);
            }],
        [300, () => {
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [500, () => {
                ventana.comprobar(cal.selector === "mes" && ventana.todos("opcionSelector").length === 12, "el mes se elige en un desplegable de doce", cal.selector);
                ventana.captura("7-selector-mes");
                ventana.clicEn(ventana.todos("opcionSelector")[10]);
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 1 && cal.selector === "" && cal.shown.getMonth() === 10, "elegir noviembre cambia de mes y cierra el desplegable", String(cal.monthOffset));
                ventana.clicEn(ventana.uno("chipAnio"));
            }],
        [500, () => {
                const o = ventana.todos("opcionSelector").filter(x => x.valor === 2028)[0];
                ventana.comprobar(cal.selector === "anio" && o !== undefined, "el año se elige en otro, con doce años a la vista");
                ventana.captura("8-selector-anio");
                ventana.clicEn(o);
            }],
        [300, () => {
                ventana.comprobar(cal.shown.getFullYear() === 2028 && cal.shown.getMonth() === 10 && cal.monthOffset === 25, "elegir 2028 cambia el año y conserva el mes", String(cal.monthOffset));
                ventana.clicEn(ventana.uno("mesAnterior"));
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 24 && cal.shown.getMonth() === 9, "la flecha izquierda retrocede un mes");
                ventana.clicEn(ventana.uno("mesSiguiente"));
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 25, "la flecha derecha avanza un mes");
                ventana.clicEn(ventana.uno("botonHoy"));
            }],
        [300, () => {
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [400, () => {
                ventana.comprobar(cal.selector === "mes", "(desplegable abierto)");
                ventana.clicDia("2026-10-23");
            }],
        [400, () => {
                ventana.comprobar(cal.selector === "" && cal.elegido === "", "pulsar fuera del desplegable lo cierra sin elegir un día");
                ventana.clicDia("2026-10-23");
            }],
        [300, () => {
                ventana.comprobar(cal.elegido === "2026-10-23" && ventana.filas().length === 2, "(el 23, con sus tareas)", ventana.filas().length + " filas");
            }],
        [100, () => {
                // Arrastrar la fila «Media» (id b) al 27.
                const f = ventana.filas().filter(x => ventana.hijos(x, "tituloFila")[0].text === "Media")[0];
                const c = ventana.uno("dia-2026-10-27");
                const a = f.mapToItem(envoltura, 60, f.height / 2);
                const z = c.mapToItem(envoltura, c.width / 2, c.height / 2);
                ev.mousePress(envoltura, a.x, a.y, Qt.LeftButton, Qt.NoModifier, 50);
                for (let k = 1; k <= 12; k++)
                    ev.mouseMove(envoltura, a.x + (z.x - a.x) * k / 12, a.y + (z.y - a.y) * k / 12, 20, Qt.LeftButton, Qt.NoModifier);
                ventana.comprobar(cal.arrastrada !== null && cal.arrastrada.id === "b", "arrastrar una fila lleva la tarea en la mano");
                ventana.captura("9-arrastrando");
                ev.mouseRelease(envoltura, z.x, z.y, Qt.LeftButton, Qt.NoModifier, 50);
            }],
        [500, () => {
                ventana.comprobar(ventana.igual(tareasFalso.llamadas, [["b", "2026-10-27"]]), "soltar sobre un día pide moverla a esa fecha", JSON.stringify(tareasFalso.llamadas));
                ventana.comprobar(ventana.puntosDe("2026-10-27").length === 1 && ventana.puntosDe("2026-10-23").length === 1, "  y la vista cambia: un punto menos el 23 y uno más el 27");
                ventana.comprobar(ventana.uno("avisoMover") !== null && ventana.uno("avisoMover").text === "Movida al 27 oct", "  y avisa", ventana.textoDe("avisoMover"));
                ventana.captura("10-movida");
            }],
        [100, () => {
                tareasFalso.falla = true;
                const f = ventana.filas()[0];
                const c = ventana.uno("dia-2026-10-28");
                const a = f.mapToItem(envoltura, 60, f.height / 2);
                const z = c.mapToItem(envoltura, c.width / 2, c.height / 2);
                ev.mousePress(envoltura, a.x, a.y, Qt.LeftButton, Qt.NoModifier, 50);
                for (let k = 1; k <= 12; k++)
                    ev.mouseMove(envoltura, a.x + (z.x - a.x) * k / 12, a.y + (z.y - a.y) * k / 12, 20, Qt.LeftButton, Qt.NoModifier);
                ev.mouseRelease(envoltura, z.x, z.y, Qt.LeftButton, Qt.NoModifier, 50);
            }],
        [500, () => {
                ventana.comprobar(tareasFalso.llamadas.length === 2 && ventana.textoDe("avisoMover") === "El NUC no contesta", "si el panel falla, lo dice", ventana.textoDe("avisoMover"));
                ventana.comprobar(ventana.puntosDe("2026-10-28").length === 0, "  y la tarea no cambia de día");
        }],
        [100, () => {
                // Soltar fuera de la rejilla no hace nada; sin id, no se arrastra.
                tareasFalso.falla = false;
                const f = ventana.filas()[0];
                const a = f.mapToItem(envoltura, 60, f.height / 2);
                ev.mousePress(envoltura, a.x, a.y, Qt.LeftButton, Qt.NoModifier, 50);
                for (let k = 1; k <= 8; k++)
                    ev.mouseMove(envoltura, a.x + 100, a.y + 10 * k, 20, Qt.LeftButton, Qt.NoModifier);
                ev.mouseRelease(envoltura, a.x + 100, a.y + 80, Qt.LeftButton, Qt.NoModifier, 50);
            }],
        [400, () => {
                ventana.comprobar(tareasFalso.llamadas.length === 2 && cal.arrastrada === null, "soltar fuera de un día no pide nada");
                shellFalso.tareas = null;
                shellFalso.agenda = null;
                cal.volverAHoy();
            }],
        [200, () => {
                // Todo junto: lo que escribe el cajón llega al calendario.
                shellFalso.agenda = Qt.binding(() => lector.datos);
                apiFalsa.conexion = "conectado";
                apiFalsa.tareas = ventana.tareasPrueba(false);
            }],
        [500, () => {
                ventana.comprobar(lector.datos !== null && ventana.puntosDe("2026-10-21").length === 1 && ventana.puntosDe("2026-10-19").length === 1, "del cajón al calendario: las tareas del panel salen como puntos");
                ventana.comprobar(ventana.igual(ventana.etiquetas(), ["venció 19 oct", "Clase"]), "  y la lista de hoy, con la entrega de Aules", ventana.etiquetas().join(", "));
                ventana.captura("6-del-cajon");
            }],
        [200, () => {
                apiFalsa.conexion = "sin-credenciales";
                apiFalsa.tareas = null;
            }],
        [500, () => {
                ventana.comprobar(ventana.todos("punto").length === 0 && ventana.uno("agendaDia") === null, "y si el cajón borra la agenda, el calendario vuelve a la rejilla sola");
            }],
        [300, () => {
                console.log("Resultado: " + (ventana.hechas - ventana.fallos.length) + " de " + ventana.hechas + " bien" + (ventana.fallos.length ? "; fallan: " + ventana.fallos.join(" | ") : ""));
                Qt.quit();
            }]
    ]

    property int i: 0

    Timer {
        id: motor
        interval: 500
        running: true
        onTriggered: {
            if (ventana.i >= ventana.pasos.length)
                return;
            const p = ventana.pasos[ventana.i++];
            // Una excepción en un paso es un fallo, no el final de la prueba.
            try {
                p[1]();
            } catch (e) {
                ventana.comprobar(false, "excepción en el paso " + ventana.i + ": " + e);
            }
            motor.interval = ventana.i < ventana.pasos.length ? ventana.pasos[ventana.i][0] : 100;
            motor.restart();
        }
    }
}
