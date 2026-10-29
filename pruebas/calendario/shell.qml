import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "shared"
import "shared/AgendaFormato.js" as Formato
import "barra" as Barra
import "cajon" as Cajon

// Prueba sin pantalla de la agenda del calendario (la lanza prueba.sh, al
// lado). Cuatro partes: el formato, el fichero entre el cajón y la barra (con
// una API falsa y un $XDG_RUNTIME_DIR temporal), el CalendarPanel.qml del
// repo con un shell falso, movido con TestEvent, y el cliente del panel
// (Tareas.qml) de verdad contra el panel falso de prueba.sh (panel-falso.py),
// con el calendario encima. Cada comprobación imprime OK o FALLO; al final,
// el recuento.
//
// El panel falso manda «aules» en cada tarea (como el panel nuevo): con él,
// «Clase» se ofrece como categoría y una tarea propia movida a Clase se
// borra y se recategoriza; una entrega de Aules no. Con su ajuste «viejo»
// (sin el campo), Clase no se ofrece y toda tarea de Clase es de Aules.
//
// Ninguna comprobación imprime el texto de una tarea ni el JSON: prueba.sh
// mira después que no haya ninguno en el log.
FloatingWindow {
    id: ventana
    property real anchoChip: 0
    property real xFlecha: 0

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
        property bool puedeEscribir: true
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

    // El cliente de verdad: lee HOMELAB_PANEL_URL (el panel falso) y el
    // secret-tool de mentira de prueba.sh.
    Barra.Tareas {
        id: cliente
    }

    // Las teclas que se le escapan al calendario hacia arriba (Escape, que en
    // la isla de verdad la cerraría entera si nadie la recoge antes).
    property int escapesFuera: 0

    Item {
        id: envoltura
        anchors.fill: parent

        Keys.onEscapePressed: ventana.escapesFuera++

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

    // La categoría de cada fila (a la derecha) y su detalle (la hora, «vencida»…).
    function etiquetas() {
        return ventana.filas().map(f => ventana.hijos(f, "etiquetaFila")[0].text);
    }

    function detalles() {
        return ventana.filas().map(f => {
            const d = ventana.hijos(f, "detalleFila")[0];
            return d ? d.text : "";
        });
    }

    function textoDe(nombre) {
        const t = ventana.uno(nombre);
        return t ? t.text : null;
    }

    // El texto de un botón de la hoja (Boton.texto), o null si no se ve.
    function textoBoton(nombre) {
        const b = ventana.unoHoja(nombre);
        return b ? b.texto : null;
    }

    function igual(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // Como hijos(), pero también lo que no se ve (un halo a opacidad 0).
    function buscar(raiz, nombre) {
        const l = [];
        ventana.recorrer(raiz, it => {
            if (it.objectName === nombre)
                l.push(it);
        });
        return l;
    }

    function dobleClicDia(dia) {
        const c = ventana.uno("dia-" + dia);
        const p = c.mapToItem(envoltura, c.width / 2, c.height / 2);
        ev.mouseDoubleClickSequence(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function titulos() {
        return ventana.filas().map(f => ventana.hijos(f, "tituloFila")[0].text);
    }

    function filaDe(titulo) {
        return ventana.filas().find(f => ventana.hijos(f, "tituloFila")[0].text === titulo) || null;
    }

    function puntoDe(titulo) {
        return ventana.hijos(ventana.filaDe(titulo), "puntoFila")[0];
    }

    // El color del punto de una fila (el Rectangle de dentro de puntoFila).
    function colorPunto(titulo) {
        return ventana.puntoDe(titulo).children[0].color;
    }

    function robotDe(titulo) {
        return ventana.hijos(ventana.filaDe(titulo), "claudeOffFila")[0];
    }

    function porId(agenda, id) {
        return agenda ? agenda.eventos.find(e => e.id === id) || null : null;
    }

    function porTitulo(titulo) {
        return cliente.datos ? cliente.datos.eventos.find(e => e.titulo === titulo) || null : null;
    }

    function tituloDe(titulo) {
        return ventana.hijos(ventana.filaDe(titulo), "tituloFila")[0];
    }

    // La categoría de una fila, a la derecha.
    function etiquetaDe(titulo) {
        const f = ventana.filaDe(titulo);
        const e = f ? ventana.hijos(f, "etiquetaFila")[0] : null;
        return e ? e.text : null;
    }

    // Lo que va antes de la categoría: la hora, «vencida»… ("" si nada).
    function detalleDe(titulo) {
        const f = ventana.filaDe(titulo);
        if (!f)
            return null;
        const d = ventana.hijos(f, "detalleFila")[0];
        return d ? d.text : "";
    }

    // La barrita del color de la categoría de una fila.
    function barraDe(titulo) {
        const f = ventana.filaDe(titulo);
        return f ? ventana.buscar(f, "categoriaBarra")[0] : null;
    }

    // --- La hoja de una tarea ---
    function hoja() {
        return ventana.uno("hoja");
    }

    function enHoja(nombre) {
        const h = ventana.hoja();
        return h ? ventana.hijos(h, nombre) : [];
    }

    function unoHoja(nombre) {
        return ventana.enHoja(nombre)[0] || null;
    }

    function titulo() {
        return ventana.unoHoja("campoTitulo");
    }

    // Lo que se sale por la derecha de la hoja: los hijos de su columna que
    // acaban más allá de su ancho, y los de cada fila más allá de la fila.
    function desbordes() {
        const h = ventana.hoja();
        const malos = [];
        const col = h.children[0];
        for (const f of col.children) {
            if (!f.visible)
                continue;
            if (f.x + f.width > h.width + 0.5)
                malos.push((f.objectName || "fila") + " " + Math.round(f.x + f.width) + ">" + Math.round(h.width));
            for (const c of f.children) {
                if (c.visible && c.width > 0 && c.x + c.width > f.width + 0.5)
                    malos.push((c.objectName || "hijo") + " de " + (f.objectName || "fila") + " " + Math.round(c.x + c.width) + ">" + Math.round(f.width));
            }
        }
        return malos;
    }

    // Pulsa el control de la categoría de la hoja (abre o cierra la lista).
    function abrirCategorias() {
        ventana.clicEn(ventana.unoHoja("categoriaControl"));
    }

    property bool prioIntacta: false
    property real alturaHoja: 0
    property real altoIsla: 0
    property int gets0: 0
    property string dia0: ""

    // Un campo de hora, se vea o no (sin «Todo el día» no se ve).
    function campoHora(nombre) {
        const h = ventana.hoja();
        return h ? ventana.buscar(h, nombre)[0] : null;
    }

    // Dos cuerpos iguales, sin mirar el orden de las claves.
    function mismo(a, b) {
        const o = x => x && typeof x === "object" ? Object.keys(x).sort().reduce((r, k) => {
                r[k] = x[k];
                return r;
            }, {}) : x;
        return JSON.stringify(o(a)) === JSON.stringify(o(b));
    }

    function posts() {
        return ventana.registro.filter(x => x.metodo === "POST").length;
    }

    property int posts0: 0

    // --- El panel falso ------------------------------------------------------------
    // Sus dos puertas de prueba, sin credenciales: lo que le han pedido
    // (/__registro) y cuánto tarda o cómo falla en las escrituras (/__ajustes).

    readonly property string urlPanel: Quickshell.env("HOMELAB_PANEL_URL") || ""
    property var registro: []
    property int filas0: 0

    function alPanel(metodo, ruta, cuerpo, alAcabar) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState === XMLHttpRequest.DONE && alAcabar)
                alAcabar(x.status, x.responseText);
        };
        x.open(metodo, ventana.urlPanel + ruta);
        if (cuerpo === undefined) {
            x.send();
        } else {
            x.setRequestHeader("Content-Type", "application/json");
            x.send(JSON.stringify(cuerpo));
        }
    }

    function ajustar(a) {
        ventana.alPanel("POST", "/__ajustes", a);
    }

    function leerRegistro() {
        ventana.alPanel("GET", "/__registro", undefined, (estado, texto) => {
            try {
                ventana.registro = JSON.parse(texto);
            } catch (e) {
                ventana.registro = [];
            }
        });
    }

    function ultima() {
        return ventana.registro.length ? ventana.registro[ventana.registro.length - 1] : {};
    }

    // Coge la fila `titulo` y la lleva por encima de `por` hasta `a`, sin
    // soltarla (soltar() la suelta donde esté); alPasar("por") y alPasar("a")
    // al llegar a cada uno, para mirar qué casillas se resaltan.
    function arrastrar(titulo, por, a, alPasar) {
        const f = ventana.filaDe(titulo);
        const ini = f.mapToItem(envoltura, 60, f.height / 2);
        const cPor = ventana.uno("dia-" + por);
        const cA = ventana.uno("dia-" + a);
        const pPor = cPor.mapToItem(envoltura, cPor.width / 2, cPor.height / 2);
        const pA = cA.mapToItem(envoltura, cA.width / 2, cA.height / 2);
        ev.mousePress(envoltura, ini.x, ini.y, Qt.LeftButton, Qt.NoModifier, 50);
        for (let k = 1; k <= 10; k++)
            ev.mouseMove(envoltura, ini.x + (pPor.x - ini.x) * k / 10, ini.y + (pPor.y - ini.y) * k / 10, 20, Qt.LeftButton, Qt.NoModifier);
        alPasar("por");
        for (let k = 1; k <= 4; k++)
            ev.mouseMove(envoltura, pPor.x + (pA.x - pPor.x) * k / 4, pPor.y + (pA.y - pPor.y) * k / 4, 20, Qt.LeftButton, Qt.NoModifier);
        alPasar("a");
        ventana.soltarEn = pA;
    }

    property var soltarEn: null

    function soltar() {
        ev.mouseRelease(envoltura, ventana.soltarEn.x, ventana.soltarEn.y, Qt.LeftButton, Qt.NoModifier, 50);
    }

    // El halo de destino de la casilla de un día: si está puesto.
    function halo(dia) {
        const c = ventana.uno("dia-" + dia);
        const h = c ? ventana.buscar(c, "destino")[0] : null;
        return h ? h.state === "sobre" : null;
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
        [50, () => {
                // Las horas y el color propio de una tarea, del panel a la agenda.
                const d = Formato.deTareas({
                    habilitado: true,
                    secciones: [
                        {
                            id: "general",
                            titulo: "General",
                            color: "#4a90e2",
                            tareas: [
                                {
                                    id: "a",
                                    plano: "Con hora",
                                    vence: "2026-10-30",
                                    horaInicio: "09:00",
                                    horaFin: "10:30"
                                },
                                {
                                    id: "b",
                                    plano: "Al revés",
                                    vence: "2026-10-30",
                                    horaInicio: "11:00",
                                    horaFin: "10:00"
                                },
                                {
                                    id: "c",
                                    plano: "Sin fin",
                                    vence: "2026-10-30",
                                    horaInicio: "08:00",
                                    horaFin: ""
                                },
                                {
                                    id: "d",
                                    plano: "Temprano",
                                    vence: "2026-10-30",
                                    horaInicio: "07:15",
                                    horaFin: "07:45"
                                },
                                {
                                    id: "e",
                                    plano: "Todo el día",
                                    vence: "2026-10-30"
                                }
                            ]
                        }
                    ]
                }, true, null);
                const por = {};
                d.eventos.forEach(e => por[e.id] = e);
                ventana.comprobar(por.a.todoElDia === false && por.a.hora === "09:00" && por.a.horaFin === "10:30" && por.a.color === "#4a90e2" && !("colorPropio" in por.a), "una tarea con horas las lleva, y su color es el de su sección (no hay color propio por tarea)");
                ventana.comprobar(por.b.todoElDia && por.b.hora === "" && por.b.horaFin === "" && por.c.todoElDia && por.c.hora === "" && por.e.todoElDia && por.e.horaFin === "", "  unas horas que no valen (el fin antes, o sin fin) son todo el día");
                const a = Formato.leer(JSON.stringify(d));
                const x = a.porDia["2026-10-30"].find(e => e.id === "a");
                ventana.comprobar(x.horaFin === "10:30" && x.color === "#4a90e2" && x.hora === "09:00" && !x.todoElDia, "  y pasan igual por el fichero");
                ventana.comprobar(ventana.igual(Formato.delDia(a, "2026-10-30", "2026-10-21").map(e => e.id), ["b", "c", "e", "d", "a"]), "  en el día, lo de todo el día primero y lo que tiene hora, por su hora", Formato.delDia(a, "2026-10-30", "2026-10-21").map(e => e.id).join(" "));
                const r = Formato.leer(JSON.stringify({
                    formato: 1,
                    eventos: [ventana.ev1("2026-10-30", "x", {
                            todoElDia: false,
                            hora: "10:00",
                            horaFin: "09:00",
                            color: "#12"
                        }), ventana.ev1("2026-10-30", "y", {
                            horaFin: "10:00"
                        })]
                }));
                ventana.comprobar(r.eventos[0].horaFin === "" && r.eventos[0].color === "" && r.eventos[1].horaFin === "", "  al leer el fichero, un fin que no va después de la hora (o sin hora) y un color roto se quitan");
                ventana.comprobar(Formato.motivoHoras("", "") === "" && Formato.motivoHoras("09:00", "10:00") === "" && Formato.motivoHoras("09:00", "") === "La hora de fin no es hh:mm" && Formato.motivoHoras("", "10:00") === "La hora de inicio no es hh:mm" && Formato.motivoHoras("10:00", "10:00") === "El fin tiene que ir después del inicio" && Formato.motivoHoras("24:00", "25:00") === "La hora de inicio no es hh:mm" && Formato.motivoHoras("09:00", "9:60") === "La hora de fin no es hh:mm", "las horas: las dos o ninguna, en hh:mm y el fin después del inicio");
                const n = ["9", "930", "0930", "9:5", "23:59", "12", "24", "9:60", "abc", ""].map(t => Formato.normalizarHora(t));
                ventana.comprobar(ventana.igual(n, ["09:00", "09:30", "09:30", "09:05", "23:59", "12:00", "24", "9:60", "abc", ""]), "lo que se teclea en una hora se entiende: «9» son las 09:00 y «930», las 09:30", n.join(" "));
                ventana.comprobar(Formato.sumarMinutos("09:00", 60) === "10:00" && Formato.sumarMinutos("23:30", 60) === "23:59" && Formato.sumarMinutos("00:10", -15) === "00:00" && Formato.sumarMinutos("x", 15) === "", "sumar minutos a una hora no pasa de 00:00 ni de 23:59");
                ventana.comprobar(Formato.PALETA === undefined && Formato.COLOR_CLASE === "#a78bfa" && /^#[0-9a-f]{6}$/.test(Formato.COLOR_CLASE), "ya no hay paleta de colores por tarea; el color de «Clase» está en un solo sitio (COLOR_CLASE)");
                const cat = e => Formato.categoria(Object.assign({ origen: "tarea", area: "", seccion: "", color: "" }, e));
                ventana.comprobar(ventana.igual(cat({ origen: "clase", seccion: "Clase" }), { nombre: "Clase", color: "#a78bfa" }) && ventana.igual(cat({ area: "Clase", seccion: "Otra", color: "#112233" }), { nombre: "Clase", color: "#a78bfa" }), "la categoría de una entrega de Aules (origen o área «Clase») es «Clase», con el color fijo, aunque la sección traiga otro");
                ventana.comprobar(ventana.igual(cat({ seccion: "Trabajo", color: "#4a90e2" }), { nombre: "Trabajo", color: "#4a90e2" }) && ventana.igual(cat({ seccion: "Casa" }), { nombre: "Casa", color: "" }) && ventana.igual(cat({ seccion: "Casa", color: "rojo" }), { nombre: "Casa", color: "" }) && cat({ area: "Taller" }).nombre === "Taller", "  la de cualquier otra es su sección y el color de la sección; sin color o con uno roto, sin barrita; sin sección, el área");
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
                const det = ventana.detalles();
                ventana.comprobar(f.length === 3 && det[0] === "venció 19 oct" && et[0] === "Trabajo" && et[1] === "Clase" && et[2] === "Trabajo", "  con lo vencido de antes delante, la entrega de Aules y lo hecho al final, cada una con su categoría a la derecha", f.length + " filas: " + det.join(", ") + " / " + et.join(", "));
                const b0 = ventana.buscar(f[0], "categoriaBarra")[0];
                const b1 = ventana.buscar(f[1], "categoriaBarra")[0];
                ventana.comprobar(f.length === 3 && b0.color.a === 0 && Qt.colorEqual(b1.color, Formato.COLOR_CLASE) && b0.width === 3, "  y a la izquierda, la barrita con el color de la categoría: sin color (la sección no lo trae) y el fijo de Clase");
                ventana.comprobar(f.length === 3 && Qt.colorEqual(ventana.hijos(f[0], "detalleFila")[0].color, Theme.prioMaxima) && ventana.hijos(f[2], "tituloFila")[0].font.strikeout, "  la vencida en rojo y la hecha tachada");
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
                ventana.comprobar(ventana.textoDe("tituloDia") === "Lunes 19 de octubre" && ventana.igual(ventana.detalles(), ["vencida"]), "un día pasado: su tarea sin hacer, marcada como vencida", ventana.etiquetas().join(", "));
                ventana.clicDia("2026-10-22");
            }],
        [300, () => {
                ventana.comprobar(ventana.textoDe("tituloDia") === "Mañana" && ventana.igual(ventana.detalles(), ["10:30"]), "mañana: una reunión con hora lleva la hora", ventana.etiquetas().join(", "));
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
                const actual = ventana.todos("opcionSelector").filter(o => o.actual).map(o => o.index);
                ventana.comprobar(ventana.uno("chipMes").texto === "Octubre 2026", "la cabecera lleva un chip con el mes y el año", ventana.uno("chipMes").texto);
                ventana.comprobar(cal.selectorAbierto && ventana.textoDe("anioSelector") === "2026" && ventana.todos("opcionSelector").length === 12, "  que abre un desplegable con el año arriba y los doce meses", ventana.textoDe("anioSelector"));
                ventana.comprobar(ventana.igual(actual, [9]) && ventana.igual(ventana.todos("opcionSelector").map(o => o.children[0].text).slice(0, 3), ["Ene", "Feb", "Mar"]), "  con el mes que se mira resaltado", actual.join(" "));
                ventana.captura("7-selector");
                ventana.clicEn(ventana.todos("opcionSelector")[10]);
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 1 && !cal.selectorAbierto && cal.shown.getMonth() === 10, "elegir noviembre cambia de mes y cierra el desplegable", String(cal.monthOffset));
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [500, () => {
                ventana.clicEn(ventana.uno("anioSiguiente"));
                ventana.clicEn(ventana.uno("anioSiguiente"));
            }],
        [300, () => {
                ventana.comprobar(cal.selectorAbierto && ventana.textoDe("anioSelector") === "2028" && cal.monthOffset === 1, "las flechitas cambian el año del desplegable sin cambiar todavía de mes", ventana.textoDe("anioSelector"));
                ventana.comprobar(ventana.todos("opcionSelector").filter(o => o.actual).length === 0, "  y en otro año no hay mes resaltado");
                ventana.captura("8-selector-2028");
                ventana.clicEn(ventana.todos("opcionSelector")[10]);
            }],
        [300, () => {
                ventana.comprobar(cal.shown.getFullYear() === 2028 && cal.shown.getMonth() === 10 && cal.monthOffset === 25 && !cal.selectorAbierto, "elegir un mes lleva a ese mes de ese año", String(cal.monthOffset));
                ventana.comprobar(ventana.uno("chipMes").texto === "Noviembre 2028", "  y el chip lo dice", ventana.uno("chipMes").texto);
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [500, () => {
                ventana.comprobar(ventana.textoDe("anioSelector") === "2028", "al abrirlo otra vez, el año es el que se mira");
                ventana.clicEn(ventana.uno("anioAnterior"));
            }],
        [300, () => {
                ventana.comprobar(ventana.textoDe("anioSelector") === "2027" && cal.monthOffset === 25, "  la flechita izquierda retrocede un año");
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [400, () => {
                ventana.comprobar(!cal.selectorAbierto && cal.monthOffset === 25, "pulsar otra vez el chip lo cierra sin cambiar nada");
                ventana.clicEn(ventana.uno("mesAnterior"));
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 24 && cal.shown.getMonth() === 9, "la flecha izquierda retrocede un mes");
                ventana.clicEn(ventana.uno("mesSiguiente"));
            }],
        [300, () => {
                ventana.comprobar(cal.monthOffset === 25, "la flecha derecha avanza un mes");
                ventana.anchoChip = ventana.uno("chipMes").width;
                ventana.xFlecha = ventana.uno("mesSiguiente").x;
                cal.monthOffset = 19;
            }],
        [300, () => {
                const c = ventana.uno("chipMes");
                ventana.comprobar(c.texto === "Mayo 2028" && c.width === ventana.anchoChip && ventana.uno("mesSiguiente").x === ventana.xFlecha, "el chip mide lo mismo con un mes corto (Mayo) que con uno largo (Noviembre), y la flecha no se mueve", c.width + " vs " + ventana.anchoChip);
                cal.monthOffset = 23;
            }],
        [300, () => {
                const c = ventana.uno("chipMes");
                ventana.comprobar(c.texto === "Septiembre 2028" && c.width === ventana.anchoChip && ventana.uno("mesSiguiente").x === ventana.xFlecha, "  ni con el más largo (Septiembre)", c.width + " vs " + ventana.anchoChip);
                ventana.clicEn(ventana.uno("botonHoy"));
            }],
        [300, () => {
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [500, () => {
                const c = ventana.uno("dia-2026-10-25");
                const pop = ventana.uno("selector");
                ventana.comprobar(cal.selectorAbierto && !pop.contains(c.mapToItem(pop, c.width / 2, c.height / 2)), "(desplegable abierto, y el 25 queda fuera)");
                ventana.clicDia("2026-10-25");
            }],
        [400, () => {
                ventana.comprobar(!cal.selectorAbierto && cal.elegido === "", "pulsar fuera del desplegable lo cierra sin elegir un día");
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
                ventana.comprobar(ventana.igual(ventana.detalles(), ["venció 19 oct", ""]) && ventana.igual(ventana.etiquetas(), ["Trabajo", "Clase"]), "  y la lista de hoy, con la entrega de Aules", ventana.detalles().join(", ") + " / " + ventana.etiquetas().join(", "));
                ventana.captura("6-del-cajon");
            }],
        [200, () => {
                apiFalsa.conexion = "sin-credenciales";
                apiFalsa.tareas = null;
            }],
        [500, () => {
                ventana.comprobar(ventana.todos("punto").length === 0 && ventana.uno("agendaDia") === null, "y si el cajón borra la agenda, el calendario vuelve a la rejilla sola");
            }],
        // --- El cliente del panel, de verdad, contra el panel falso ---
        [200, () => {
                ventana.comprobar(cliente.estado === "inactivo" && cliente.datos === null && !cliente.puedeEscribir, "el cliente del panel no hace nada hasta que se le pide");
                ventana.comprobar(cliente.efectiva("low", "2026-10-22", "2026-10-21") === "highest" && cliente.efectiva("low", "2026-10-24", "2026-10-21") === "high" && cliente.efectiva("", "2026-10-28", "2026-10-21") === "medium" && cliente.efectiva("high", "2026-10-26", "2026-10-21") === "high" && cliente.efectiva("lowest", "2026-11-30", "2026-10-21") === "lowest" && cliente.efectiva("low", "", "2026-10-21") === "low", "la prioridad de hoy sube cerca de la fecha, como la calcula el panel");
                let r = null;
                cliente.crear({
                    texto: "Comprar pilas",
                    dia: "2026-10-30"
                }, ok => r = ok);
                ventana.comprobar(r === false && !cliente.escribiendo, "  sin conexión no se crea nada (y contesta enseguida)");
                cliente.refrescar(true);
            }],
        [900, () => {
                const d = cliente.datos;
                const c1 = ventana.porId(d, "c1");
                const g2 = ventana.porId(d, "g2");
                const g3 = ventana.porId(d, "g3");
                ventana.comprobar(cliente.estado === "conectado" && d !== null && d.eventos.length === 4, "con el llavero (de mentira) lee las tareas del panel falso", cliente.estado + ", " + (d ? d.eventos.length : "sin datos"));
                ventana.comprobar(g3 !== null && !g3.todoElDia && g3.hora === "16:00" && g3.horaFin === "17:00" && ventana.porId(d, "g1").todoElDia && g3.color === "#e67c73" && !("colorPropio" in g3), "  con las horas (time_start, time_end) y el color de su sección; el color suelto de la tarea (color) no entra");
                ventana.comprobar(g3 !== null && g3.texto.indexOf("**") > 0 && g3.titulo.indexOf("**") < 0, "  y su texto tal cual, con el Markdown, aparte del título, que va sin él");
                ventana.comprobar(c1 !== null && c1.claudeOff === true && ventana.porId(d, "g1").claudeOff === false, "  cada evento lleva su 🚫🤖 (claudeOff)");
                ventana.comprobar(g2 !== null && g2.prioridadPropia === "baja" && g2.prioridad === "maxima", "  y la prioridad que tiene puesta, además de la de hoy", g2 ? g2.prioridadPropia + " / " + g2.prioridad : "");
                ventana.comprobar(c1 !== null && c1.prioridadPropia === "" && Formato.delDia(d, "2026-10-30", "2026-10-21").every(e => "claudeOff" in e), "  sin prioridad, vacía; y los campos pasan a la lista del día");
                ventana.comprobar(cliente.seccionPorDefecto() === "general", "lo que se cree va a General, aunque no sea la primera sección");
                const rs = [];
                cliente.crear({
                    texto: "   ",
                    dia: "2026-10-30"
                }, ok => rs.push(ok));
                cliente.crear({
                    texto: "Algo",
                    dia: "30/10/2026"
                }, ok => rs.push(ok));
                cliente.prioridad("g1", "urgente", ok => rs.push(ok));
                cliente.claudeOff("no-existe", true, ok => rs.push(ok));
                cliente.mover("g1", "", ok => rs.push(ok));
                ventana.comprobar(ventana.igual(rs, [false, false, false, false, false]) && !cliente.escribiendo, "un texto vacío, una fecha rota, una prioridad que no existe o una tarea que no está no se mandan");
                const rh = [];
                const errores = [];
                cliente.crear({
                    texto: "Algo",
                    dia: "2026-10-30",
                    horaInicio: "10:00",
                    horaFin: "09:00"
                }, ok => {
                    rh.push(ok);
                    errores.push(cliente.error);
                });
                cliente.crear({
                    texto: "Algo",
                    dia: "2026-10-30",
                    horaInicio: "10:00"
                }, ok => rh.push(ok));
                cliente.crear({
                    texto: "Algo",
                    dia: "2026-10-30",
                    prioridad: "urgente"
                }, ok => {
                    rh.push(ok);
                    errores.push(cliente.error);
                });
                cliente.cambiar("g1", {
                    horaInicio: "10:00"
                }, ok => rh.push(ok));
                cliente.cambiar("g1", {
                    color: "#12345"
                }, ok => rh.push(ok));
                cliente.cambiar("g1", {}, ok => rh.push(ok));
                ventana.comprobar(ventana.igual(rh, [false, false, false, false, false, false]) && !cliente.escribiendo, "  ni unas horas al revés o sin pareja, ni una prioridad que no existe, ni un color (ya no se manda: una edición solo con color queda vacía), ni una edición vacía");
                ventana.comprobar(ventana.igual(errores, ["El fin tiene que ir después del inicio", "Prioridad no válida"]), "  y el cliente dice por qué", errores.join(" | "));
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.comprobar(ventana.registro.length === 1 && ventana.registro[0].metodo === "GET" && ventana.registro.every(x => x.auth), "  (al panel solo le ha llegado la lectura, y con las credenciales)", ventana.registro.length + " peticiones");
                shellFalso.tareas = cliente;
                shellFalso.agenda = Qt.binding(() => cliente.datos);
                cal.volverAHoy();
            }],
        // Crear, en la hoja.
        [300, () => {
                ventana.ajustar({
                    retraso: 500
                });
                ventana.dobleClicDia("2026-10-30");
            }],
        [300, () => {
                const h = ventana.hoja();
                const t = ventana.titulo();
                const prios = ventana.enHoja("prioridadPunto");
                ventana.comprobar(cal.hojaModo === "nueva" && h !== null && t !== null && t.activeFocus, "doble clic en un día abre la hoja «Nueva tarea», con el teclado en el título");
                ventana.comprobar(ventana.textoDe("tituloHoja") === "Nueva tarea" && ventana.textoDe("diaHoja") === "vie 30 oct" && cal.elegido === "2026-10-30", "  para ese día, que pasa a ser el elegido", ventana.textoDe("diaHoja"));
                ventana.comprobar(ventana.uno("agendaDia") === null, "  en el sitio de la lista del día, que no se ve mientras");
                ventana.comprobar(h !== null && h.todoElDia && ventana.unoHoja("horasHoja") === null && ventana.uno("todoElDia").activo, "  de todo el día, y sin las horas a la vista");
                ventana.comprobar(ventana.enHoja("colorPunto").length === 0 && ventana.unoHoja("colorHoja") === null && !("color" in h), "  sin selector de color (ya no hay color propio por tarea)");
                ventana.comprobar(ventana.unoHoja("eliminarHoja") === null, "  y sin «Eliminar», que solo está al editar");
                ventana.comprobar(prios.length === 5 && ventana.igual(prios.map(p => p.elegido), [false, false, true, false, false]) && ventana.textoDe("prioridadHoja") === "Media" && !ventana.uno("claudeOffHoja").activo, "  prioridad media y el 🚫🤖 apagado");
                ventana.comprobar(!ventana.uno("guardarHoja").activo && ventana.textoDe("avisoHoja") === "", "  sin título no se puede guardar, pero no se regaña antes de intentarlo");
                ev.keyClick(Qt.Key_P, Qt.NoModifier, -1);
                ventana.comprobar(t !== null && t.text === "p", "  lo que se teclea va al título");
                ventana.captura("11-hoja-nueva");
            }],
        [200, () => {
                ventana.titulo().text = "";
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [200, () => {
                ventana.comprobar(cal.hojaModo === "nueva" && !cal.guardando && ventana.textoDe("avisoHoja") === "Falta el título", "Intro sin título no guarda: dice que falta", ventana.textoDe("avisoHoja"));
                ventana.titulo().text = "Clase de yoga";
                ventana.clicEn(ventana.uno("todoElDia"));
            }],
        [300, () => {
                const h = ventana.hoja();
                ventana.comprobar(!h.todoElDia && ventana.unoHoja("horasHoja") !== null && ventana.campoHora("horaInicio").text === "09:00" && ventana.campoHora("horaFin").text === "10:00", "quitar «Todo el día» enseña las horas: de 09:00 a 10:00", ventana.campoHora("horaInicio").text + "–" + ventana.campoHora("horaFin").text);
                ventana.comprobar(ventana.textoDe("avisoHoja") === "" && ventana.uno("guardarHoja").activo, "  y con título ya se puede guardar");
                ventana.campoHora("horaFin").text = "08:30";
            }],
        [200, () => {
                ventana.comprobar(ventana.textoDe("avisoHoja") === "El fin tiene que ir después del inicio" && !ventana.uno("guardarHoja").activo && ventana.campoHora("horaFin").mal && !ventana.campoHora("horaInicio").mal, "un fin antes del inicio no deja guardar, dice por qué y marca el campo", ventana.textoDe("avisoHoja"));
                ventana.captura("11b-hoja-horas-mal");
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [200, () => {
                ventana.campoHora("horaFin").text = "25:00";
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.comprobar(ventana.posts() === 0 && !cal.guardando && cal.hojaModo === "nueva", "  ni Intro manda nada", ventana.posts() + " escrituras");
                ventana.comprobar(ventana.textoDe("avisoHoja") === "La hora de fin no es hh:mm" && !ventana.uno("guardarHoja").activo, "una hora que no existe tampoco", ventana.textoDe("avisoHoja"));
                ventana.campoHora("horaInicio").text = "9";
                ventana.campoHora("horaFin").text = "1030";
                ventana.clicEn(ventana.enHoja("prioridadPunto")[1]);
                ventana.clicEn(ventana.uno("claudeOffHoja"));
            }],
        [300, () => {
                const h = ventana.hoja();
                ventana.comprobar(ventana.textoDe("avisoHoja") === "" && ventana.uno("guardarHoja").activo && h.horaInicio === "09:00" && h.horaFin === "10:30", "«9» y «1030» valen: de 09:00 a 10:30", h.horaInicio + "–" + h.horaFin);
                ventana.comprobar(h.prioridad === "high" && ventana.textoDe("prioridadHoja") === "Alta" && h.claudeOff && ventana.uno("claudeOffHoja").activo, "  y la prioridad y el 🚫🤖 se eligen en la misma hoja");
                ventana.comprobar(ventana.titulo().activeFocus, "  sin que el título pierda el teclado");
                ventana.captura("11c-hoja-lista");
            }],
        [200, () => ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1)],
        [150, () => {
                ventana.comprobar(cal.guardando && ventana.hoja() !== null && ventana.hoja().ocupada && ventana.titulo().readOnly, "Intro la manda, y la hoja espera al panel (crear no es optimista)");
                ventana.comprobar(ventana.campoHora("horaInicio").text === "09:00" && ventana.campoHora("horaFin").text === "10:30", "  con las horas escritas como hh:mm");
            }],
        [800, () => {
                const b = ventana.barraDe("Clase de yoga");
                const rojo = Qt.color("#e67c73");
                ventana.comprobar(!cal.guardando && cal.hojaModo === "" && ventana.hoja() === null, "  al contestar, la hoja se cierra");
                ventana.comprobar(ventana.uno("agendaDia") !== null && ventana.textoDe("avisoMover") === "Añadida al 30 oct", "  vuelve la lista del día, y avisa", ventana.textoDe("avisoMover"));
                ventana.comprobar(ventana.detalleDe("Clase de yoga") === "09:00–10:30" && ventana.etiquetaDe("Clase de yoga") === "General", "  la tarea sale con su hora y, a la derecha, su categoría", ventana.detalleDe("Clase de yoga") + " / " + ventana.etiquetaDe("Clase de yoga"));
                ventana.comprobar(b !== null && b.visible && Qt.colorEqual(b.color, rojo) && b.width > 0 && b.height > 8, "  y una barrita con el color de esa categoría (el de la sección General)");
                const bc = ventana.barraDe("MIA: Tarea quinta");
                ventana.comprobar(ventana.etiquetaDe("MIA: Tarea quinta") === "Clase" && bc !== null && Qt.colorEqual(bc.color, Formato.COLOR_CLASE) && ventana.detalleDe("MIA: Tarea quinta") === "", "  la entrega de Aules, categoría «Clase» con el color fijo de Clase, sin hora");
                ventana.comprobar(ventana.igual(ventana.titulos(), ["Revisar el informe", "MIA: Tarea quinta", "Clase de yoga", "Tutoría de FOL"]), "  las del día, las de todo el día primero y las que tienen hora, por su hora");
                ventana.comprobar(ventana.detalleDe("Tutoría de FOL") === "16:00–17:00" && ventana.etiquetaDe("Tutoría de FOL") === "General" && Qt.colorEqual(ventana.barraDe("Tutoría de FOL").color, rojo), "  (la que trae el panel con hora, igual: el color es el de la categoría, no el suelto de la tarea)");
                ventana.captura("11d-fila-hora-categoria");
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.metodo === "POST" && r.ruta === "/api/tareas" && r.auth === true, "  con POST /api/tareas", r.metodo + " " + r.ruta);
                ventana.comprobar(ventana.mismo(r.cuerpo, {
                    seccion: "general",
                    texto: "Clase de yoga",
                    area: "",
                    fecha: "2026-10-30",
                    prioridad: "high",
                    claude_off: true,
                    hora_inicio: "09:00",
                    hora_fin: "10:30"
                }), "  y el cuerpo exacto: el texto, el día, la prioridad, el 🚫🤖 y las dos horas, sin color", Object.keys(r.cuerpo || {}).sort().join(","));
                const n = ventana.porTitulo("Clase de yoga");
                ventana.comprobar(n !== null && n.id !== "" && n.hora === "09:00" && n.horaFin === "10:30" && n.prioridadPropia === "alta" && n.claudeOff === true, "  y vuelve del panel con su id y todo eso");
                ventana.ajustar({
                    retraso: 0
                });
                ventana.dobleClicDia("2026-10-30");
            }],
        [300, () => {
                const h = ventana.hoja();
                ventana.comprobar(h !== null && ventana.titulo().text === "" && h.todoElDia && h.prioridad === "medium" && !h.claudeOff, "otra hoja nueva empieza de cero");
                ventana.titulo().text = "Comprar pilas";
                ventana.filas0 = cliente.datos.eventos.length;
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [400, () => {
                ventana.comprobar(cal.hojaModo === "" && cliente.datos.eventos.length === ventana.filas0 + 1 && ventana.etiquetaDe("Comprar pilas") === "General" && ventana.detalleDe("Comprar pilas") === "" && Qt.colorEqual(ventana.barraDe("Comprar pilas").color, "#e67c73"), "una de todo el día sale con su sección a la derecha y la barrita de su color", ventana.etiquetaDe("Comprar pilas"));
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                const c = r.cuerpo || {};
                ventana.comprobar(ventana.igual(Object.keys(c).sort(), ["area", "claude_off", "fecha", "prioridad", "seccion", "texto"]) && c.seccion === "general" && c.texto === "Comprar pilas" && c.area === "" && c.fecha === "2026-10-30" && c.prioridad === "medium" && c.claude_off === false, "  con el cuerpo de siempre (sin horas): la sección, el texto, el día, sin área, prioridad media y el 🚫🤖 apagado", Object.keys(c).sort().join(","));
                const n = ventana.porTitulo("Comprar pilas");
                ventana.comprobar(n !== null && n.id !== "" && n.claudeOff === false && n.prioridadPropia === "media" && n.todoElDia, "  y vuelve con su id, prioridad media, sin 🚫🤖 y de todo el día");
                ventana.dobleClicDia("2026-10-30");
            }],
        [300, () => {
                ventana.comprobar(ventana.hoja() !== null, "(otra vez la hoja)");
                ventana.titulo().text = "No la quiero";
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.hoja() === null && ventana.uno("agendaDia") !== null, "Escape cierra la hoja sin guardar, y vuelve la lista");
                ventana.dobleClicDia("2026-10-30");
            }],
        [300, () => ventana.clicEn(ventana.uno("cancelarHoja"))],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.hoja() === null, "Cancelar también");
                ventana.dobleClicDia("2026-10-30");
            }],
        [300, () => ventana.clicEn(ventana.uno("cerrarHoja"))],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.hoja() === null, "  y la ✕");
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.comprobar(ventana.posts() === 2, "  (ni una petición más)", ventana.posts() + " escrituras");
                // El mensaje más largo del panel de verdad.
                ventana.ajustar({
                    fallos: [
                        {
                            estado: 422,
                            error: "La hora de inicio y la de fin van juntas: las dos, o ninguna para todo el día."
                        }
                    ]
                });
                ventana.dobleClicDia("2026-10-30");
            }],
        [300, () => {
                ventana.titulo().text = "Otra";
                ventana.clicEn(ventana.uno("todoElDia"));
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [500, () => {
                const h = ventana.hoja();
                const t = ventana.titulo();
                ventana.comprobar(cal.hojaModo === "nueva" && h !== null && t.text === "Otra" && !h.todoElDia && ventana.campoHora("horaInicio").text === "09:00" && !t.readOnly && t.activeFocus && !cal.guardando, "si el panel no la acepta (422), la hoja se queda abierta con lo tecleado");
                ventana.comprobar(ventana.textoDe("avisoHoja") === "La hora de inicio y la de fin van juntas: las dos, o ninguna para todo el día." && !ventana.unoHoja("avisoHoja").truncated, "  y dice el porqué del panel, entero aunque sea largo", ventana.textoDe("avisoHoja"));
                ventana.comprobar(h !== null && h.width === cal.width - 2 * Theme.pad && cal.width === cal.implicitWidth, "  sin ensanchar el calendario", h ? h.width + " de " + (cal.width - 2 * Theme.pad) : "");
                ventana.captura("12-hoja-422");
            }],
        [200, () => {
                ventana.titulo().text = "Otra cosa";
                ventana.comprobar(ventana.textoDe("avisoHoja") === "", "al tocar algo, el aviso del panel se va");
                ventana.clicDia("2026-10-31");
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "nueva" && cal.hojaDia === "2026-10-31" && ventana.textoDe("diaHoja") === "sáb 31 oct" && ventana.titulo().text === "Otra cosa" && cal.elegido === "2026-10-31", "con la hoja abierta, pulsar otro día la lleva a ese día sin perder lo tecleado", ventana.textoDe("diaHoja"));
                ventana.clicDia("2026-10-31");
            }],
        [300, () => {
                ventana.comprobar(cal.hojaDia === "2026-10-31" && cal.elegido === "2026-10-31", "  y pulsarlo otra vez no la lleva a hoy");
                ventana.dobleClicDia("2026-10-29");
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "nueva" && cal.hojaDia === "2026-10-29" && ventana.titulo().text === "Otra cosa", "  ni un doble clic abre otra: la misma, en ese día");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "", "(cerrada)");
                ventana.clicDia("2026-10-30");
            }],
        // La prioridad.
        [300, () => {
                ventana.ajustar({
                    retraso: 500
                });
                ventana.clicEn(ventana.puntoDe("Revisar el informe"));
            }],
        [450, () => {
                const ops = ventana.todos("opcionPrioridad");
                const m = ventana.uno("menuPrioridad");
                ventana.comprobar(cal.menuDe !== null && cal.menuDe.id === "g1" && ops.length === 5, "pulsar el punto de una tarea abre el menú de prioridades", ops.length + " opciones");
                ventana.comprobar(ventana.igual(ops.map(o => ventana.hijos(o, "etiquetaPrioridad")[0].text), ["Máxima", "Alta", "Media", "Baja", "Mínima"]), "  las cinco, de la más alta a la más baja");
                ventana.comprobar(ventana.igual(ops.map(o => ventana.hijos(o, "marcaPrioridad").length), [0, 0, 0, 1, 0]), "  con la marca en la que tiene puesta (baja)");
                ventana.comprobar(m !== null && m.y >= 0 && m.y + m.height <= cal.height && m.x >= 0 && m.x + m.width <= cal.width, "  y el menú cabe en el calendario", m ? Math.round(m.x) + "," + Math.round(m.y) : "");
                ventana.captura("13-prioridad");
            }],
        // Una captura sale en el siguiente fotograma: elegir, en otro paso.
        [200, () => ventana.clicEn(ventana.todos("opcionPrioridad")[1])],
        [150, () => {
                const e = ventana.porId(cliente.datos, "g1");
                ventana.comprobar(cal.menuDe === null && e.prioridadPropia === "alta" && Qt.colorEqual(ventana.colorPunto("Revisar el informe"), Theme.prioAlta) && cliente.escribiendo, "elegir una la cambia al momento, antes de que conteste el panel (optimista)");
            }],
        [800, () => {
                ventana.comprobar(!cliente.escribiendo && ventana.porId(cliente.datos, "g1").prioridadPropia === "alta" && ventana.textoDe("avisoMover") === "Prioridad alta", "  el panel la confirma y se avisa", ventana.textoDe("avisoMover"));
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.metodo === "POST" && r.ruta === "/api/tareas/g1" && ventana.igual(r.cuerpo, {
                    prioridad: "high"
                }), "  con POST /api/tareas/{id} y solo { prioridad: \"high\" }", JSON.stringify(r.cuerpo));
                ventana.ajustar({
                    retraso: 300,
                    fallos: [
                        {
                            estado: 500
                        }
                    ]
                });
                ventana.clicEn(ventana.puntoDe("Revisar el informe"));
            }],
        [450, () => ventana.clicEn(ventana.todos("opcionPrioridad")[4])],
        [100, () => {
                ventana.comprobar(ventana.porId(cliente.datos, "g1").prioridadPropia === "minima" && Qt.colorEqual(ventana.colorPunto("Revisar el informe"), Theme.prioMinima), "(mínima mientras el panel contesta)");
            }],
        [600, () => {
                ventana.comprobar(ventana.porId(cliente.datos, "g1").prioridadPropia === "alta" && Qt.colorEqual(ventana.colorPunto("Revisar el informe"), Theme.prioAlta), "si el panel falla, la prioridad vuelve a la de antes");
                ventana.comprobar(ventana.textoDe("avisoMover") === "No se pudo cambiar la prioridad (HTTP 500)", "  y lo dice", ventana.textoDe("avisoMover"));
                ventana.comprobar(ventana.uno("agendaDia").width === cal.width - 2 * Theme.pad && ventana.uno("avisoMover").truncated, "  recortado: un aviso largo no ensancha el calendario", ventana.uno("agendaDia").width + " de " + (cal.width - 2 * Theme.pad));
                ventana.ajustar({
                    retraso: 0
                });
                ventana.clicEn(ventana.puntoDe("Revisar el informe"));
            }],
        [450, () => {
                ventana.comprobar(cal.menuDe !== null, "(menú abierto)");
                ventana.clicDia("2026-10-23");
            }],
        [400, () => {
                ventana.comprobar(cal.menuDe === null && cal.elegido === "2026-10-30", "pulsar fuera del menú lo cierra sin elegir un día");
                ventana.clicEn(ventana.puntoDe("Revisar el informe"));
            }],
        [450, () => ventana.clicEn(ventana.todos("opcionPrioridad")[1])],
        [300, () => {
                ventana.comprobar(cal.menuDe === null && !cliente.escribiendo, "elegir la que ya tiene solo cierra el menú");
                ventana.leerRegistro();
            }],
        // El 🚫🤖.
        [300, () => {
                ventana.comprobar(ventana.registro.filter(x => x.metodo === "POST").length === 5, "  (sin pedirle nada al panel)", ventana.registro.filter(x => x.metodo === "POST").length + " escrituras");
                const f = ventana.filaDe("Revisar el informe");
                const p = f.mapToItem(envoltura, 60, f.height / 2);
                ev.mouseMove(envoltura, p.x, p.y, 20, Qt.NoButton, Qt.NoModifier);
            }],
        [400, () => {
                const r1 = ventana.robotDe("Revisar el informe");
                const r2 = ventana.robotDe("MIA: Tarea quinta");
                const r3 = ventana.robotDe("Comprar pilas");
                ventana.comprobar(r1.opacity > 0.3 && r1.opacity < 1, "el 🚫🤖 apagado sale tenue al pasar el ratón por la fila", String(r1.opacity));
                ventana.comprobar(r3.opacity === 0, "  y en las demás filas no se ve", String(r3.opacity));
                ventana.comprobar(r2.opacity === 1 && Qt.colorEqual(r2.color, Theme.strong), "  encendido, se ve siempre");
                ventana.captura("14-claude-off");
                // Los ajustes del panel, un paso antes de la escritura: si no,
                // pueden llegarle después que ella.
                ventana.ajustar({
                    retraso: 400
                });
            }],
        [200, () => ventana.clicEn(ventana.robotDe("Revisar el informe"))],
        [150, () => {
                ventana.comprobar(ventana.porId(cliente.datos, "g1").claudeOff === true && cliente.escribiendo, "pulsarlo lo enciende al momento (optimista)");
            }],
        [700, () => {
                ventana.comprobar(!cliente.escribiendo && ventana.porId(cliente.datos, "g1").claudeOff === true && ventana.robotDe("Revisar el informe").opacity === 1, "  y sigue encendido cuando el panel contesta", String(ventana.robotDe("Revisar el informe").opacity));
                ventana.comprobar(ventana.textoDe("avisoMover") === "Claude no la hará", "  y avisa", ventana.textoDe("avisoMover"));
                ventana.ajustar({
                    retraso: 0
                });
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.ruta === "/api/tareas/g1" && ventana.igual(r.cuerpo, {
                    claude_off: true
                }), "  con { claude_off: true }", JSON.stringify(r.cuerpo));
                ventana.clicEn(ventana.robotDe("Revisar el informe"));
            }],
        [400, () => {
                ventana.comprobar(ventana.porId(cliente.datos, "g1").claudeOff === false && ventana.textoDe("avisoMover") === "Claude ya puede hacerla", "pulsarlo otra vez lo apaga", ventana.textoDe("avisoMover"));
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, {
                    claude_off: false
                }), "  con { claude_off: false }");
            }],
        // Mover, con el cliente de verdad, y el halo del día destino.
        [200, () => {
                const vistos = {};
                ventana.arrastrar("Comprar pilas", "2026-10-30", "2026-10-31", cuando => {
                    vistos[cuando] = [ventana.halo("2026-10-30"), ventana.halo("2026-10-31")];
                });
                ventana.comprobar(ventana.igual(vistos.por, [false, false]), "arrastrando, el día de la propia tarea no se resalta", JSON.stringify(vistos.por));
                ventana.comprobar(ventana.igual(vistos.a, [false, true]), "  y el día de destino sí", JSON.stringify(vistos.a));
            }],
        [400, () => ventana.captura("15-halo")],
        [200, () => ventana.soltar()],
        [600, () => {
                const n = ventana.porTitulo("Comprar pilas");
                ventana.comprobar(n !== null && n.dia === "2026-10-31" && ventana.textoDe("avisoMover") === "Movida al 31 oct", "al soltarla se mueve", ventana.textoDe("avisoMover"));
                ventana.comprobar(ventana.halo("2026-10-31") === false, "  y el halo se va");
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.metodo === "POST" && /^\/api\/tareas\/n\d+$/.test(r.ruta) && ventana.igual(r.cuerpo, {
                    fecha: "2026-10-31"
                }), "  con POST /api/tareas/{id} y { fecha }", JSON.stringify(r.cuerpo));
                ventana.clicEn(ventana.tituloDe("Revisar el informe"));
            }],
        // Editar, en la hoja.
        [300, () => {
                const h = ventana.hoja();
                const t = ventana.titulo();
                ventana.comprobar(cal.hojaModo === "editar" && h !== null && t.activeFocus && ventana.textoDe("tituloHoja") === "Editar tarea" && ventana.textoDe("diaHoja") === "vie 30 oct", "pulsar el título de una tarea abre la hoja «Editar tarea», con el teclado en el título");
                ventana.comprobar(t.text === "Revisar el informe" && h.todoElDia && h.prioridad === "high" && !h.claudeOff && ventana.uno("guardarHoja").activo, "  rellena con lo suyo: el título, de todo el día, prioridad alta y sin 🚫🤖");
                ventana.comprobar(ventana.uno("agendaDia") === null, "  también en el sitio de la lista");
                ventana.captura("16-hoja-editar");
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.posts0 = ventana.posts();
                ventana.clicEn(ventana.uno("guardarHoja"));
            }],
        [300, () => ventana.leerRegistro()],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.posts() === ventana.posts0, "guardar sin cambiar nada solo la cierra, sin pedirle nada al panel", ventana.posts() - ventana.posts0 + " escrituras");
                ventana.ajustar({
                    retraso: 400
                });
            }],
        [200, () => ventana.clicEn(ventana.tituloDe("Revisar el informe"))],
        [300, () => {
                ventana.clicEn(ventana.enHoja("prioridadPunto")[3]);
                ventana.clicEn(ventana.uno("todoElDia"));
                ventana.campoHora("horaInicio").text = "11:00";
                ventana.campoHora("horaFin").text = "12:15";
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [150, () => {
                const e = ventana.porId(cliente.datos, "g1");
                ventana.comprobar(cal.guardando && cliente.escribiendo && ventana.hoja() !== null && e.hora === "11:00" && e.horaFin === "12:15" && e.prioridadPropia === "baja", "guardar una edición la cambia al momento (optimista), con la hoja esperando al panel");
            }],
        [700, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.textoDe("avisoMover") === "Guardada", "  al contestar, se cierra y avisa", ventana.textoDe("avisoMover"));
                ventana.comprobar(ventana.detalleDe("Revisar el informe") === "11:00–12:15" && Qt.colorEqual(ventana.colorPunto("Revisar el informe"), Theme.prioBaja), "  la fila lleva la hora nueva, y el punto, la prioridad", ventana.detalleDe("Revisar el informe"));
                ventana.comprobar(ventana.igual(ventana.titulos(), ["MIA: Tarea quinta", "Clase de yoga", "Revisar el informe", "Tutoría de FOL"]), "  y se coloca por su hora");
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.metodo === "POST" && r.ruta === "/api/tareas/g1" && ventana.mismo(r.cuerpo, {
                    prioridad: "low",
                    hora_inicio: "11:00",
                    hora_fin: "12:15"
                }), "  con POST /api/tareas/{id} y solo lo que cambió: la prioridad y las dos horas", JSON.stringify(r.cuerpo));
                ventana.ajustar({
                    retraso: 0
                });
            }],
        [200, () => ventana.clicEn(ventana.tituloDe("Tutoría de FOL"))],
        [300, () => {
                const h = ventana.hoja();
                ventana.comprobar(h !== null && ventana.titulo().text === "Tutoría de **FOL**" && !h.todoElDia && ventana.campoHora("horaInicio").text === "16:00" && ventana.campoHora("horaFin").text === "17:00", "una con hora la trae, y el texto, el de la nota, con su Markdown");
                ventana.comprobar(h !== null && h.prioridad === "high" && ventana.enHoja("colorPunto").length === 0, "  y su prioridad, sin selector de color aunque el panel guarde uno suelto en la tarea");
                ventana.captura("17-hoja-editar-hora");
            }],
        [200, () => {
                ventana.clicEn(ventana.uno("todoElDia"));
                ventana.titulo().text = "Tutoría de **FOL** con tutora";
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [400, () => {
                const b = ventana.barraDe("Tutoría de FOL con tutora");
                ventana.comprobar(cal.hojaModo === "" && ventana.etiquetaDe("Tutoría de FOL con tutora") === "General" && ventana.detalleDe("Tutoría de FOL con tutora") === "" && b !== null && Qt.colorEqual(b.color, "#e67c73"), "dejarla de todo el día le quita la hora y le deja la barrita de su categoría", ventana.etiquetaDe("Tutoría de FOL con tutora"));
                ventana.leerRegistro();
            }],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.ruta === "/api/tareas/g3" && ventana.mismo(r.cuerpo, {
                    texto: "Tutoría de **FOL** con tutora",
                    hora_inicio: "",
                    hora_fin: ""
                }), "  con el texto nuevo y las dos horas vacías, y nada más (ni rastro de color)", Object.keys(r.cuerpo || {}).sort().join(","));
                ventana.ajustar({
                    fallos: [
                        {
                            estado: 422,
                            error: "Prioridad no válida."
                        }
                    ]
                });
            }],
        [200, () => ventana.clicEn(ventana.tituloDe("Clase de yoga"))],
        [300, () => {
                ventana.clicEn(ventana.enHoja("prioridadPunto")[4]);
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [400, () => {
                const h = ventana.hoja();
                ventana.comprobar(cal.hojaModo === "editar" && h !== null && h.prioridad === "lowest" && !cal.guardando && ventana.textoDe("avisoHoja") === "Prioridad no válida.", "si el panel rechaza una edición, la hoja se queda con lo elegido y el porqué", ventana.textoDe("avisoHoja"));
                ventana.comprobar(ventana.porTitulo("Clase de yoga").prioridadPropia === "alta", "  y la tarea vuelve a como estaba");
                ventana.comprobar(ventana.igual(ventana.desbordes(), []) && ventana.textoDe("prioridadHoja") === "Mínima" && ventana.unoHoja("claudeOffHoja").activo, "  y con «Mínima» y «Claude no» a la vez, nada de la hoja se sale por la derecha", ventana.desbordes().join(" | "));
                ventana.captura("18-hoja-editar-422");
            }],
        [200, () => ventana.clicDia("2026-10-29")],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && cal.elegido === "2026-10-29", "pulsar un día cierra la hoja de editar sin guardar");
                ventana.clicDia("2026-10-30");
            }],
        [300, () => ventana.clicEn(ventana.tituloDe("Clase de yoga"))],
        [300, () => {
                ventana.clicEn(ventana.campoHora("horaInicio"));
                ev.keyClick(Qt.Key_Down, Qt.NoModifier, -1);
            }],
        [200, () => {
                const c = ventana.campoHora("horaInicio");
                ventana.comprobar(c.entrada.activeFocus && c.text === "08:45" && ventana.hoja().horaInicio === "08:45", "en un campo de hora, la flecha abajo resta un cuarto de hora", c.text);
                ventana.escapesFuera = 0;
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.hoja() === null && ventana.escapesFuera === 0, "  y Escape desde él cancela la hoja, y ahí se queda (no sigue hacia la isla)", ventana.escapesFuera + " escapes fuera");
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.comprobar(ventana.posts() === ventana.posts0 + 3, "  (tres ediciones mandadas, la rechazada incluida)", ventana.posts() - ventana.posts0 + " escrituras");
                // Contraprueba: sin hoja, un Escape que nadie recoge sí sigue
                // hacia arriba, y la prueba lo ve.
                cal.forceActiveFocus();
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                ventana.comprobar(ventana.escapesFuera === 1, "  (sin hoja, Escape sí sigue hacia arriba: la comprobación de antes vale)", ventana.escapesFuera + " escapes fuera");
                cal.elegido = "2026-10-30";
                ventana.clicEn(ventana.tituloDe("Clase de yoga"));
            }],
        // La categoría, en la hoja de editar y en la de crear: un control de
        // una línea que abre una lista. Cada captura va en un paso y la acción
        // que la prepara, en el anterior (sale en el siguiente fotograma).
        [300, () => {
                const c = ventana.unoHoja("categoriaControl");
                const h = ventana.hoja();
                ventana.comprobar(cal.hojaModo === "editar" && c !== null && ventana.unoHoja("categoriasHoja") !== null && c.nombre === "General" && Qt.colorEqual(c.tinta, "#e67c73"), "la hoja enseña la categoría de la tarea en un solo control, con su color (General)", c ? c.nombre : "sin control");
                ventana.comprobar(ventana.todos("categoriaOpcion").length === 0 && !cal.menuCatAbierto, "  y la lista no sale hasta pulsarlo");
                ventana.comprobar(c.height <= 24 && c.x + c.width <= c.parent.width + 0.5, "  en una línea y dentro del ancho de la hoja", Math.round(c.height) + " de alto");
                ventana.alturaHoja = h.height;
                ventana.altoIsla = cal.implicitHeight;
                ventana.posts0 = ventana.posts();
                ventana.abrirCategorias();
            }],
        [450, () => {
                const o = ventana.todos("categoriaOpcion");
                const m = ventana.uno("menuCategorias");
                ventana.comprobar(cal.menuCatAbierto && ventana.igual(o.map(x => ventana.hijos(x, "etiquetaCategoria")[0].text), ["Clase", "General", "Homelab", "Proyecto de fin de ciclo"]), "pulsar el control abre la lista con las secciones del panel (con «Clase», que el panel nuevo distingue de las de Aules, y sin «En pausa»)", o.length + " opciones");
                ventana.comprobar(ventana.igual(o.map(x => ventana.hijos(x, "marcaCategoria").length), [0, 1, 0, 0]) && ventana.igual(o.map(x => x.actual), [false, true, false, false]), "  con la marca en la actual de la tarea (General)");
                ventana.comprobar(m !== null && m.y >= 0 && m.y + m.height <= cal.height && m.x >= 0 && m.x + m.width <= cal.width && ventana.todos("scrollCategorias").length === 0, "  dentro del calendario y sin scroll (caben)", m ? Math.round(m.x) + "," + Math.round(m.y) + " " + Math.round(m.height) : "");
                ventana.comprobar(ventana.hoja().height === ventana.alturaHoja, "  y la hoja no cambia de alto");
                ventana.captura("20-hoja-categoria-lista");
            }],
        [200, () => {
                ventana.escapesFuera = 0;
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [450, () => {
                ventana.comprobar(!cal.menuCatAbierto && cal.hojaModo === "editar" && ventana.hoja() !== null && ventana.escapesFuera === 0 && ventana.todos("categoriaOpcion").length === 0, "Escape con la lista abierta cierra solo la lista: la hoja sigue y Escape no sube a la isla", ventana.escapesFuera + " escapes fuera");
                ventana.abrirCategorias();
            }],
        [450, () => {
                ventana.comprobar(cal.menuCatAbierto, "(la lista, abierta otra vez)");
                ventana.dia0 = cal.elegido;
                ventana.clicDia("2026-10-27");
            }],
        [450, () => {
                ventana.comprobar(!cal.menuCatAbierto && cal.hojaModo === "editar" && ventana.hoja().seccion === "general" && cal.elegido === ventana.dia0, "pulsar fuera de la lista (en un día) la cierra y no hace nada más: ni cambia de día ni cierra la hoja", cal.menuCatAbierto + " " + cal.hojaModo + " " + cal.elegido);
                ventana.abrirCategorias();
            }],
        [450, () => ventana.clicEn(ventana.todos("categoriaOpcion")[2])],
        [450, () => {
                const c = ventana.unoHoja("categoriaControl");
                ventana.comprobar(!cal.menuCatAbierto && ventana.hoja().seccion === "homelab" && c.nombre === "Homelab" && Qt.colorEqual(c.tinta, "#33b679"), "elegir otra la pone en el control (nombre y color) y cierra la lista", ventana.hoja().seccion);
                ventana.comprobar(ventana.hoja().height === ventana.alturaHoja && cal.implicitHeight === ventana.altoIsla, "  sin cambiar el alto de la hoja ni el de la isla");
                ventana.abrirCategorias();
            }],
        [450, () => {
                const o = ventana.todos("categoriaOpcion");
                ventana.comprobar(ventana.igual(o.map(x => x.actual), [false, false, true, false]) && ventana.igual(o.map(x => ventana.hijos(x, "marcaCategoria").length), [0, 0, 1, 0]), "al reabrirla, la actual es la elegida (solo una)");
                ventana.clicEn(o[1]);
            }],
        [450, () => {
                ventana.comprobar(ventana.hoja().seccion === "general" && ventana.unoHoja("categoriaControl").nombre === "General", "  y elegir la de antes la vuelve a poner");
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [300, () => ventana.leerRegistro()],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.posts() === ventana.posts0, "elegir otra y volver a la misma no manda nada: guardar solo cierra la hoja", ventana.posts() - ventana.posts0 + " escrituras");
                ventana.clicEn(ventana.tituloDe("Clase de yoga"));
            }],
        [300, () => ventana.abrirCategorias()],
        [450, () => ventana.clicEn(ventana.todos("categoriaOpcion")[2])],
        [450, () => ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1)],
        [500, () => ventana.leerRegistro()],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(ventana.posts() === ventana.posts0 + 1 && r.metodo === "POST" && /^\/api\/tareas\/n\d+$/.test(r.ruta) && ventana.mismo(r.cuerpo, {
                    seccion: "homelab"
                }), "cambiar solo la categoría manda solo { seccion } a POST /api/tareas/{id}", JSON.stringify(r.cuerpo));
                const n = ventana.porTitulo("Clase de yoga");
                ventana.comprobar(cal.hojaModo === "" && n !== null && n.seccionId === "homelab" && ventana.etiquetaDe("Clase de yoga") === "Homelab" && Qt.colorEqual(ventana.barraDe("Clase de yoga").color, "#33b679"), "  y la fila pasa a «Homelab», con su barrita verde", ventana.etiquetaDe("Clase de yoga"));
                ventana.clicEn(ventana.tituloDe("Clase de yoga"));
            }],
        [300, () => {
                ventana.comprobar(ventana.unoHoja("categoriaControl").nombre === "Homelab", "al editarla otra vez, la categoría que se enseña es la nueva (Homelab)");
                ventana.abrirCategorias();
            }],
        [450, () => {
                const o = ventana.todos("categoriaOpcion");
                ventana.comprobar(ventana.igual(o.map(x => x.actual), [false, false, true, false]), "  y la actual de la lista, también");
                ventana.clicEn(o[3]);
                ventana.ajustar({
                    fallos: [
                        {
                            estado: 422,
                            error: "Sección desconocida."
                        }
                    ]
                });
            }],
        [450, () => ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1)],
        [500, () => {
                ventana.comprobar(cal.hojaModo === "editar" && !cal.guardando && ventana.hoja().seccion === "tfg" && ventana.textoDe("avisoHoja") === "Sección desconocida.", "si el panel rechaza el cambio de categoría, la hoja se queda con la elegida y el porqué", ventana.textoDe("avisoHoja"));
                ventana.comprobar(ventana.porTitulo("Clase de yoga").seccionId === "homelab", "  y la tarea vuelve a su categoría de antes");
                ventana.comprobar(ventana.unoHoja("categoriaControl").nombre === "Proyecto de fin de ciclo" && ventana.unoHoja("categoriaControl").width > 80, "  (con el nombre largo, cortado dentro del control)");
                ventana.captura("20b-hoja-categoria-422");
            }],
        [300, () => ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)],
        [300, () => ventana.dobleClicDia("2026-10-30")],
        [300, () => {
                const c = ventana.unoHoja("categoriaControl");
                ventana.comprobar(cal.hojaModo === "nueva" && c !== null && c.nombre === "General", "una hoja nueva trae elegida la categoría de siempre (General)");
                ventana.titulo().text = "Reunión del proyecto";
                ventana.abrirCategorias();
            }],
        [450, () => {
                ventana.prioIntacta = ventana.hoja().prioridad === "medium";
                ventana.clicEn(ventana.todos("categoriaOpcion")[3]);
            }],
        [450, () => {
                ventana.comprobar(ventana.prioIntacta && ventana.hoja().prioridad === "medium" && ventana.hoja().seccion === "tfg", "elegir en la lista no toca lo que hay debajo de ella (la prioridad sigue media)", ventana.hoja().prioridad);
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            }],
        [500, () => ventana.leerRegistro()],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(r.metodo === "POST" && r.ruta === "/api/tareas" && ventana.mismo(r.cuerpo, {
                    seccion: "tfg",
                    texto: "Reunión del proyecto",
                    area: "",
                    fecha: "2026-10-30",
                    prioridad: "medium",
                    claude_off: false
                }), "crear con otra categoría manda esa seccion en el POST", JSON.stringify(r.cuerpo));
                ventana.comprobar(cal.hojaModo === "" && ventana.etiquetaDe("Reunión del proyecto") === "Proyecto de fin de ciclo" && Qt.colorEqual(ventana.barraDe("Reunión del proyecto").color, "#8e24aa"), "  y la tarea sale en esa categoría, con su color", ventana.etiquetaDe("Reunión del proyecto"));
                ventana.clicEn(ventana.tituloDe("Clase de yoga"));
            }],
        // Eliminar, en la hoja de editar: dos pulsaciones.
        [300, () => {
                const e = ventana.unoHoja("eliminarHoja");
                ventana.comprobar(cal.hojaModo === "editar" && e !== null && ventana.textoBoton("eliminarHoja") === "Eliminar", "editando una tarea, la hoja tiene el botón «Eliminar»");
                ventana.captura("19-hoja-eliminar");
                ventana.clicEn(e);
            }],
        [300, () => {
                ventana.comprobar(ventana.textoBoton("eliminarHoja") === "¿Eliminar?" && ventana.hoja().confirmando && cal.hojaModo === "editar", "la primera pulsación pide confirmar y no borra nada");
                ventana.captura("19b-hoja-eliminar-confirmar");
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.comprobar(ventana.registro.filter(x => x.metodo === "DELETE").length === 0 && ventana.porTitulo("Clase de yoga") !== null, "  (ninguna petición DELETE, y la tarea sigue)");
                ventana.clicEn(ventana.unoHoja("prioridadPunto"));
            }],
        [300, () => {
                ventana.comprobar(!ventana.hoja().confirmando && ventana.textoBoton("eliminarHoja") === "Eliminar", "tocar otra cosa de la hoja retira la confirmación");
                ventana.clicEn(ventana.unoHoja("eliminarHoja"));
            }],
        [4600, () => {
                ventana.comprobar(!ventana.hoja().confirmando && ventana.textoBoton("eliminarHoja") === "Eliminar", "y sin pulsar nada, se retira sola a los pocos segundos");
                ventana.ajustar({
                    fallos: [
                        {
                            estado: 500,
                            error: ""
                        }
                    ]
                });
                ventana.clicEn(ventana.unoHoja("eliminarHoja"));
            }],
        [300, () => {
                ventana.clicEn(ventana.unoHoja("eliminarHoja"));
            }],
        [500, () => {
                ventana.comprobar(cal.hojaModo === "editar" && !cal.guardando && ventana.textoDe("avisoHoja") === "No se pudo eliminar la tarea (HTTP 500)" && ventana.porTitulo("Clase de yoga") !== null, "si el panel no la borra, la hoja se queda con el porqué y la tarea sigue", ventana.textoDe("avisoHoja"));
                ventana.ajustar({
                    retraso: 400
                });
                ventana.clicEn(ventana.unoHoja("eliminarHoja"));
            }],
        [300, () => ventana.clicEn(ventana.unoHoja("eliminarHoja"))],
        [150, () => {
                ventana.comprobar(cal.guardando && ventana.hoja() !== null && ventana.hoja().ocupada && ventana.porTitulo("Clase de yoga") !== null, "la segunda pulsación manda el borrado y espera al panel (no es optimista: la tarea sigue hasta que contesta)");
            }],
        [700, () => {
                ventana.comprobar(cal.hojaModo === "" && ventana.hoja() === null && ventana.porTitulo("Clase de yoga") === null && ventana.filaDe("Clase de yoga") === null, "  al contestar, la hoja se cierra y la tarea ya no está en la lista");
                ventana.comprobar(ventana.textoDe("avisoMover") === "Eliminada", "  y avisa", ventana.textoDe("avisoMover"));
                ventana.ajustar({
                    retraso: 0
                });
                ventana.leerRegistro();
            }],
        [300, () => {
                const dels = ventana.registro.filter(x => x.metodo === "DELETE");
                const r = dels[dels.length - 1] || {};
                ventana.comprobar(dels.length === 2 && /^\/api\/tareas\/n\d+$/.test(r.ruta) && r.auth === true && r.cuerpo === null, "  con DELETE /api/tareas/{id}, sin cuerpo y con las credenciales (el intento fallido, y este)", dels.length + " DELETE, " + r.ruta);
                ventana.clicEn(ventana.tituloDe("MIA: Tarea quinta"));
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "editar" && ventana.unoHoja("eliminarHoja") === null && !cal.hojaBorrable, "las entregas de Aules (área «Clase») son de solo lectura: la hoja no tiene «Eliminar»");
                ventana.comprobar(ventana.todos("categoriaOpcion").length === 0 && ventana.unoHoja("categoriasHoja") === null, "  ni selector de categoría: la de Aules es fija");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        // «Clase» como categoría elegible: una tarea propia movida a Clase
        // (aules false) sigue con selector y «Eliminar»; con un panel viejo
        // (sin «aules») Clase no se ofrece y una tarea de Clase es de Aules.
        [300, () => {
                ventana.comprobar(cliente.categorias.map(c => c.id).indexOf("clase") === 0 && cliente.categorias.map(c => c.id).indexOf("en-pausa") < 0, "con el panel nuevo (manda «aules»), Clase se ofrece como categoría y En pausa no");
                ventana.comprobar(Qt.colorEqual(cliente.categorias[0].color, Formato.COLOR_CLASE), "  y con el violeta de Clase, que su sección no trae", cliente.categorias[0].color);
                ventana.comprobar(ventana.porTitulo("MIA: Tarea quinta").aules === true && ventana.porTitulo("Revisar el informe").aules === false, "  y cada tarea lleva si es de Aules (la entrega sí, las propias no)");
                ventana.ajustar({
                    mover: {
                        g1: "clase"
                    }
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => {
                const n = ventana.porTitulo("Revisar el informe");
                ventana.comprobar(n.seccionId === "clase" && n.aules === false && ventana.etiquetaDe("Revisar el informe") === "Clase" && Qt.colorEqual(ventana.barraDe("Revisar el informe").color, Formato.COLOR_CLASE), "una tarea propia movida a Clase sale en Clase con el violeta, y no es de Aules");
                ventana.clicEn(ventana.tituloDe("Revisar el informe"));
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "editar" && cal.hojaBorrable && ventana.unoHoja("eliminarHoja") !== null && ventana.unoHoja("categoriasHoja") !== null, "  al editarla tiene «Eliminar» y selector de categoría (no es de Aules)");
                const c = ventana.unoHoja("categoriaControl");
                ventana.comprobar(c.nombre === "Clase" && Qt.colorEqual(c.tinta, Formato.COLOR_CLASE), "  con «Clase» y su violeta en el control", c.nombre);
                ventana.abrirCategorias();
            }],
        [450, () => {
                const o = ventana.todos("categoriaOpcion");
                ventana.comprobar(o.length > 0 && ventana.hijos(o[0], "etiquetaCategoria")[0].text === "Clase" && o[0].actual, "la lista abre con Clase en primer lugar, y es la actual", o.length + " opciones");
                ventana.captura("20c-hoja-clase-propia-lista");
            }],
        [200, () => ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)],
        [300, () => {
                ventana.captura("20d-hoja-clase-propia");
            }],
        [300, () => ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)],
        [300, () => ventana.clicEn(ventana.tituloDe("MIA: Tarea quinta"))],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "editar" && cal.hojaDeAules && !cal.hojaBorrable && ventana.unoHoja("eliminarHoja") === null && ventana.unoHoja("categoriasHoja") === null, "la entrega de Aules (aules true) sigue sin «Eliminar» ni selector, aunque Clase se ofrezca");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                ventana.ajustar({
                    viejo: true
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => {
                ventana.comprobar(cliente.categorias.map(c => c.id).indexOf("clase") < 0 && ventana.porTitulo("MIA: Tarea quinta").aules === undefined, "con un panel viejo (sin «aules») Clase no se ofrece");
                ventana.clicEn(ventana.tituloDe("Revisar el informe"));
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "editar" && cal.hojaDeAules && ventana.unoHoja("eliminarHoja") === null && ventana.unoHoja("categoriasHoja") === null, "  y, como hoy, toda tarea de categoría «Clase» es de Aules: sin «Eliminar» ni selector");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                ventana.ajustar({
                    viejo: false
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => {
                ventana.comprobar(cliente.categorias.map(c => c.id).indexOf("clase") === 0 && ventana.porTitulo("MIA: Tarea quinta").aules === true, "(y el panel nuevo, otra vez)");
                ventana.ajustar({
                    mover: {
                        g1: "general"
                    }
                });
            }],
        [300, () => cliente.refrescar(true)],
        // Las secciones del panel, muchas y con nombres largos: la hoja y la
        // isla no cambian de alto y nada se sale.
        [300, () => {
                // El cliente, sin ninguna sección en la que crear (nada se manda)
                // o con solo ocultas (Clase y En pausa) y una de verdad.
                const sec = id => ({ id: id, title: id, tasks: [] });
                cliente.poner({ sections: [sec("clase"), sec("en-pausa"), sec("proyecto")] }, true);
                ventana.comprobar(cliente.seccionPorDefecto() === "proyecto", "sin General, lo que se cree no va a una sección oculta (ni En pausa ni Clase)", cliente.seccionPorDefecto());
                cliente.poner({ sections: [] }, true);
                let r = null;
                cliente.crear({
                    texto: "Algo",
                    dia: "2026-10-30",
                    seccion: ""
                }, ok => r = ok);
                ventana.comprobar(r === false && cliente.error === "No hay ninguna sección en la que crearla" && !cliente.escribiendo, "sin ninguna sección en la que crearla no se manda nada y se dice por qué", cliente.error);
                ventana.leerRegistro();
            }],
        [300, () => {
                ventana.ajustar({
                    secciones: [["homelab", "Homelab", "#33b679"], ["tfg", "Proyecto de fin de ciclo", "#8e24aa"], ["l1", "Sistemas informáticos y redes locales de la oficina", "#039be5"], ["l2", "Programación de servicios y procesos del módulo", "#f6bf26"], ["l3", "Empresa e iniciativa emprendedora (EIE)", "#616161"], ["l4", "Inglés técnico para el ciclo formativo", "#f4511e"], ["l5", "Prácticas en empresa (FCT) y memoria final", "#0b8043"]]
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => {
                ventana.comprobar(cliente.categorias.length === 9 && cliente.seccionPorDefecto() === "general", "con ocho secciones en el panel (y Clase), la hoja las ofrece las nueve", String(cliente.categorias.length));
                ventana.clicDia("2026-10-22");
            }],
        [300, () => ventana.clicEn(ventana.tituloDe("Llamar al taller"))],
        [300, () => {
                const h = ventana.hoja();
                const g = ventana.unoHoja("guardarHoja");
                const q = g.mapToItem(cal, 0, g.height);
                ventana.comprobar(cal.hojaModo === "editar" && ventana.unoHoja("categoriaControl").nombre === "General" && h.height === ventana.alturaHoja && cal.implicitHeight === ventana.altoIsla, "con ocho secciones la hoja y la isla miden lo mismo que con tres", h.height + " / " + ventana.alturaHoja);
                ventana.comprobar(q.y <= cal.height && ventana.igual(ventana.desbordes(), []), "  y Guardar y Eliminar siguen dentro de la isla, sin salirse por la derecha", Math.round(q.y) + " de " + Math.round(cal.height) + " " + ventana.desbordes().join(" | "));
                ventana.captura("21-hoja-8-secciones");
            }],
        [300, () => ventana.abrirCategorias()],
        [450, () => {
                const l = ventana.uno("listaCategorias");
                const m = ventana.uno("menuCategorias");
                ventana.comprobar(l !== null && l.count === 9 && l.contentHeight > l.height && ventana.todos("scrollCategorias").length === 1, "la lista de nueve (ocho y Clase) tiene scroll (y la rayita lo dice)", l ? l.count + " / " + Math.round(l.contentHeight) + " > " + Math.round(l.height) : "");
                ventana.comprobar(m !== null && m.height <= 6 * 24 + 12 && m.y >= 0 && m.y + m.height <= cal.height && m.x >= 0 && m.x + m.width <= cal.width, "  de un alto razonable y dentro del calendario", m ? Math.round(m.y) + " " + Math.round(m.height) : "");
                ventana.comprobar(ventana.hoja().height === ventana.alturaHoja, "  sin cambiar el alto de la hoja");
                ventana.captura("21b-lista-8-secciones");
            }],
        [300, () => {
                const l = ventana.uno("listaCategorias");
                l.contentY = l.contentHeight - l.height;
            }],
        [300, () => {
                const l = ventana.uno("listaCategorias");
                const o = ventana.todos("categoriaOpcion").find(x => ventana.hijos(x, "etiquetaCategoria")[0].text === "Prácticas en empresa (FCT) y memoria final");
                const q = o ? o.mapToItem(l, 0, 0) : null;
                ventana.comprobar(o !== null && q.y >= 0 && q.y + o.height <= l.height + 0.5, "al bajar la lista se llega a la última", q ? String(Math.round(q.y)) : "");
                ventana.clicEn(o);
            }],
        [450, () => {
                const c = ventana.unoHoja("categoriaControl");
                ventana.comprobar(ventana.hoja().seccion === "l5" && c.nombre === "Prácticas en empresa (FCT) y memoria final" && c.x + c.width <= c.parent.width + 0.5 && ventana.hoja().height === ventana.alturaHoja, "elegir la última pone su nombre largo en el control, cortado, y la hoja no cambia", ventana.hoja().seccion);
                ventana.comprobar(ventana.igual(ventana.desbordes(), []), "  y nada se sale por la derecha", ventana.desbordes().join(" | "));
                ventana.ajustar({
                    fallos: [
                        {
                            estado: 422,
                            error: "La sección de destino ya no existe en tus notas; recarga el panel y vuelve a elegir una categoría de la lista antes de guardar otra vez."
                        }
                    ]
                });
                ventana.captura("22-hoja-8-secciones-elegida");
            }],
        [300, () => ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1)],
        [500, () => {
                const a = ventana.unoHoja("avisoHoja");
                const e = ventana.unoHoja("eliminarHoja");
                const g = ventana.unoHoja("guardarHoja");
                const q = g.mapToItem(cal, 0, g.height);
                ventana.comprobar(cal.hojaModo === "editar" && a.text.indexOf("La sección de destino") === 0 && a.mapToItem(cal, 0, a.height).y <= e.mapToItem(cal, 0, 0).y + 0.5 && a.width > 200 && a.contentHeight <= a.height + 0.5, "un error largo del panel se parte en líneas, en su línea y entero, sin montarse sobre «Eliminar»", Math.round(a.width) + " de ancho, " + Math.round(a.contentHeight) + " de alto");
                ventana.comprobar(q.y <= cal.height && ventana.igual(ventana.desbordes(), []), "  ni empuja los botones fuera de la isla", Math.round(q.y) + " de " + Math.round(cal.height));
                ventana.captura("23-hoja-editar-error-largo");
            }],
        [300, () => ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)],
        // Una tarea en una sección que no se ofrece (En pausa).
        [300, () => {
                ventana.ajustar({
                    mover: {
                        g2: "en-pausa"
                    }
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => {
                ventana.leerRegistro();
                ventana.clicEn(ventana.tituloDe("Llamar al taller"));
            }],
        [300, () => {
                const c = ventana.unoHoja("categoriaControl");
                ventana.comprobar(cal.hojaModo === "editar" && ventana.unoHoja("categoriasHoja") !== null && c !== null && c.nombre === "En pausa", "una tarea en una sección que no se ofrece (En pausa) enseña su categoría igual", c ? c.nombre : "sin control");
                ventana.posts0 = ventana.posts();
                ventana.clicEn(ventana.enHoja("prioridadPunto")[0]);
                ventana.captura("24-hoja-en-pausa");
            }],
        [300, () => {
                ventana.abrirCategorias();
            }],
        [450, () => {
                const o = ventana.todos("categoriaOpcion");
                ventana.comprobar(o.length > 0 && o.every(x => !x.actual) && ventana.hoja().seccion === "en-pausa", "  y en la lista no hay ninguna marcada como la actual");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [450, () => ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1)],
        [500, () => ventana.leerRegistro()],
        [300, () => {
                const r = ventana.ultima();
                ventana.comprobar(ventana.posts() === ventana.posts0 + 1 && ventana.mismo(r.cuerpo, {
                    prioridad: "highest"
                }) && ventana.porTitulo("Llamar al taller").seccionId === "en-pausa", "cambiar otra cosa de ella no manda seccion: solo { prioridad } y sigue en pausa", JSON.stringify(r.cuerpo));
            }],
        // Con una sola categoría y que sea la actual, no hay nada que elegir.
        [300, () => {
                // Con un panel viejo, que no ofrece Clase.
                ventana.ajustar({
                    secciones: [],
                    viejo: true
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => {
                ventana.comprobar(cliente.categorias.length === 1, "con una sola sección en el panel (General)", String(cliente.categorias.length));
                ventana.clicEn(ventana.tituloDe("Llamar al taller"));
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "editar" && ventana.unoHoja("categoriasHoja") !== null, "  la tarea de una sección oculta sí ve el control (puede pasarse a General)");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [300, () => {
                ventana.clicDia("2026-10-30");
            }],
        [300, () => {
                ventana.clicEn(ventana.tituloDe("Revisar el informe"));
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "editar" && ventana.unoHoja("categoriasHoja") === null && ventana.todos("categoriaOpcion").length === 0, "  y la tarea de General, con General como única, no ve ninguno");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
            }],
        [300, () => ventana.dobleClicDia("2026-10-30")],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "nueva" && ventana.unoHoja("categoriasHoja") === null, "  ni la hoja de una nueva (se crea en General)");
                ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                ventana.ajustar({
                    secciones: [["homelab", "Homelab", "#33b679"], ["tfg", "Proyecto de fin de ciclo", "#8e24aa"]],
                    viejo: false,
                    mover: {
                        g2: "general"
                    }
                });
            }],
        [300, () => cliente.refrescar(true)],
        [900, () => ventana.leerRegistro()],
        [300, () => {
                ventana.gets0 = ventana.registro.filter(x => x.metodo === "GET").length;
                ventana.comprobar(cliente.categorias.length === 4 && cliente.estado === "conectado", "(las secciones del panel, como estaban)");
            }],
        [300, () => {
                ventana.dobleClicDia("2026-10-23");
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "nueva" && cal.hojaDia === "2026-10-23", "(la hoja abierta)");
                ventana.clicEn(ventana.uno("chipMes"));
            }],
        [300, () => {
                ventana.comprobar(cal.selectorAbierto && cal.hojaModo === "nueva", "(y el desplegable)");
                shellFalso.mode = "";
            }],
        [300, () => {
                ventana.comprobar(cal.hojaModo === "" && cal.menuDe === null && !cal.selectorAbierto, "al cerrar la isla se cierran la hoja, el menú y el desplegable");
                shellFalso.mode = "calendar";
                ventana.leerRegistro();
            }],
        [300, () => {
                const gets = ventana.registro.filter(x => x.metodo === "GET").length;
                ventana.comprobar(gets === ventana.gets0 && ventana.registro.every(x => x.auth), "al abrirla otra vez no se relee (lo que hay es reciente), y todo fue con credenciales", gets + " lecturas");
                shellFalso.tareas = null;
                shellFalso.agenda = null;
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
