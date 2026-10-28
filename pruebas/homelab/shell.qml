import QtQuick
import QtTest
import Quickshell
import "homelab"
import "shared"

// Prueba sin pantalla del cajón (la lanza prueba.sh, al lado): el Cajon.qml
// del repo en una ventana de 700x900, con un shell falso y el ratón y el
// teclado movidos con TestEvent. Cada comprobación imprime OK o FALLO; al
// final, el recuento. La fase 3 (tareas, hábitos y Aules) y la 4 (proyectos,
// servidor y registro) van al final, con la API falsa con estado de
// ApiFalsa.qml.
FloatingWindow {
    id: ventana

    implicitWidth: 700
    implicitHeight: 900
    color: "#1b2030"

    readonly property string dir: Quickshell.env("PRUEBA_DIR") + "/capturas/"

    QtObject {
        id: falso
        property bool abierto: false
        property bool fijado: false
        property var api: apiFalsa
    }

    // La API falsa de la fase 2 (ApiFalsa.qml, al lado) y los avisos reales con
    // la orden sustituida: nada de notify-send de verdad.
    ApiFalsa {
        id: apiFalsa
    }

    // Un segundo TareasEstado, para ver que lo guardado se lee de verdad.
    Component {
        id: lectorEstado

        TareasEstado {
            property string vistaLeida: ""
            property var plegadosLeidos: null

            onLeido: (vista, plegados) => {
                vistaLeida = vista;
                plegadosLeidos = plegados;
            }
        }
    }

    property var lector: null
    property bool plegadoAntes: false
    property var lanzadas: []
    property int refrescosAntes: 0

    Avisos {
        api: apiFalsa
        lanzar: args => ventana.lanzadas = ventana.lanzadas.concat([args])
    }

    Item {
        id: envoltura
        anchors.fill: parent

        // Un fondo con algo de dibujo, para ver el cristal encima.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a4a6b" }
                GradientStop { position: 1; color: "#6b3a55" }
            }
        }
        Text {
            x: 40; y: 120
            text: "ventana de detrás"
            color: "white"; font.pixelSize: 40
        }

        // Otro sitio donde puede estar el foco del teclado, y cuántos Escape
        // llegan hasta aquí (hasta Borde.qml, que es quien cierra el cajón).
        Item {
            id: otroFoco
        }
        property int escapes: 0
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                envoltura.escapes++;
        }

        Cajon {
            id: cajon
            anchors.fill: parent
            anchoPantalla: 1440
            shell: falso
        }
    }

    TestEvent { id: ev }

    // Los pasos de Notas (fase 5), en su fichero (PasosNotas.qml, al lado).
    PasosNotas {
        id: pasosNotas
        v: ventana
        api: apiFalsa
        zona: envoltura
        shell: falso
    }

    // Los pasos del orden de las secciones (PasosOrden.qml, al lado).
    PasosOrden {
        id: pasosOrden
        v: ventana
        zona: envoltura
    }

    property var fallos: []
    property int hechas: 0

    function comprobar(ok, que, extra) {
        console.log((ok ? "OK     " : "FALLO  ") + que + "  (progreso " + cajon.progreso.toFixed(3) + ", abierto " + falso.abierto + ", asoma " + cajon.asoma + (extra !== undefined && extra !== "" ? "; " + extra : "") + ")");
        ventana.hechas++;
        if (!ok)
            ventana.fallos.push(que);
    }

    function captura(nombre) {
        envoltura.grabToImage(r => r.saveToFile(ventana.dir + nombre + ".png"));
    }

    // Recorre el árbol del cajón.
    function recorrer(item, f) {
        f(item);
        for (let k = 0; k < item.children.length; k++)
            ventana.recorrer(item.children[k], f);
    }

    // Todo el texto visible del cajón, en una cadena.
    function textos() {
        const l = [];
        ventana.recorrer(cajon, it => {
            if (it.visible && typeof it.text === "string" && it.text !== "")
                l.push(it.text);
        });
        return l.join("\n");
    }

    function porNombre(nombre) {
        const l = [];
        ventana.recorrer(cajon, it => {
            if (it.objectName === nombre && it.visible)
                l.push(it);
        });
        return l;
    }

    function colorPunto() {
        return ventana.porNombre("puntoAsa")[0].color;
    }

    function tiene(trozo) {
        return ventana.textos().indexOf(trozo) >= 0;
    }


    // --- Fase 3: ayudas ------------------------------------------------------

    // Un clic en el centro de un item, o en (dx, dy) de él.
    function clic(item, dx, dy) {
        ventana.verEnLista(item);
        const p = item.mapToItem(envoltura, dx === undefined ? item.width / 2 : dx, dy === undefined ? item.height / 2 : dy);
        ev.mouseClick(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    // Las listas que se desplazan y recortan.
    readonly property var desplazables: ["desplazableTareas", "desplazableInicio", "desplazableProyectos", "detalleProyecto", "desplazableServidor", "desplazableRegistro", "desplazableRevisiones", "desplazableFinanzas"]

    // Si el item está en una lista que se desplaza (y recorta), la mueve hasta
    // que se vea entero: un clic fuera de lo que enseña no llega.
    function verEnLista(item) {
        let f = item;
        while (f && ventana.desplazables.indexOf(f.objectName) < 0)
            f = f.parent;
        if (!f)
            return;
        const y = item.mapToItem(f.contentItem, 0, 0).y;
        if (y < f.contentY + 8 || y + item.height > f.contentY + f.height - 8)
            f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - 100));
    }

    function uno(nombre) {
        const l = ventana.porNombre(nombre);
        return l.length ? l[0] : null;
    }

    // Una tarjeta de las tareas de Inicio, por su texto.
    function tarjetaInicio(texto) {
        return ventana.porNombre("tarjetaInicio").find(t => t.modelData.texto === texto) || null;
    }

    function textosInicio() {
        return ventana.porNombre("tarjetaInicio").map(t => t.modelData.texto);
    }

    property string idInicio: ""
    property var asa: null

    // Tareas.qml, esté a la vista o no (con el cajón cerrado no se ve).
    function ui() {
        let r = null;
        ventana.recorrer(cajon, it => {
            if (it.objectName === "seccionTareas")
                r = it;
        });
        return r;
    }

    // Las filas y las tarjetas visibles bajo un item.
    function filasDe(raiz) {
        const l = [];
        ventana.recorrer(raiz, it => {
            if (it.visible && it.t !== undefined && it.ctx !== undefined && it.ctrl !== undefined)
                l.push(it);
        });
        return l;
    }

    function filaDe(plano, ctx) {
        return ventana.filasDe(ventana.ui()).find(f => f.t.plano === plano && f.ctx === ctx) || null;
    }

    // Que un item quede dentro de lo que enseña la lista de tareas.
    function traer(item) {
        const f = ventana.uno("desplazableTareas");
        const y = item.mapToItem(f.contentItem, 0, 0).y;
        f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - 120));
    }

    // Un clic en una fila (en su texto, no en la casilla) o en una tarjeta.
    function clicFila(plano, ctx) {
        const f = ventana.filaDe(plano, ctx);
        if (!f)
            return false;
        ventana.traer(f);
        ventana.clic(f, ctx === "a" ? 90 : 160, ctx === "a" ? 50 : 17);
        return true;
    }

    function grupos() {
        const l = [];
        ventana.recorrer(ventana.ui(), it => {
            if (it.visible && it.objectName.indexOf("grupo-") === 0)
                l.push(it);
        });
        return l;
    }

    function claves() {
        return ventana.grupos().map(g => g.objectName.slice(6));
    }

    function planos(raiz) {
        return ventana.filasDe(raiz).map(f => f.t.plano);
    }

    function ahoraPlanos() {
        return ventana.ui() ? ventana.filasDe(ventana.ui()).filter(f => f.ctx === "a").map(f => f.t.plano) : [];
    }

    function ultima() {
        return apiFalsa.escrituras[apiFalsa.escrituras.length - 1] || null;
    }

    function ultimaJSON() {
        const u = ventana.ultima();
        return u ? u.op + " " + JSON.stringify(u.cuerpo) : "(nada)";
    }

    // Una tecla (un carácter o un Qt.Key_...): la recoge quien tenga el foco de
    // la ventana, que es lo que pasa con el teclado de verdad.
    function tecla(t, mods) {
        const m = mods === undefined ? Qt.NoModifier : mods;
        if (typeof t === "string")
            ev.keyClickChar(t, m, -1);
        else
            ev.keyClick(t, m, -1);
    }

    function igual(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    property var claseGuardada: null

    function contenidoRaiz() {
        let r = null;
        ventana.recorrer(cajon, it => {
            if (it.objectName === "contenido")
                r = it;
        });
        return r;
    }

    function seccion(id) {
        ventana.clic(ventana.uno("seccion-" + id));
    }

    function grupoPlegado(clave) {
        const g = ventana.grupos().find(x => x.objectName === "grupo-" + clave);
        return g ? g.plegado : null;
    }

    property int escrituras0: 0
    property int lecturas0: 0
    property bool fijadaAntes: false
    property string versionNueva: ""

    // El primer item visible con ese nombre bajo «raiz».
    function hijo(raiz, nombre) {
        let r = null;
        ventana.recorrer(raiz, it => {
            if (!r && it.visible && it.objectName === nombre)
                r = it;
        });
        return r;
    }

    // La cabecera de un grupo, por su clave.
    function cabecera(clave) {
        const g = ventana.grupos().find(x => x.objectName === "grupo-" + clave);
        return g ? ventana.hijo(g, "cabeceraGrupo") : null;
    }

    // --- Fase 4: ayudas ------------------------------------------------------

    property var enlaces: []
    property int escapes0: 0
    property int acciones0: 0
    property int edicionesAntes: 0
    property int detallesAntes: 0
    property int masAntes: 0
    property int lecturasAntes: 0

    // Los nombres de los items visibles que empiezan por «prefijo», sin él,
    // en el orden del árbol.
    function nombresCon(prefijo) {
        const l = [];
        ventana.recorrer(cajon, it => {
            if (it.visible && it.objectName.indexOf(prefijo) === 0)
                l.push(it.objectName.slice(prefijo.length));
        });
        return l;
    }

    // El primer item con ese nombre, esté a la vista o no.
    function cualquiera(nombre) {
        let r = null;
        ventana.recorrer(cajon, it => {
            if (!r && it.objectName === nombre)
                r = it;
        });
        return r;
    }

    function ultimaProyecto() {
        return apiFalsa.edicionesProyecto[apiFalsa.edicionesProyecto.length - 1] || null;
    }

    function ultimaAccion() {
        return apiFalsa.acciones[apiFalsa.acciones.length - 1] || null;
    }

    // La línea de estado de un contenedor en Servidor.
    function estadoDe(nombre) {
        const c = ventana.uno("contenedor-" + nombre);
        const t = c ? ventana.hijo(c, "estadoContenedor") : null;
        return t ? t.text : "";
    }

    function textoAviso() {
        const a = ventana.uno("textoAviso");
        return a ? a.text : "";
    }

    function asaX() {
        return cajon.xCajon - cajon.asaHueco - cajon.asaAncho / 2;
    }

    property real px: 0
    readonly property int py: 450
    property real qy: 0

    // Un arrastre de «dx» píxeles en «n» pasos, uno cada «ms».
    function arrastre(dx, n, ms) {
        const lista = [[100, () => {
                    ventana.px = ventana.asaX();
                    ev.mousePress(envoltura, ventana.px, ventana.py, Qt.LeftButton, Qt.NoModifier, -1);
                }]];
        for (let i = 1; i <= n; i++)
            lista.push([ms, () => {
                    ventana.px += dx / n;
                    ev.mouseMove(envoltura, ventana.px, ventana.py, -1, Qt.LeftButton, Qt.NoModifier);
                }]);
        return lista;
    }

    function soltar(espera) {
        return [[espera, () => ev.mouseRelease(envoltura, ventana.px, ventana.py, Qt.LeftButton, Qt.NoModifier, -1)]];
    }

    readonly property var pasos: [].concat(
        pasosOrden.pasos,
        [[300, () => ev.mouseMove(envoltura, 350, 450, -1, Qt.NoButton, Qt.NoModifier)]],
        [[300, () => {
            ventana.comprobar(!cajon.asoma, "en medio de la pantalla no asoma");
            ev.mouseMove(envoltura, 699, 100, -1, Qt.NoButton, Qt.NoModifier);
        }]],
        [[300, () => {
            ventana.comprobar(!cajon.asoma, "arriba del borde (fuera del centro) no asoma");
            ev.mouseMove(envoltura, 699, 450, -1, Qt.NoButton, Qt.NoModifier);
        }]],
        [[60, () => ventana.comprobar(!cajon.asoma, "en el centro del borde, antes de 120 ms, todavía no")]],
        [[400, () => {
            ventana.comprobar(cajon.asoma && Math.abs(cajon.asomaVisible - cajon.asomaPx) < 0.5, "en el centro del borde asoma el asa");
            ventana.captura("1-asoma");
        }]],
        // Poco y despacio: vuelve.
        ventana.arrastre(-100, 10, 30),
        [[40, () => {
            ventana.comprobar(Math.abs(cajon.progreso - 100 / cajon.recorrido) < 0.03, "arrastrando, el cajón va pegado al ratón");
            ventana.comprobar(cajon.arrastrando, "arrastrando");
            ventana.captura("2-arrastrando");
        }]],
        ventana.soltar(200),
        [[700, () => ventana.comprobar(!falso.abierto && cajon.progreso < 0.01, "soltar antes de un tercio, despacio: vuelve")]],
        // Más de un tercio y despacio: abre.
        ventana.arrastre(-250, 12, 30),
        ventana.soltar(200),
        [[800, () => {
            ventana.comprobar(falso.abierto && Math.abs(cajon.progreso - 1) < 0.005, "soltar pasado un tercio, despacio: abre");
            ventana.captura("3-abierto");
        }]],
        // Abierto, un poco hacia la derecha y despacio: se queda.
        ventana.arrastre(100, 10, 30),
        ventana.soltar(200),
        [[800, () => ventana.comprobar(falso.abierto && Math.abs(cajon.progreso - 1) < 0.005, "abierto, devolverlo menos de un tercio: se queda")]],
        // Tirar de más: cede como una goma y no pasa del 6 %.
        ventana.arrastre(-200, 8, 30),
        [[40, () => ventana.comprobar(cajon.progreso > 1 && cajon.progreso <= 1.06 + 1e-6, "tirar de más cede como una goma")]],
        ventana.soltar(200),
        [[800, () => ventana.comprobar(Math.abs(cajon.progreso - 1) < 0.005, "y al soltar vuelve a su sitio")]],
        // Un tirón rápido hacia la derecha: cierra aunque se mueva poco.
        ventana.arrastre(60, 3, 8),
        ventana.soltar(1),
        [[700, () => ventana.comprobar(!falso.abierto && cajon.progreso < 0.01, "un tirón hacia fuera cierra")]],
        // Un tirón rápido hacia dentro: abre.
        [[100, () => ev.mouseMove(envoltura, 699, 450, -1, Qt.NoButton, Qt.NoModifier)]],
        [[400, () => ventana.comprobar(cajon.asoma, "vuelve a asomar")]],
        ventana.arrastre(-60, 3, 8),
        ventana.soltar(1),
        [[800, () => ventana.comprobar(falso.abierto && Math.abs(cajon.progreso - 1) < 0.005, "un tirón hacia dentro abre")]],
        // Desde fuera (SUPER+H, Escape, clic fuera): cierra y abre.
        [[50, () => falso.abierto = false]],
        [[150, () => ventana.comprobar(cajon.progreso > 0.5, "cerrar con el teclado toma carrerilla (aún va por la mitad)")]],
        [[600, () => ventana.comprobar(cajon.progreso < 0.01, "cerrar desde fuera lo esconde")]],
        [[50, () => falso.abierto = true]],
        [[800, () => ventana.comprobar(Math.abs(cajon.progreso - 1) < 0.005, "abrir desde fuera lo saca")]],
        // Un clic en el asa, sin mover: cierra.
        [[100, () => {
            ventana.px = ventana.asaX();
            ev.mouseClick(envoltura, ventana.px, ventana.py, Qt.LeftButton, Qt.NoModifier, -1);
        }]],
        [[800, () => ventana.comprobar(!falso.abierto && cajon.progreso < 0.01, "un clic en el asa abierta cierra")]],
        // La rueda horizontal sobre el asa: abre.
        [[100, () => ev.mouseMove(envoltura, 699, 450, -1, Qt.NoButton, Qt.NoModifier)]],
        [[400, () => ev.mouseMove(envoltura, ventana.asaX(), 450, -1, Qt.NoButton, Qt.NoModifier)]],
        Array.from({ length: 12 }, () => [16, () => ev.mouseWheel(envoltura, ventana.asaX(), 450, Qt.NoButton, Qt.NoModifier, -120, 0, -1)]),
        [[40, () => ventana.comprobar(cajon.arrastrando && cajon.progreso > 0.2, "la rueda horizontal mueve el cajón")]],
        [[900, () => ventana.comprobar(falso.abierto && Math.abs(cajon.progreso - 1) < 0.005, "y al parar, abre")]],
        // Una rueda vertical no hace nada.
        [[50, () => falso.abierto = false]],
        [[700, () => ev.mouseMove(envoltura, 699, 450, -1, Qt.NoButton, Qt.NoModifier)]],
        [[400, () => ev.mouseMove(envoltura, ventana.asaX(), 450, -1, Qt.NoButton, Qt.NoModifier)]],
        Array.from({ length: 6 }, () => [16, () => ev.mouseWheel(envoltura, ventana.asaX(), 450, Qt.NoButton, Qt.NoModifier, 0, -120, -1)]),
        [[300, () => ventana.comprobar(!cajon.arrastrando && cajon.progreso < 0.01, "la rueda vertical no lo mueve")]],
        // --- Fase 2: los datos salen de la API (falsa) ---
        [[50, () => {
            ventana.refrescosAntes = apiFalsa.refrescos;
            falso.abierto = true;
        }]],
        [[800, () => {
            ventana.comprobar(apiFalsa.refrescos === ventana.refrescosAntes + 1, "abrir el cajón llama a refrescar una vez");
            ventana.comprobar(ventana.tiene("martes 20 de octubre · semana 43"), "el Inicio enseña la fecha y la semana de la API");
            ventana.comprobar(ventana.tiene("8 de 9 en marcha · 1 con problemas · 2 alertas sin ver"), "el Inicio enseña el servidor y las alertas sin ver en una línea");
            ventana.comprobar(ventana.tiene("34 %"), "el Inicio enseña el porcentaje de la meta");
            ventana.comprobar(ventana.tiene("Entrega de prueba con fecha") && ventana.tiene("Revisar la copia de seguridad") && ventana.tiene("Tarea en otra nota"), "el Inicio enseña las tareas de la API");
            ventana.comprobar(ventana.tiene("vencida hace 2 días") && ventana.tiene("vencida ayer") && ventana.tiene("vencida hace 3 días"), "las tareas enseñan su «cuando»");
            ventana.comprobar(ventana.tiene("Contenedor caído: caddy") && ventana.tiene("Disco al 85 % en /srv") && ventana.tiene("hace 12 min"), "el Inicio enseña las alertas abiertas con su título y desde cuándo");
            ventana.comprobar(ventana.porNombre("botonVista").length === 2, "«Vista» sólo en las alertas sin ver");
            ventana.comprobar(!ventana.tiene("datos de prueba") && !ventana.tiene("Todo esto es de prueba"), "ya no queda el texto de datos de prueba");
            ventana.comprobar(ventana.tiene("conectado · portatil"), "la cabecera dice la conexión y el usuario");
            ventana.captura("4-inicio-conectado");
            const b = ventana.porNombre("botonVista")[0];
            const p = b.mapToItem(envoltura, b.width / 2, b.height / 2);
            ev.mouseClick(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.vistas.length === 1 && apiFalsa.vistas[0] === "a1", "«Vista» llama a marcarVista con el id de la alerta");
            ev.mouseMove(envoltura, 350, 450, -1, Qt.NoButton, Qt.NoModifier);
        }]],
        // Las casillas de las tareas de Inicio: marcan y desmarcan como las de
        // Tareas (marcarTarea con el id de la tarea), menos las de otras notas.
        [[50, () => {
            ventana.comprobar(ventana.igual(ventana.textosInicio(), ["Entrega de prueba con fecha", "Tarea en otra nota", "Revisar la copia de seguridad", "Pausada que venció"]), "Inicio: una tarjeta por tarea vencida o de hoy", JSON.stringify(ventana.textosInicio()));
            const con = ventana.porNombre("tarjetaInicio").filter(t => ventana.hijo(t, "casillaInicio") !== null).map(t => t.modelData.texto);
            ventana.comprobar(ventana.igual(con, ["Entrega de prueba con fecha", "Revisar la copia de seguridad", "Pausada que venció"]), "  las de la nota llevan casilla; la de otra nota no (no se marca desde el cajón, como en la web)", JSON.stringify(con));
            const t = ventana.tarjetaInicio("Entrega de prueba con fecha");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.idInicio = t.modelData.id;
            ventana.clic(ventana.hijo(t, "casillaInicio"));
        }]],
        [[400, () => {
            const u = ventana.ultima();
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0 + 1 && u.op === "hecha" && u.id === ventana.idInicio && u.cuerpo.hecha === true, "Inicio: un clic en la casilla marca la tarea como hecha, con su id", ventana.ultimaJSON() + " " + (u ? u.id : "") + " / " + ventana.idInicio);
            ventana.comprobar(apiFalsa.tareas.secciones[1].tareas[0].hecha === true, "  y el servidor la tiene hecha");
            const t = ventana.tarjetaInicio("Entrega de prueba con fecha");
            const c = t ? ventana.hijo(t, "casillaInicio") : null;
            ventana.comprobar(!!c && c.marcada && t.modelData.cuando === "hecha hoy" && t.index === 0, "  y la tarjeta se queda en su sitio, marcada, para poder deshacerlo", t ? JSON.stringify(t.modelData) + " en " + t.index : "no está");
            ventana.comprobar(ventana.igual(ventana.textosInicio(), ["Entrega de prueba con fecha", "Tarea en otra nota", "Revisar la copia de seguridad", "Pausada que venció"]), "  y las demás siguen como estaban", JSON.stringify(ventana.textosInicio()));
            ventana.captura("4b-inicio-hecha");
        }]],
        [[300, () => {
            const t = ventana.tarjetaInicio("Entrega de prueba con fecha");
            ventana.idInicio = t.modelData.id;
            ventana.clic(ventana.hijo(t, "casillaInicio"));
        }]],
        [[400, () => {
            const u = ventana.ultima();
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0 + 2 && u.op === "hecha" && u.id === ventana.idInicio && u.cuerpo.hecha === false, "Inicio: otro clic la desmarca, con el id nuevo", ventana.ultimaJSON());
            const t = ventana.tarjetaInicio("Entrega de prueba con fecha");
            ventana.comprobar(!!t && !ventana.hijo(t, "casillaInicio").marcada && t.modelData.cuando === "vencida hace 2 días" && apiFalsa.tareas.secciones[1].tareas[0].hecha === false, "  y vuelve a estar abierta, en el servidor y en la tarjeta", t ? JSON.stringify(t.modelData) : "no está");
            const av = ventana.uno("textoAviso");
            ventana.comprobar(av === null, "  sin ningún aviso", av ? av.text : "");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.tarjetaInicio("Tarea en otra nota"));
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0, "Inicio: un clic en la de otra nota no escribe nada");
            apiFalsa.tareasOcupado = true;
            ventana.clic(ventana.hijo(ventana.tarjetaInicio("Revisar la copia de seguridad"), "casillaInicio"));
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0, "Inicio: con una escritura en camino, la casilla no manda otra");
            apiFalsa.tareasOcupado = false;
            apiFalsa.conflictoPendiente = true;
            ventana.clic(ventana.hijo(ventana.tarjetaInicio("Revisar la copia de seguridad"), "casillaInicio"));
        }]],
        [[500, () => {
            const av = ventana.uno("textoAviso");
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0 + 1 && !!av && av.text.indexOf("La nota cambió") === 0, "Inicio: un 409 avisa abajo", av ? av.text : "sin aviso");
            const t = ventana.tarjetaInicio("Cambiada desde Obsidian");
            ventana.comprobar(!!t && !t.modelData.hecha && ventana.tarjetaInicio("Revisar la copia de seguridad") === null && apiFalsa.tareas.secciones[0].tareas[0].hecha === false, "  y la tarjeta trae lo de fuera, sin marcar nada", JSON.stringify(ventana.textosInicio()));
            ventana.captura("4c-inicio-conflicto");
        }]],
        [[300, () => {
            // Todo como al principio, para lo que sigue (aunque algo de aquí
            // haya fallado).
            apiFalsa.conflictoPendiente = false;
            apiFalsa.tareasOcupado = false;
            apiFalsa.arrancar();
        }]],
        // Sin meta: ni la palabra.
        [[50, () => apiFalsa.inicio = Object.assign({}, apiFalsa.inicio, { metaPorcentaje: null })]],
        [[200, () => ventana.comprobar(!ventana.tiene("Meta") && !ventana.tiene("%  ") && !ventana.tiene("34 %"), "con metaPorcentaje null no sale la meta")]],
        [[50, () => apiFalsa.inicio = Object.assign({}, apiFalsa.inicio, { metaPorcentaje: 34 })]],
        // El punto del asa sigue al nivel de las alertas.
        [[50, () => apiFalsa.nivelAlertas = "ok"]],
        [[150, () => ventana.comprobar(Qt.colorEqual(ventana.colorPunto(), Theme.ok), "punto del asa: ok es verde")]],
        [[50, () => apiFalsa.nivelAlertas = "warn"]],
        [[150, () => ventana.comprobar(Qt.colorEqual(ventana.colorPunto(), Theme.warn), "punto del asa: warn es ámbar")]],
        [[50, () => apiFalsa.nivelAlertas = "error"]],
        [[150, () => ventana.comprobar(Qt.colorEqual(ventana.colorPunto(), Theme.danger), "punto del asa: error es rojo")]],
        [[50, () => apiFalsa.nivelAlertas = "desconocido"]],
        [[150, () => ventana.comprobar(Qt.colorEqual(ventana.colorPunto(), Theme.faint), "punto del asa: desconocido es gris apagado")]],
        [[50, () => apiFalsa.nivelAlertas = "error"]],
        // Cada estado de conexión.
        [[50, () => apiFalsa.conexion = "conectando"]],
        [[200, () => ventana.comprobar(ventana.tiene("Conectando con el NUC…"), "conexión «conectando»: su línea")]],
        [[50, () => apiFalsa.conexion = "sin-conexion"]],
        [[200, () => {
            ventana.comprobar(ventana.tiene("Sin conexión con el NUC") && ventana.tiene("Reintenta solo"), "conexión «sin-conexion»: su línea y que reintenta solo");
            ventana.captura("5-sin-conexion");
        }]],
        [[50, () => apiFalsa.conexion = "sin-credenciales"]],
        [[200, () => {
            ventana.comprobar(ventana.tiene("Falta la contraseña del panel en el llavero") && ventana.tiene('secret-tool store --label="Panel del homelab" servicio homelab-panel usuario <equipo>'), "conexión «sin-credenciales»: su línea y el comando");
            ventana.captura("6-sin-credenciales");
        }]],
        [[50, () => apiFalsa.conexion = "no-autorizado"]],
        [[200, () => ventana.comprobar(ventana.tiene("El NUC no acepta la contraseña de este equipo"), "conexión «no-autorizado»: su línea")]],
        [[50, () => apiFalsa.conexion = "conectado"]],
        [[200, () => ventana.comprobar(!ventana.tiene("Conectando") && !ventana.tiene("Sin conexión") && !ventana.tiene("llavero") && !ventana.tiene("no acepta"), "conectado: ya no sale ninguna línea de conexión")]],
        // Las notificaciones.
        [[50, () => {
            apiFalsa.alertaNueva({ id: "n1", nivel: "error", titulo: "Contenedor caído: caddy", detalle: "caddy lleva   3 minutos\nparado", desde: new Date(), vista: false });
            apiFalsa.alertaNueva({ id: "n2", nivel: "warn", titulo: "Disco al 85 %", detalle: "x".repeat(400), desde: new Date(), vista: false });
        }]],
        [[100, () => {
            const l = ventana.lanzadas;
            ventana.comprobar(l.length === 2, "cada alertaNueva lanza una notificación");
            ventana.comprobar(JSON.stringify(l[0]) === JSON.stringify(["notify-send", "-a", "Homelab", "-u", "critical", "Contenedor caído: caddy", "caddy lleva 3 minutos parado"]), "alerta error: notify-send -a Homelab -u critical, título y detalle");
            ventana.comprobar(l[1][4] === "normal" && l[1][5] === "Disco al 85 %", "alerta warn: urgencia normal");
            ventana.comprobar(l[1][6].length <= 160 && l[1][6].endsWith("…"), "el detalle largo se recorta");
            ventana.comprobar(l.join(" ").indexOf("€") < 0, "las notificaciones no llevan euros");
            ventana.comprobar(falso.abierto, "una alerta no cierra el cajón abierto");
        }]],
        // El abrir en la web usa la URL de la API.
        [[50, () => {
            falso.abierto = false;
            ventana.refrescosAntes = apiFalsa.refrescos;
        }]],
        [[700, () => {
            ventana.comprobar(apiFalsa.refrescos === ventana.refrescosAntes, "cerrar el cajón no refresca");
            apiFalsa.alertaNueva({ id: "n3", nivel: "error", titulo: "Otra alerta", detalle: "", desde: new Date(), vista: false });
        }]],
        [[300, () => ventana.comprobar(!falso.abierto && ventana.lanzadas.length === 3, "con el cajón cerrado, una alerta avisa pero no lo abre")]],
        [[50, () => falso.abierto = true]],
        [[800, () => ventana.comprobar(apiFalsa.refrescos === ventana.refrescosAntes + 1, "al abrir otra vez, otro refrescar")]],
        // =====================================================================
        // Fase 3: Tareas
        // =====================================================================
        [[50, () => ventana.seccion("tareas")]],
        [[700, () => {
            ventana.comprobar(ventana.ui() !== null, "la tira de secciones lleva a Tareas");
            ventana.comprobar(ventana.tiene("AHORA") && ventana.uno("campoNueva") !== null, "Tareas enseña «Ahora» y la fila de añadir");
            ventana.comprobar(ventana.igual(ventana.ahoraPlanos(), ["Fijada a mano sin fecha", "Entrega de prueba con fecha", "Revisar la copia de seguridad"]), "«Ahora»: la fijada primero, y después las más urgentes", JSON.stringify(ventana.ahoraPlanos()));
            ventana.comprobar(ventana.ahoraPlanos().indexOf("Empieza la semana que viene") < 0, "«Ahora» no lleva lo que aún no ha empezado");
            ventana.comprobar(ventana.ahoraPlanos().indexOf("Pausada que venció") < 0, "«Ahora» no lleva lo de En pausa");
            const cuentas = ventana.porNombre("cuentaAtras").map(x => x.text);
            ventana.comprobar(ventana.igual(cuentas, ["sin fecha", "vencida", "hoy"]), "las tarjetas llevan la cuenta atrás", JSON.stringify(cuentas));
            ventana.comprobar(ventana.igual(ventana.claves(), ["plazo|Esta semana", "plazo|Con fecha más adelante", "plazo|Sin fecha", "pausa", "hechas"]), "vista Plazo: esta semana, más adelante, sin fecha, En pausa y Hechas", JSON.stringify(ventana.claves()));
            ventana.captura("7-tareas-foco");
        }]],
        [[50, () => {
            const g = ventana.grupos().find(x => x.objectName === "grupo-plazo|Esta semana");
            ventana.comprobar(!!g && ventana.igual(ventana.planos(g), ["Empieza la semana que viene", "Cambiar los discos del NAS"]), "Plazo: dentro de un grupo, por prioridad de hoy y fecha (la de «Ahora» no se repite)", g ? JSON.stringify(ventana.planos(g)) : "sin grupo");
            ventana.comprobar(ventana.grupoPlegado("pausa") === true && ventana.grupoPlegado("hechas") === true && ventana.grupoPlegado("plazo|Sin fecha") === false, "En pausa y Hechas empiezan plegados; los demás, no");
            ventana.comprobar(!ventana.tiene("Pausada que venció") && !ventana.tiene("Ya hecha"), "lo plegado no se ve");
        }]],
        // Vistas.
        [[50, () => ventana.clic(ventana.uno("vista-proyecto"))]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.claves(), ["proyecto|homelab", "proyecto|clase", "proyecto|general", "pausa", "hechas"]), "vista Proyecto: un grupo por sección de la nota", JSON.stringify(ventana.claves()));
            const g = ventana.grupos().find(x => x.objectName === "grupo-proyecto|homelab");
            let cuadrado = null;
            ventana.recorrer(g, it => {
                if (it.objectName === "" && it.radius === 2 && it.implicitWidth === 8)
                    cuadrado = it;
            });
            ventana.comprobar(!!cuadrado && Qt.colorEqual(cuadrado.color, "#6aa8ff"), "  con el cuadrado del color del proyecto", cuadrado ? String(cuadrado.color) : "sin cuadrado");
            ventana.captura("8-tareas-proyecto");
        }]],
        [[50, () => ventana.clic(ventana.uno("vista-prioridad"))]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.claves(), ["prioridad|maxima", "prioridad|media", "prioridad|baja", "prioridad|minima", "pausa", "hechas"]), "vista Prioridad: un grupo por nivel, el de hoy (lo que vence hoy ya es máxima)", JSON.stringify(ventana.claves()));
            const g = ventana.grupos().find(x => x.objectName === "grupo-prioridad|media");
            let punto = null;
            ventana.recorrer(g, it => {
                if (it.objectName === "" && it.radius === 4 && it.implicitWidth === 8)
                    punto = it;
            });
            ventana.comprobar(!!punto && Qt.colorEqual(punto.color, Theme.prioMedia), "  con el punto del color de la prioridad", punto ? String(punto.color) : "sin punto");
            const m = ventana.grupos().find(x => x.objectName === "grupo-prioridad|maxima");
            ventana.comprobar(!!m && ventana.igual(ventana.planos(m), ["Entrega de prueba con fecha", "Revisar la copia de seguridad", "Empieza la semana que viene"]), "  y dentro, lo más cercano primero", m ? JSON.stringify(ventana.planos(m)) : "");
            ventana.captura("9-tareas-prioridad");
        }]],
        [[50, () => ventana.clic(ventana.uno("vista-todas"))]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.claves(), ["todas|todas", "pausa", "hechas"]), "vista Todas: un solo grupo", JSON.stringify(ventana.claves()));
            ventana.comprobar(ventana.filasDe(ventana.grupos()[0]).length === 7, "  con las 7 abiertas (sin las de En pausa)", String(ventana.filasDe(ventana.grupos()[0]).length));
        }]],
        [[50, () => ventana.clic(ventana.uno("vista-plazo"))]],
        // Plegar y desplegar.
        [[500, () => {
            ventana.comprobar(ventana.tiene("Una tarea sin proyecto"), "Plazo: «Sin fecha» desplegado enseña su tarea");
            ventana.clic(ventana.cabecera("plazo|Sin fecha"));
        }]],
        [[700, () => {
            ventana.comprobar(ventana.grupoPlegado("plazo|Sin fecha") === true && !ventana.tiene("Una tarea sin proyecto"), "clic en la cabecera de un grupo lo pliega");
            ventana.clic(ventana.cabecera("plazo|Sin fecha"));
        }]],
        [[700, () => ventana.comprobar(ventana.grupoPlegado("plazo|Sin fecha") === false && ventana.tiene("Una tarea sin proyecto"), "y otro clic lo despliega")]],
        [[50, () => ventana.clic(ventana.uno("plegarTodo"))]],
        [[700, () => {
            ventana.comprobar(ventana.grupos().every(g => g.plegado), "«Contraer» pliega todos los grupos");
            ventana.clic(ventana.uno("plegarTodo"));
        }]],
        [[700, () => {
            ventana.comprobar(ventana.grupos().every(g => !g.plegado), "y «Expandir» los despliega todos");
            // Como al empezar: En pausa y Hechas plegados.
            ventana.ui().plegados = ({});
        }]],
        // Hecha, desde la tarjeta.
        [[300, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.hijo(ventana.filaDe("Entrega de prueba con fecha", "a"), "casillaTarjeta"));
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0 + 1 && ventana.ultima().op === "hecha" && ventana.ultima().cuerpo.hecha === true, "la casilla de una tarjeta marca la tarea como hecha", ventana.ultimaJSON());
            ventana.comprobar(ventana.ahoraPlanos().indexOf("Entrega de prueba con fecha") < 0, "  y sale de «Ahora»", JSON.stringify(ventana.ahoraPlanos()));
            ventana.comprobar(apiFalsa.tareas.secciones[1].tareas[0].hecha === true, "  y la lista que vuelve la trae hecha");
            ventana.comprobar(!ventana.igual(ventana.ahoraPlanos().slice(0, 1), ["Entrega de prueba con fecha"]) && ventana.ahoraPlanos().length === 3, "  y «Ahora» se vuelve a llenar hasta tres", JSON.stringify(ventana.ahoraPlanos()));
        }]],
        // Deshacer: la casilla de la fila en Hechas.
        [[50, () => {
            ventana.ui().plegados = ({ "hechas": false });
        }]],
        [[700, () => {
            ventana.traer(ventana.cabecera("hechas"));
        }]],
        [[100, () => {
            const f = ventana.filaDe("Entrega de prueba con fecha", "r");
            ventana.comprobar(!!f && f.t.hecha === true, "Hechas, desplegado, enseña la tarea hecha", f ? "" : "no está");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.traer(f);
            ventana.clic(ventana.hijo(f, "casillaFila"));
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "hecha" && ventana.ultima().cuerpo.hecha === false, "la casilla de una hecha la vuelve a abrir", ventana.ultimaJSON());
            ventana.ui().plegados = ({});
        }]],
        // Detalles de una fila, y fijar.
        [[300, () => {
            ventana.clicFila("Cambiar los discos del NAS", ventana.filaDe("Cambiar los discos del NAS", "r") ? "r" : "a");
        }]],
        [[700, () => {
            const f = ventana.filaDe("Cambiar los discos del NAS", "r");
            ventana.comprobar(ventana.ui().abiertos["r" + f.t.linea] === true && ventana.tiene("DETALLES") && ventana.tiene("Fijar en «Ahora»"), "un clic en una fila despliega sus detalles");
            ventana.comprobar(ventana.ui().seleccion.ctx === "r" && ventana.ui().seleccion.linea === f.t.linea, "  y la elige");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.hijo(f, "fijarTarea"));
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { fijada: true }), "«Fijar en Ahora» manda fijada: true", ventana.ultimaJSON());
            ventana.comprobar(ventana.igual(ventana.ahoraPlanos(), ["Cambiar los discos del NAS", "Fijada a mano sin fecha", "Entrega de prueba con fecha"]), "  y la fijada pasa a «Ahora»: las fijadas primero y se rellena hasta tres", JSON.stringify(ventana.ahoraPlanos()));
        }]],
        // Añadir.
        [[100, () => {
            const c = ventana.uno("campoNueva");
            c.enfocar();
            c.texto = "Tarea nueva de prueba";
        }]],
        [[100, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla(Qt.Key_Return);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { seccion: "general", texto: "Tarea nueva de prueba", prioridad: "media" }), "Intro en la fila de añadir: tarea nueva en General con prioridad media", ventana.ultimaJSON());
            ventana.comprobar(ventana.uno("campoNueva").texto === "", "  y el campo se vacía");
            ventana.comprobar(ventana.tiene("Tarea nueva de prueba"), "  y la tarea sale en la lista");
        }]],
        [[50, () => ventana.clic(ventana.uno("opcionesAnadir"))]],
        [[600, () => {
            ventana.comprobar(ventana.uno("opcionesNueva") !== null && ventana.uno("opSeccion-clase") !== null, "el botón de opciones enseña sección, prioridad y fecha");
            ventana.captura("11-tareas-anadir");
            ventana.clic(ventana.uno("opSeccion-clase"));
        }]],
        [[100, () => ventana.clic(ventana.uno("opPrio-alta"))]],
        [[100, () => ventana.clic(ventana.uno("opManana"))]],
        [[100, () => {
            ventana.comprobar(ventana.uno("opFecha").texto === "2026-10-21", "«Mañana» pone la fecha de mañana (la de hoy del NUC más uno)", ventana.uno("opFecha").texto);
            const c = ventana.uno("campoNueva");
            c.texto = "Entrega con fecha";
            ventana.uno("opcionesNueva").area = "Aules";
            ventana.clic(ventana.uno("botonAnadir"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { seccion: "clase", texto: "Entrega con fecha", prioridad: "alta", area: "Aules", fecha: "2026-10-21" }), "añadir con opciones: sección, prioridad, área y fecha", ventana.ultimaJSON());
            ventana.clic(ventana.uno("opcionesAnadir"));
        }]],
        // Editar el texto, desde el atajo e.
        [[600, () => {
            ventana.clicFila("Leer el tema 4", "r");
        }]],
        [[400, () => {
            ventana.tecla("e");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.uno("editorTexto") !== null && ventana.uno("editorGuardar") !== null, "e abre el editor de la tarea elegida");
            ventana.comprobar(ventana.uno("editorTexto").texto === "Leer el tema 4", "  con su texto");
            ventana.comprobar(apiFalsa.editandoTarea === true, "  y avisa a la API de que se edita (para que una recarga de fuera espere)");
            ventana.traer(ventana.uno("editorTexto"));
            ventana.captura("12-tareas-editor");
        }]],
        [[400, () => {
            ventana.uno("editorTexto").texto = "Leer el tema 4 (editado)";
            ventana.clic(ventana.uno("opPrio-alta"));
        }]],
        [[100, () => ventana.clic(ventana.uno("opSinFecha"))]],
        [[100, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.uno("editorGuardar"));
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { texto: "Leer el tema 4 (editado)", fecha: "", prioridad: "alta" }), "guardar el editor manda solo lo que cambió", ventana.ultimaJSON());
            ventana.comprobar(ventana.uno("editorTexto") === null && apiFalsa.editandoTarea === false, "  y el editor se cierra");
            ventana.comprobar(ventana.tiene("Leer el tema 4 (editado)"), "  y el texto nuevo sale en la lista");
        }]],
        // Cancelar el editor con Escape.
        [[100, () => {
            ventana.clicFila("Leer el tema 4 (editado)", "r");
        }]],
        [[300, () => ventana.tecla("e")]],
        [[400, () => {
            ventana.comprobar(ventana.uno("editorTexto") !== null, "e vuelve a abrir el editor");
            ventana.uno("editorTexto").texto = "no se guarda";
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.uno("editorTexto") === null && apiFalsa.escrituras.length === ventana.escrituras0, "Escape cierra el editor sin escribir nada");
        }]],
        // Detalles y subtareas.
        [[300, () => ventana.clicFila("Revisar la copia de seguridad", "r")]],
        [[700, () => {
            ventana.comprobar(ventana.tiene("<b>Hecho</b>: lo de ayer") && ventana.tiene("Comprobar restic"), "el detalle enseña las líneas de detalle (la etiqueta en negrita)");
            ventana.comprobar(ventana.tiene("Mirar el log") && ventana.tiene("Probar una restauración") && ventana.tiene("SUBTAREAS · 1/2"), "  y las subtareas con su cuenta");
            const f = ventana.filaDe("Revisar la copia de seguridad", "r");
            ventana.traer(f);
            ventana.captura("10-tareas-detalle");
        }]],
        [[400, () => {
            const f = ventana.filaDe("Revisar la copia de seguridad", "r");
            ventana.clic(ventana.hijo(f, "editarDetalles"));
        }]],
        [[300, () => {
            const c = ventana.uno("campoDetalles");
            ventana.comprobar(c !== null && c.texto === "**Hecho**: lo de ayer\nComprobar restic", "«Editar detalles» abre un campo con las líneas");
            c.texto = "Una línea\nOtra línea\n\n";
            ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { detalles: ["Una línea", "Otra línea"] }), "Ctrl+Intro guarda los detalles (sin las líneas vacías)", ventana.ultimaJSON());
            ventana.comprobar(ventana.tiene("Otra línea") && !ventana.tiene("Comprobar restic"), "  y se ven en la lista");
        }]],
        [[50, () => {
            const f = ventana.filaDe("Revisar la copia de seguridad", "r");
            ventana.clic(ventana.hijo(f, "anadirSub"));
        }]],
        [[300, () => {
            const c = ventana.uno("campoSubNueva");
            ventana.comprobar(c !== null, "«Añadir subtarea» abre su campo");
            c.texto = "Subtarea nueva";
            ventana.tecla(Qt.Key_Return);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { subtareas: [{ texto: "Mirar el log", hecha: true }, { texto: "Probar una restauración", hecha: false }, { texto: "Subtarea nueva", hecha: false }] }), "Intro añade la subtarea al final y deja las demás como estaban", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("casillaSub")[0]);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo.subtareas.map(x => x.hecha), [false, false, false]), "la casilla de una subtarea la marca o la desmarca", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("textoSub")[1]);
        }]],
        [[300, () => {
            const c = ventana.porNombre("campoSub");
            ventana.comprobar(c.length === 1 && c[0].texto === "Probar una restauración", "un clic en el texto de una subtarea la edita");
            c[0].texto = "Probar la restauración";
            ventana.tecla(Qt.Key_Return);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo.subtareas.map(x => x.texto), ["Mirar el log", "Probar la restauración", "Subtarea nueva"]), "Intro guarda el texto nuevo de la subtarea", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("quitarSub")[0]);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo.subtareas.map(x => x.texto), ["Probar la restauración", "Subtarea nueva"]), "la × quita la subtarea", ventana.ultimaJSON());
            ventana.clicFila("Revisar la copia de seguridad", "r");
        }]],
        // Un 409: se recarga, se avisa y no se escribe nada.
        [[700, () => {
            ventana.comprobar(!ventana.tiene("Subtarea nueva"), "plegado el detalle, no se ven sus subtareas");
            apiFalsa.conflictoPendiente = true;
            ventana.escrituras0 = apiFalsa.escrituras.length;
            const f = ventana.filaDe("Una tarea sin proyecto", "r");
            ventana.traer(f);
            ventana.clic(ventana.hijo(f, "casillaFila"));
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0 + 1, "(se intentó la escritura)");
            const av = ventana.uno("textoAviso");
            ventana.comprobar(!!av && av.text.indexOf("La nota cambió") === 0, "un 409 enseña un aviso corto abajo", av ? av.text : "sin aviso");
            ventana.comprobar(apiFalsa.tareas.secciones[2].tareas[0].hecha === false, "  y no marca nada");
            ventana.comprobar(ventana.tiene("Cambiada desde Obsidian"), "  y la lista recargada trae lo que cambió fuera");
            ventana.captura("13-tareas-conflicto");
        }]],
        // Un 409 con el editor abierto: se recarga y no se pisa lo de fuera.
        [[100, () => {
            ventana.clicFila("Cambiada desde Obsidian", "r");
        }]],
        [[300, () => ventana.tecla("e")]],
        [[400, () => {
            const e = ventana.uno("editorTexto");
            ventana.comprobar(e !== null, "(editor abierto otra vez)");
            e.texto = "Esto no debe llegar al servidor";
            apiFalsa.conflictoPendiente = true;
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.uno("editorGuardar"));
        }]],
        [[500, () => {
            const e = ventana.uno("editorTexto");
            ventana.comprobar(apiFalsa.tareas.secciones[0].tareas[0].texto === "Cambiada desde Obsidian", "un 409 al guardar el editor no deja lo escrito en el servidor");
            ventana.comprobar(ventana.uno("textoAviso") !== null && ventana.uno("textoAviso").text.indexOf("La nota cambió") === 0, "  y avisa");
            ventana.tecla(Qt.Key_Escape);
        }]],
        // =====================================================================
        // Los atajos
        // =====================================================================
        // Sin el foco del teclado, no hacen nada.
        [[400, () => {
            const t = ventana.filaDe("Una tarea sin proyecto", "r").t;
            ventana.ui().seleccion = { ctx: "r", linea: t.linea };
            otroFoco.forceActiveFocus();
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("x");
            ventana.tecla("p");
            ventana.tecla("1");
            ventana.tecla("n");
            ventana.tecla("/");
            ventana.tecla("?");
            ventana.tecla("j");
            ventana.comprobar(!ventana.ui().activeFocus, "(el foco del teclado está en otro sitio)");
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0 && !ventana.uno("campoNueva").enfocado && !ventana.uno("campoFiltro").enfocado && !ventana.ui().ayuda && ventana.ui().seleccion.linea === t.linea, "x, p, 1, n, / , ? y j no hacen nada sin el foco del teclado");
        }]],
        // Con el foco pero con el cajón cerrado, tampoco.
        [[50, () => {
            ventana.ui().enfocar();
            falso.abierto = false;
        }]],
        [[800, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("x");
            ventana.tecla("n");
            ventana.tecla("?");
            ventana.comprobar(ventana.ui().activeFocus && apiFalsa.escrituras.length === ventana.escrituras0 && !ventana.ui().ayuda, "con el cajón cerrado, los atajos tampoco hacen nada, aunque el foco esté aquí");
            falso.abierto = true;
        }]],
        [[900, () => {
            // Al abrir, el foco vuelve a Tareas (el teclado de verdad sigue siendo del cajón solo tras un clic).
            ventana.comprobar(ventana.ui().activeFocus, "al abrir el cajón, Tareas recupera el foco de los atajos");
            ventana.ui().seleccion = { ctx: "", linea: -1 };
            ventana.tecla("j");
        }]],
        [[200, () => {
            const o = ventana.ui().orden;
            ventana.comprobar(ventana.igual(ventana.ui().seleccion, o[0]), "j sin nada elegido elige la primera (la primera tarjeta de «Ahora»)", JSON.stringify(ventana.ui().seleccion));
            ventana.tecla("j");
        }]],
        [[200, () => {
            const o = ventana.ui().orden;
            ventana.comprobar(ventana.igual(ventana.ui().seleccion, o[1]), "j otra vez, la siguiente", JSON.stringify(ventana.ui().seleccion));
            ventana.tecla("k");
        }]],
        [[200, () => {
            const o = ventana.ui().orden;
            ventana.comprobar(ventana.igual(ventana.ui().seleccion, o[0]), "k vuelve a la anterior", JSON.stringify(ventana.ui().seleccion));
            ventana.tecla("k");
        }]],
        [[200, () => {
            ventana.comprobar(ventana.igual(ventana.ui().seleccion, ventana.ui().orden[0]), "k en la primera se queda en la primera");
            ventana.tecla(Qt.Key_Return);
        }]],
        [[600, () => {
            const s = ventana.ui().seleccion;
            ventana.comprobar(ventana.ui().abiertos[s.ctx + s.linea] === true, "Intro abre el detalle de la elegida");
            ventana.tecla("o");
        }]],
        [[600, () => {
            const s = ventana.ui().seleccion;
            ventana.comprobar(!ventana.ui().abiertos[s.ctx + s.linea], "o lo cierra");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("x");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "hecha" && ventana.ultima().cuerpo.hecha === true && apiFalsa.escrituras.length === ventana.escrituras0 + 1, "x marca como hecha la elegida", ventana.ultimaJSON());
            ventana.tecla("x");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "hecha" && ventana.ultima().cuerpo.hecha === false, "y otra x la desmarca", ventana.ultimaJSON());
            ventana.fijadaAntes = ventana.ui().elegida().fijada;
            ventana.tecla("p");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.ultima().cuerpo.fijada === !ventana.fijadaAntes, "p cambia lo de fijar en «Ahora» de la elegida", ventana.ultimaJSON());
            ventana.tecla("p");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && "fijada" in ventana.ultima().cuerpo, "y p otra vez lo deshace", ventana.ultimaJSON());
            // Prioridad: una de media.
            const t = ventana.filaDe("Una tarea sin proyecto", "r").t;
            ventana.ui().seleccion = { ctx: "r", linea: t.linea };
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("1");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { prioridad: "maxima" }), "1 pone la prioridad máxima", ventana.ultimaJSON());
            ventana.tecla("5");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { prioridad: "minima" }), "5 la mínima", ventana.ultimaJSON());
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("5");
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0, "la misma prioridad otra vez no escribe nada");
            ventana.tecla("3");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { prioridad: "media" }) && ventana.igual(ventana.filaDe("Una tarea sin proyecto", "r").t.prioridad, "media"), "3 la media", ventana.ultimaJSON());
            // n, el filtro y el campo.
            ventana.tecla("n");
        }]],
        [[200, () => {
            ventana.comprobar(ventana.uno("campoNueva").enfocado, "n enfoca el campo de añadir");
            ventana.tecla("j");
        }]],
        [[200, () => {
            ventana.comprobar(ventana.uno("campoNueva").texto === "j" || ventana.uno("campoNueva").texto === "", "mientras se escribe en un campo, los atajos no actúan (la j se escribe)", ventana.uno("campoNueva").texto);
            ventana.uno("campoNueva").texto = "";
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("x");
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0, "  y la x tampoco marca nada");
            ventana.uno("campoNueva").texto = "";
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[200, () => {
            ventana.comprobar(!ventana.uno("campoNueva").enfocado && ventana.ui().activeFocus && envoltura.escapes === 0, "Escape suelta el campo y no cierra el cajón");
            ventana.tecla("/");
        }]],
        [[200, () => {
            ventana.comprobar(ventana.uno("campoFiltro").enfocado, "/ enfoca el filtro");
            ventana.uno("campoFiltro").texto = "discos";
        }]],
        [[500, () => {
            ventana.comprobar(ventana.tiene("Nada coincide con el filtro.") && ventana.filasDe(ventana.ui()).filter(f => f.ctx === "r").length === 0 && ventana.ahoraPlanos().length === 3, "el filtro «discos» (esa tarea está en «Ahora», que no se filtra) no deja filas y lo dice", String(ventana.filasDe(ventana.ui()).filter(f => f.ctx === "r").length));
            ventana.uno("campoFiltro").texto = "tema";
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.filasDe(ventana.ui()).filter(f => f.ctx === "r").map(f => f.t.plano), ["Leer el tema 4 (editado)"]), "el filtro «tema» deja solo la tarea que lo lleva", JSON.stringify(ventana.filasDe(ventana.ui()).filter(f => f.ctx === "r").map(f => f.t.plano)));
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.uno("campoFiltro").texto === "" && ventana.uno("campoFiltro").enfocado, "Escape en el filtro lo vacía primero");
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[300, () => {
            ventana.comprobar(!ventana.uno("campoFiltro").enfocado && envoltura.escapes === 0, "y otro lo suelta, sin cerrar el cajón");
            ventana.tecla("?");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ui().ayuda === true && ventana.tiene("Atajos de las tareas") && ventana.tiene("Esta ayuda"), "? enseña la lista de atajos");
            ventana.captura("14-tareas-ayuda");
        }]],
        [[400, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla("x");
            ventana.tecla("j");
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0, "con la ayuda a la vista, el resto de atajos no actúan");
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ui().ayuda === false && envoltura.escapes === 0, "Escape cierra la ayuda y no el cajón");
            ventana.ui().seleccion = { ctx: "", linea: -1 };
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[300, () => ventana.comprobar(envoltura.escapes === 1, "con nada que cerrar, Escape sube hasta quien cierra el cajón", String(envoltura.escapes))]],
        // =====================================================================
        // Hábitos (en Inicio)
        // =====================================================================
        [[50, () => ventana.seccion("inicio")]],
        [[700, () => {
            ventana.comprobar(ventana.tiene("HÁBITOS DE HOY") && ventana.tiene("Gym") && ventana.tiene("Leído") && ventana.tiene("Programado") && ventana.tiene("Energía"), "Inicio enseña los hábitos de hoy: gym, leído, programado y energía");
            ventana.comprobar(ventana.tiene("3/7 semana") && ventana.tiene("6,5 media"), "  con los totales de la semana");
            const e = ventana.porNombre("habito-gym")[0].estado + "," + ventana.porNombre("habito-lectura")[0].estado + "," + ventana.porNombre("habito-programar")[0].estado;
            ventana.comprobar(e === "si,,no", "  y cómo está cada uno hoy (sí, sin marcar, no)", e);
            ventana.comprobar(Qt.colorEqual(ventana.porNombre("energia-7")[0].color, Qt.rgba(1, 1, 1, 0.22)), "  y la energía puesta (7) marcada");
            ventana.captura("15-habitos");
        }]],
        [[400, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.porNombre("habito-gym")[0]);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ultima().op === "habito" && ventana.ultima().id === "gym" && ventana.ultima().cuerpo.valor === "no", "un clic en el gym (sí) lo pasa a «no»", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("habito-gym")[0]);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ultima().cuerpo.valor === "" && ventana.porNombre("habito-gym")[0].estado === "", "otro clic lo deja sin marcar", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("habito-gym")[0]);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ultima().cuerpo.valor === "si" && ventana.porNombre("habito-gym")[0].estado === "si", "y otro, «sí»: el ciclo es sin marcar, sí, no", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("habito-lectura")[0]);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ultima().id === "lectura" && ventana.ultima().cuerpo.valor === "si", "leído: de sin marcar a «sí»", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("energia-3")[0]);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ultima().id === "energia" && ventana.ultima().cuerpo.valor === "3", "un clic en un número de la energía la pone", ventana.ultimaJSON());
            ventana.clic(ventana.porNombre("energia-3")[0]);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ultima().id === "energia" && ventana.ultima().cuerpo.valor === "" && apiFalsa.habitos.hoy.energia === null, "y otro clic en la que está puesta la quita", ventana.ultimaJSON());
            ventana.comprobar(ventana.textos().indexOf("€") < 0, "(sin euros en Inicio con los hábitos)");
        }]],
        // =====================================================================
        // Clase: Actualizar Aules
        // =====================================================================
        [[50, () => ventana.seccion("clase")]],
        [[700, () => {
            ventana.comprobar(ventana.uno("seccionClase") !== null && ventana.uno("botonAules") !== null, "la tira lleva a Clase, con el botón «Actualizar Aules»");
            const l = ventana.uno("lineaAules").text;
            ventana.comprobar(l === "Aules actualizado hace 2 h · 2 tareas nuevas, 1 fecha cambiada · calendario: 1 nuevo", "la línea de estado dice cuándo y qué cambió", l);
            ventana.captura("16-clase");
        }]],
        [[400, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.uno("botonAules"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.ultima().op === "aules" && apiFalsa.escrituras.length === ventana.escrituras0 + 1, "el botón lanza la actualización", ventana.ultimaJSON());
            ventana.comprobar(ventana.uno("lineaAules").text.indexOf("Actualizando Aules…") === 0 && ventana.uno("botonAules").texto === "Actualizando…" && !ventana.uno("botonAules").encendido, "  la línea dice que está en marcha y el botón se apaga");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.uno("botonAules"));
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.escrituras.length === ventana.escrituras0, "con una en marcha, otro clic no lanza otra");
            ventana.captura("17-clase-en-marcha");
            // El evento «clase»: la actualización acaba.
            ventana.lecturas0 = apiFalsa.lecturasTareas;
            apiFalsa.eventoClase({ estado: "ok", ejecutando: false, terminado: new Date(), error: "", tareas: { anadidas: 3, fechas: 0, completadas: 1, error: "" }, calendario: null, calendarioConectado: false, calendarioPersonalError: "" });
        }]],
        [[300, () => {
            const l = ventana.uno("lineaAules").text;
            ventana.comprobar(l === "Aules actualizado hace un momento · 3 tareas nuevas, 1 entregada", "el evento «clase» cambia la línea sin tocar nada", l);
            ventana.comprobar(ventana.uno("botonAules").encendido, "  y el botón vuelve");
            ventana.comprobar(apiFalsa.lecturasTareas === ventana.lecturas0 + 1, "  y, como acabó una en marcha, se vuelven a leer las tareas", String(apiFalsa.lecturasTareas - ventana.lecturas0));
            apiFalsa.eventoClase({ estado: "error", ejecutando: false, terminado: new Date(Date.now() - 600000), error: "aules-sync falló (exit-code)", tareas: null, calendario: null, calendarioConectado: false, calendarioPersonalError: "no hay token" });
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("lineaAules").text === "aules-sync falló (exit-code) (hace 10 min)", "un error de la última, con cuándo", ventana.uno("lineaAules").text);
            ventana.comprobar(ventana.uno("lineaCalPersonal") !== null && ventana.uno("lineaCalPersonal").text.indexOf("no hay token") > 0, "  y el fallo del calendario «Personal», si lo hubo");
            ventana.captura("18-clase-error");
            apiFalsa.eventoClase({ estado: "nunca", ejecutando: false, terminado: null, error: "", tareas: null, calendario: null, calendarioConectado: false, calendarioPersonalError: "" });
        }]],
        [[300, () => ventana.comprobar(ventana.uno("lineaAules").text === "Aules todavía no se ha actualizado desde el panel.", "estado «nunca»")]],
        [[50, () => {
            apiFalsa.eventoClase({ estado: "sin-unidad", ejecutando: false, terminado: null, error: "No está la unidad aules-sync.", tareas: null, calendario: null, calendarioConectado: false, calendarioPersonalError: "" });
        }]],
        [[300, () => ventana.comprobar(ventana.uno("lineaAules").text === "No está la unidad aules-sync." && !ventana.uno("botonAules").encendido, "sin la unidad en el NUC: lo dice y el botón se apaga")]],
        // =====================================================================
        // El evento «tareas»
        // =====================================================================
        [[50, () => ventana.seccion("tareas")]],
        [[700, () => {
            ventana.lecturas0 = apiFalsa.lecturasTareas;
            const v = apiFalsa.cambioExterno("Texto cambiado en Obsidian");
            ventana.versionNueva = v;
            apiFalsa.eventoTareas(apiFalsa.versionCargada);
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.lecturasTareas === ventana.lecturas0, "un evento «tareas» con la versión que ya se tiene no vuelve a leer");
            apiFalsa.eventoTareas(ventana.versionNueva);
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.lecturasTareas === ventana.lecturas0 + 1 && ventana.tiene("Texto cambiado en Obsidian"), "con otra versión, relee las tareas y la lista se pone al día", String(apiFalsa.lecturasTareas - ventana.lecturas0));
        }]],
        // Con una tarea en edición: se marca como obsoleta y se espera.
        [[50, () => {
            ventana.clicFila("Texto cambiado en Obsidian", "r");
        }]],
        [[300, () => ventana.tecla("e")]],
        [[500, () => {
            ventana.comprobar(ventana.uno("editorTexto") !== null && apiFalsa.editandoTarea, "(editando una tarea)");
            ventana.uno("editorTexto").texto = "Lo que estoy escribiendo";
            ventana.lecturas0 = apiFalsa.lecturasTareas;
            ventana.versionNueva = apiFalsa.cambioExterno("Otro cambio desde la web");
            apiFalsa.eventoTareas(ventana.versionNueva);
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.lecturasTareas === ventana.lecturas0 && apiFalsa.tareasObsoletas === true, "un evento «tareas» mientras se edita: se marca como obsoleta y no relee");
            ventana.comprobar(ventana.uno("editorTexto") !== null && ventana.uno("editorTexto").texto === "Lo que estoy escribiendo", "  y no toca lo que se está escribiendo");
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.lecturasTareas === ventana.lecturas0 + 1 && apiFalsa.tareasObsoletas === false && ventana.tiene("Otro cambio desde la web"), "al cerrar el editor, relee las tareas y se pone al día", String(apiFalsa.lecturasTareas - ventana.lecturas0));
            ventana.comprobar(ventana.textos().indexOf("€") < 0, "(sin euros en Tareas)");
        }]],
        // Mejoras pequeñas de Tareas: la cuenta, lo que se recuerda, «Reintentar» y el pie del detalle.
        [[50, () => ventana.seccion("tareas")]],
        [[500, () => ventana.clic(ventana.uno("vista-todas"))]],
        [[400, () => {
            const c = ventana.uno("cuentaTareas");
            ventana.comprobar(!!c && /^\d+ abiertas · \d+ vencidas?$/.test(c.text), "la cabecera de Tareas cuenta las abiertas y las vencidas", c ? c.text : "sin cuenta");
            ventana.plegadoAntes = ventana.grupoPlegado("hechas");
            ventana.clic(ventana.cabecera("hechas"));
        }]],
        [[1200, () => {
            ventana.comprobar(ventana.grupoPlegado("hechas") === !ventana.plegadoAntes, "un clic en la cabecera de Hechas la pliega o la despliega");
            ventana.lector = lectorEstado.createObject(ventana);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.lector.vistaLeida === "todas" && ventana.lector.plegadosLeidos !== null && ventana.lector.plegadosLeidos["hechas"] === !ventana.plegadoAntes, "la vista y los grupos plegados se guardan y se leen al volver a arrancar", ventana.lector ? ventana.lector.vistaLeida + " " + JSON.stringify(ventana.lector.plegadosLeidos) : "");
            ventana.lector.destroy();
            ventana.clic(ventana.uno("vista-plazo"));
        }]],
        [[300, () => ventana.clic(ventana.cabecera("hechas"))]],
        [[800, () => {
            ventana.lector = lectorEstado.createObject(ventana);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.lector.vistaLeida === "plazo" && ventana.lector.plegadosLeidos["hechas"] === ventana.plegadoAntes, "y el último cambio es el que queda", ventana.lector ? ventana.lector.vistaLeida + " " + JSON.stringify(ventana.lector.plegadosLeidos) : "");
            ventana.lector.destroy();
        }]],
        // El pie del detalle: ⏳ y «fijada en Ahora».
        [[300, () => ventana.clicFila("Leer el tema 4", "r")]],
        [[600, () => {
            const pies = ventana.porNombre("pieDetalle").map(x => x.text);
            ventana.comprobar(pies.some(x => x.indexOf("\u23f3 23 oct") >= 0), "el pie del detalle enseña la fecha programada con ⏳", JSON.stringify(pies));
            ventana.comprobar(!pies.some(x => x.indexOf("\u23f3") >= 0 && x.indexOf("fijada") >= 0), "  y la fijada no la lleva (no es la misma tarea)");
        }]],
        [[400, () => ventana.clicFila("Fijada a mano sin fecha", "a")]],
        [[600, () => {
            const pies = ventana.porNombre("pieDetalle").map(x => x.text);
            ventana.comprobar(pies.some(x => x.indexOf("fijada en \u00abAhora\u00bb") >= 0), "  y «fijada en «Ahora»» si lo está", JSON.stringify(pies));
        }]],
        // Sin datos y con error: «Reintentar» vuelve a pedirlas.
        [[300, () => {
            apiFalsa.tareas = null;
            apiFalsa.tareasError = "No se pudieron leer las tareas";
        }]],
        [[300, () => {
            const b = ventana.uno("reintentarTareas");
            ventana.comprobar(!!b && ventana.uno("tareasSinDatos").text === "No se pudieron leer las tareas", "sin datos y con error, Tareas ofrece «Reintentar»");
            ventana.lecturas0 = apiFalsa.lecturasTareas;
            ventana.clic(b);
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.lecturasTareas === ventana.lecturas0 + 1 && ventana.uno("reintentarTareas") === null && ventana.uno("campoNueva") !== null, "«Reintentar» vuelve a leer las tareas y la lista reaparece", String(apiFalsa.lecturasTareas - ventana.lecturas0));
            ventana.seccion("inicio");
        }]],
        // El chip de Inicio.
        [[500, () => {
            const t = ventana.uno("textoPlazos");
            ventana.comprobar(!!t && /vencidas?/.test(t.text) && t.text.indexOf("para hoy") > 0, "Inicio enseña el chip de lo vencido y lo de hoy", t ? t.text : "sin chip");
            ventana.captura("7b-inicio-chip");
        }]],
        // =====================================================================
        // Fase 4: Proyectos
        // =====================================================================
        [[50, () => {
            ventana.cualquiera("contenido").lanzar = args => ventana.enlaces = ventana.enlaces.concat([args]);
            ventana.escapes0 = envoltura.escapes;
            ventana.lecturas0 = apiFalsa.lecturasGithub;
            ventana.seccion("proyectos");
        }]],
        [[700, () => {
            ventana.comprobar(ventana.uno("seccionProyectos") !== null, "la tira lleva a Proyectos");
            ventana.comprobar(apiFalsa.lecturasGithub === ventana.lecturas0 + 1, "al entrar en Proyectos se pide el resumen de GitHub (una vez)", String(apiFalsa.lecturasGithub - ventana.lecturas0));
            const g = ventana.nombresCon("grupoProyectos-");
            ventana.comprobar(ventana.igual(g, ["activo", "pausado", "idea", "otros"]), "los proyectos van por estado: activos, pausados, ideas y otros (el archivado)", JSON.stringify(g));
            ventana.comprobar(ventana.tiene("ACTIVOS · 1") && ventana.tiene("PAUSADOS · 1") && ventana.tiene("OTROS · 1"), "  con la cuenta de cada grupo");
            ventana.comprobar(ventana.uno("sub-Panel en el escritorio") !== null && ventana.uno("sub-Finanzas") !== null && ventana.uno("proyecto-Panel en el escritorio") === null, "los subproyectos salen dentro de su proyecto, no sueltos");
            ventana.comprobar(ventana.tiene("Fase 4 del panel en el escritorio") && !ventana.tiene("**panel**") && ventana.tiene("60 %"), "cada proyecto enseña su progreso y su primer siguiente paso, sin marcas");
            ventana.comprobar(ventana.tiene(" 2") && ventana.tiene(" 1"), "  y cuántas PR e issues tiene abiertas su repo");
            ventana.captura("19-proyectos");
        }]],
        [[300, () => ventana.clic(ventana.uno("proyecto-Homelab"), 80, 14)]],
        [[600, () => {
            ventana.comprobar(ventana.uno("detalleProyecto") !== null && ventana.uno("tituloProyecto").text === "Homelab", "un clic en un proyecto lo abre");
            ventana.comprobar(apiFalsa.reposPedidos.indexOf("IshimiG/homelab") >= 0, "  y pide las PR e issues de su repo", JSON.stringify(apiFalsa.reposPedidos));
            ventana.comprobar(ventana.tiene("#7  Panel del homelab en el escritorio, fase 2") && ventana.tiene("panel-fase2 → main") && ventana.tiene("borrador"), "  que salen en la lista, con sus ramas y si son borrador");
            ventana.comprobar(ventana.uno("estado-activo").activo && ventana.uno("prioridadProyecto-alta").activo && ventana.uno("textoProgreso").text === "60 %", "  con el estado, la prioridad y el progreso de ahora");
            ventana.captura("20-proyecto");
            ventana.clic(ventana.uno("estado-pausado"));
        }]],
        [[400, () => {
            const u = ventana.ultimaProyecto();
            ventana.comprobar(!!u && u.ruta === "30 Áreas/Servidor/22-ecosistema.md" && ventana.igual(u.cambios, { estado: "pausado" }), "un clic en otro estado lo guarda en la nota", JSON.stringify(u));
            ventana.comprobar(ventana.uno("estado-pausado").activo && ventana.uno("tituloProyecto") !== null, "  y se queda en el proyecto, con el estado nuevo");
            ventana.clic(ventana.uno("estado-activo"));
        }]],
        [[400, () => ventana.clic(ventana.uno("prioridadProyecto-ninguna"))]],
        [[400, () => {
            ventana.comprobar(ventana.igual(ventana.ultimaProyecto().cambios, { prioridad: "" }), "«Sin prioridad» la quita", JSON.stringify(ventana.ultimaProyecto()));
            ventana.clic(ventana.uno("prioridadProyecto-alta"));
        }]],
        [[400, () => {
            const d = ventana.uno("progresoProyecto");
            ventana.clic(d, d.width * 0.25, d.height / 2);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.igual(ventana.ultimaProyecto().cambios, { progreso: 25 }), "un clic en la barra del progreso lo pone, de 5 en 5", JSON.stringify(ventana.ultimaProyecto()));
            ventana.comprobar(ventana.uno("textoProgreso").text === "25 %", "  y se ve", ventana.uno("textoProgreso").text);
            ventana.clic(ventana.uno("editarSiguiente"));
        }]],
        [[400, () => {
            const c = ventana.uno("campoSiguiente");
            ventana.comprobar(c !== null && c.texto === "Fase 4 del **panel** en el escritorio\nLos hashes de Caddy", "«Editar» el siguiente paso abre un campo con los del bloque del panel", c ? JSON.stringify(c.texto) : "");
            c.texto = "Uno\nDos";
            ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.igual(ventana.ultimaProyecto().cambios, { siguiente: "Uno\nDos" }), "Ctrl+Intro lo guarda", JSON.stringify(ventana.ultimaProyecto()));
            ventana.comprobar(ventana.uno("campoSiguiente") === null && ventana.tiene("•  Uno") && ventana.tiene("•  Dos"), "  y el campo se cierra con los pasos nuevos");
            ventana.edicionesAntes = apiFalsa.edicionesProyecto.length;
            ventana.clic(ventana.uno("editarSiguiente"));
        }]],
        [[300, () => {
            ventana.uno("campoSiguiente").texto = "no se guarda";
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("campoSiguiente") === null && apiFalsa.edicionesProyecto.length === ventana.edicionesAntes && ventana.uno("tituloProyecto") !== null && envoltura.escapes === ventana.escapes0, "Escape en el campo lo cierra sin guardar y sigue en el proyecto", String(envoltura.escapes - ventana.escapes0));
            ventana.clic(ventana.uno("pestana-issues"));
        }]],
        [[300, () => {
            ventana.comprobar(ventana.tiene("#12  Una issue abierta") && !ventana.tiene("#7  Panel del homelab"), "la pestaña Issues enseña las issues");
            falso.fijado = true;
            ventana.clic(ventana.uno("github-12"));
        }]],
        [[300, () => {
            ventana.comprobar(ventana.igual(ventana.enlaces[ventana.enlaces.length - 1], ["xdg-open", "https://github.com/IshimiG/homelab/issues/12"]), "un clic en una issue la abre en el navegador", JSON.stringify(ventana.enlaces));
            ventana.comprobar(falso.abierto, "  y, con el cajón fijado, el cajón se queda");
            falso.fijado = false;
            ventana.clic(ventana.uno("subDetalle-Panel en el escritorio"));
        }]],
        [[500, () => {
            ventana.comprobar(ventana.uno("tituloProyecto").text === "Panel en el escritorio" && ventana.uno("irAlPadre") !== null, "un subproyecto se abre desde su proyecto, con un botón para volver a él");
            ventana.comprobar(ventana.uno("repoProyecto").text === "IshimiG/homelab · el de Homelab", "  sin repo propio, enseña el de su proyecto", ventana.uno("repoProyecto").text);
            ventana.comprobar(ventana.tiene("Sale de la sección «Siguiente paso» de la nota.") && ventana.tiene("•  Fusionar la fase 2"), "  y su siguiente paso de la sección de la nota, sin marcas");
            apiFalsa.conflictoProyecto = true;
            ventana.clic(ventana.uno("estado-idea"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.textoAviso().indexOf("El proyecto cambió en tus notas") === 0, "un 409 al guardar un proyecto avisa", ventana.textoAviso());
            ventana.comprobar(ventana.uno("estado-activo").activo && ventana.uno("textoProgreso").text === "70 %", "  y enseña el proyecto como está ahora, sin el cambio", ventana.uno("textoProgreso").text);
            ventana.clic(ventana.uno("irAlPadre"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.uno("tituloProyecto") !== null && ventana.uno("tituloProyecto").text === "Homelab", "el botón del proyecto vuelve a él");
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.uno("tituloProyecto") === null && ventana.uno("desplazableProyectos") !== null && envoltura.escapes === ventana.escapes0 && falso.abierto, "Escape en un proyecto vuelve a la lista, sin cerrar el cajón", String(envoltura.escapes - ventana.escapes0));
        }]],
        // =====================================================================
        // Fase 4: Servidor
        // =====================================================================
        [[50, () => ventana.seccion("servidor")]],
        [[700, () => {
            ventana.comprobar(ventana.uno("seccionServidor") !== null && apiFalsa.verConsumo === true, "la tira lleva a Servidor, y con él a la vista se lee el consumo");
            ventana.comprobar(ventana.tiene("12 %") && ventana.tiene("carga 0,52") && ventana.tiene("6,0 GiB") && ventana.tiene("38 % de 16 GiB") && ventana.tiene("80 % de 500 GiB") && ventana.tiene("sin montar"), "el consumo: CPU, RAM y discos (uno sin montar)");
            ventana.comprobar(ventana.igual(ventana.nombresCon("stack-"), ["homelab", "sync", "immich", ""]), "los stacks, con los contenedores sueltos al final", JSON.stringify(ventana.nombresCon("stack-")));
            ventana.comprobar(ventana.estadoDe("caddy") === "arriba hace 3 h · sano  ·  CPU 3,0 % · RAM 120 MiB", "un contenedor en marcha: desde cuándo, su salud y lo que gasta", ventana.estadoDe("caddy"));
            ventana.comprobar(ventana.estadoDe("vaultwarden") === "parado hace 2 días · código 1" && ventana.estadoDe("immich_server") === "con fallos · arriba hace 3 h", "  uno parado con su código, y uno con fallos", ventana.estadoDe("vaultwarden") + " | " + ventana.estadoDe("immich_server"));
            ventana.comprobar(ventana.uno("accion-caddy-stop") !== null && ventana.uno("accion-caddy-restart") !== null && ventana.uno("accion-vaultwarden-start") !== null && ventana.uno("accion-vaultwarden-stop") === null && ventana.uno("logs-pdftotext-prueba") !== null && ventana.nombresCon("accion-pdftotext").length === 0, "cada contenedor, los botones de su estado (los de la web), solo si el NUC los permite");
            ventana.comprobar(ventana.uno("accionStack-immich-stop") !== null && ventana.uno("accionStack-immich-up") === null && ventana.uno("menuStack-immich") === null && ventana.uno("accionStack-homelab-up") !== null && ventana.nombresCon("accionStack--").length === 0, "cada stack: levantar o parar todo según lo que esté en marcha; nada en los que no son del panel");
            ventana.captura("21-servidor");
        }]],
        [[300, () => ventana.clic(ventana.uno("accion-syncthing-restart"))]],
        [[150, () => {
            ventana.comprobar(ventana.igual(ventana.ultimaAccion(), { tipo: "contenedor", nombre: "syncthing", accion: "restart", confirmacion: "" }), "Reiniciar (sin palabra) sale al momento, sin confirmación", JSON.stringify(ventana.ultimaAccion()));
            ventana.comprobar(ventana.uno("confirmarServidor") === null, "  (no sale la confirmación)");
            ventana.comprobar(ventana.estadoDe("syncthing") === "restart…" && ventana.uno("accion-syncthing-stop") === null, "  y mientras dura, el contenedor dice en qué paso va y no lleva botones", ventana.estadoDe("syncthing"));
        }]],
        [[700, () => {
            ventana.comprobar(ventana.textoAviso() === "Reiniciar · syncthing: hecho", "al acabar (evento «result») sale cómo acabó", ventana.textoAviso());
            ventana.comprobar(ventana.estadoDe("syncthing").indexOf("arriba") === 0, "  y el contenedor vuelve a su estado", ventana.estadoDe("syncthing"));
            ventana.acciones0 = apiFalsa.acciones.length;
            ventana.clic(ventana.uno("accion-caddy-stop"));
        }]],
        [[400, () => {
            const c = ventana.uno("confirmarServidor");
            ventana.comprobar(c !== null && ventana.uno("tituloConfirmar").text === "Parar · caddy", "Parar caddy (el que abre el panel) pide confirmación");
            ventana.comprobar(ventana.uno("textoConfirmar") !== null && ventana.uno("textoConfirmar").text.indexOf("Caddy es la puerta del panel") === 0, "  y explica por qué");
            ventana.comprobar(apiFalsa.acciones.length === ventana.acciones0 && !ventana.uno("aceptarConfirmar").encendido, "  no sale nada, y el botón está apagado hasta escribir el nombre");
            ventana.comprobar(ventana.uno("campoConfirmar").enfocado, "  con el campo ya enfocado");
            ventana.uno("campoConfirmar").texto = "Caddy";
        }]],
        [[200, () => {
            ventana.comprobar(!ventana.uno("aceptarConfirmar").encendido, "con otra cosa escrita («Caddy»), sigue apagado");
            ventana.uno("campoConfirmar").texto = "caddy";
        }]],
        [[200, () => {
            ventana.comprobar(ventana.uno("aceptarConfirmar").encendido, "con «caddy», se enciende");
            ventana.captura("22-servidor-confirmar");
        }]],
        [[300, () => ventana.clic(ventana.uno("aceptarConfirmar"))]],
        [[300, () => {
            ventana.comprobar(ventana.igual(ventana.ultimaAccion(), { tipo: "contenedor", nombre: "caddy", accion: "stop", confirmacion: "caddy" }), "y la acción sale con la palabra escrita", JSON.stringify(ventana.ultimaAccion()));
            ventana.comprobar(ventana.uno("confirmarServidor") === null, "  y la confirmación se cierra");
        }]],
        [[800, () => {
            ventana.acciones0 = apiFalsa.acciones.length;
            ventana.clic(ventana.uno("accion-caddy-stop"));
        }]],
        [[300, () => ventana.tecla(Qt.Key_Escape)]],
        [[300, () => {
            ventana.comprobar(ventana.uno("confirmarServidor") === null && apiFalsa.acciones.length === ventana.acciones0 && envoltura.escapes === ventana.escapes0 && falso.abierto, "Escape cancela la confirmación sin hacer nada y sin cerrar el cajón", String(envoltura.escapes - ventana.escapes0));
            ventana.clic(ventana.uno("menuStack-sync"));
        }]],
        [[500, () => {
            ventana.comprobar(ventana.uno("accionStack-sync-update") !== null && ventana.uno("accionStack-sync-down") !== null, "«⋯» de un stack enseña actualizar y bajar");
            ventana.clic(ventana.uno("accionStack-sync-update"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.uno("tituloConfirmar") !== null && ventana.uno("tituloConfirmar").text === "Actualizar · sync" && ventana.uno("textoConfirmar").text.indexOf("Descarga las imágenes") === 0, "Actualizar un stack pide su nombre y dice qué hace");
            ventana.clic(ventana.uno("cancelarConfirmar"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.uno("confirmarServidor") === null && apiFalsa.acciones.length === ventana.acciones0, "«Cancelar» no hace nada");
            ventana.clic(ventana.uno("menuStack-sync"));
        }]],
        [[500, () => ventana.clic(ventana.uno("accionStack-sync-down"))]],
        [[400, () => {
            ventana.comprobar(ventana.uno("textoConfirmar") !== null && ventana.uno("textoConfirmar").text.indexOf("Quita los contenedores") === 0, "Bajar un stack explica que los volúmenes y los datos se quedan");
            ventana.uno("campoConfirmar").texto = "sync";
            ventana.tecla(Qt.Key_Return);
        }]],
        [[200, () => {
            ventana.comprobar(ventana.igual(ventana.ultimaAccion(), { tipo: "stack", nombre: "sync", accion: "down", confirmacion: "sync" }), "Intro con el nombre bien escrito lo baja", JSON.stringify(ventana.ultimaAccion()));
            ventana.comprobar(ventana.estadoDe("syncthing") === "down…" && ventana.estadoDe("syncthing-relay") === "down…", "  y mientras, todos sus contenedores dicen en qué paso va", ventana.estadoDe("syncthing") + " | " + ventana.estadoDe("syncthing-relay"));
        }]],
        [[800, () => ventana.clic(ventana.uno("accion-immich_server-restart"))]],
        [[400, () => {
            ventana.comprobar(ventana.uno("tituloConfirmar") !== null && ventana.uno("tituloConfirmar").text === "Reiniciar · immich_server" && ventana.uno("textoConfirmar").text.indexOf("immich está protegido") === 0 && ventana.uno("campoConfirmar").pista === "immich", "lo de Immich (protegido) pide escribir «immich»");
            ventana.clic(ventana.uno("cancelarConfirmar"));
        }]],
        [[400, () => ventana.clic(ventana.uno("logs-caddy"))]],
        [[500, () => {
            ventana.comprobar(ventana.uno("logsServidor") !== null && ventana.uno("tituloLogs").text === "Logs · caddy", "«Logs» abre los del contenedor");
            ventana.comprobar(ventana.tiene("08:00:01  línea de prueba del contenedor"), "  con sus líneas y su hora");
            apiFalsa.lineaLog("una línea nueva");
        }]],
        [[300, () => {
            ventana.comprobar(ventana.tiene("08:00:09  una línea nueva") && ventana.uno("listaLogs").count === 4, "las líneas nuevas se añaden al final, en vivo", String(ventana.uno("listaLogs").count));
            ventana.captura("23-servidor-logs");
        }]],
        [[300, () => ventana.tecla(Qt.Key_Escape)]],
        [[400, () => {
            ventana.comprobar(apiFalsa.logs === null && ventana.uno("logsServidor") === null && envoltura.escapes === ventana.escapes0 && falso.abierto, "Escape cierra los logs (y deja de leerlos), no el cajón");
            ventana.clic(ventana.uno("logs-syncthing"));
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.logs !== null && apiFalsa.logs.contenedor === "syncthing", "(los logs de otro, abiertos)");
            ventana.seccion("inicio");
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.verConsumo === false && apiFalsa.logs === null, "fuera de Servidor no se lee el consumo, y los logs se cierran");
            ventana.seccion("servidor");
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.verConsumo === true, "al volver a Servidor, otra vez");
            falso.abierto = false;
        }]],
        [[800, () => {
            ventana.comprobar(apiFalsa.verConsumo === false, "con el cajón cerrado, tampoco");
            falso.abierto = true;
        }]],
        [[800, () => {
            ventana.comprobar(apiFalsa.verConsumo === true, "  y al abrirlo con Servidor a la vista, sí");
            apiFalsa.permisos = { acciones_docker: false, login_traderepublic: false };
        }]],
        [[300, () => {
            ventana.comprobar(ventana.tiene("Solo para ver: con el usuario portatil no hay acciones de Docker."), "sin acciones de Docker (el usuario movil): lo dice");
            const b = ventana.nombresCon("accion").concat(ventana.nombresCon("menuStack"));
            ventana.comprobar(b.length === 0 && ventana.uno("logs-caddy") !== null, "  y no hay ningún botón de acción, pero sí los logs", JSON.stringify(b));
            ventana.captura("24-servidor-solo-ver");
        }]],
        [[300, () => apiFalsa.permisos = { acciones_docker: true, login_traderepublic: true }]],
        // =====================================================================
        // Fase 4: Registro
        // =====================================================================
        [[50, () => ventana.seccion("registro")]],
        [[600, () => {
            ventana.comprobar(ventana.uno("seccionRegistro") !== null && ventana.igual(apiFalsa.lecturasRegistro, [""]), "la tira lleva al Registro, que se lee (sin filtro) la primera vez que se mira", JSON.stringify(apiFalsa.lecturasRegistro));
            ventana.comprobar(ventana.tiene("Contenedor caído · vaultwarden") && ventana.tiene("Paquetes actualizados") && ventana.tiene("Disco casi lleno · /"), "las líneas, con su título");
            ventana.comprobar(ventana.tiene("Reiniciar contenedor · syncthing") && ventana.tiene("Parar contenedor · caddy") && ventana.tiene("Bajar stack · sync"), "  también las de las acciones de antes");
            ventana.comprobar(ventana.porNombre("diaRegistro").length >= 1 && ventana.tiene("Hoy") && ventana.tiene("contenedor") && ventana.tiene("paquetes"), "  partidas por días y con su fuente");
            ventana.comprobar(!ventana.tiene("Viejo · parar contenedor · relay") && ventana.uno("masRegistro") !== null, "lo más viejo no viene en la primera página, y sale «Cargar más»");
            ventana.comprobar(ventana.tiene("Sin permiso para leer el journal del sistema"), "  y las notas de lo que el NUC no puede ver");
            ventana.captura("25-registro");
            ventana.clic(ventana.uno("entrada-9"));
        }]],
        [[400, () => {
            const d = ventana.uno("detalleRegistro");
            ventana.comprobar(ventana.igual(apiFalsa.detallesPedidos, [9]) && d !== null && d.text === "Por: portatil\nDuración: 1.2s\n<b>no es html</b>" && d.textFormat === Text.PlainText, "un clic en una línea pide su detalle y lo enseña tal cual (texto, no HTML)", d ? JSON.stringify(d.text) : "");
            ventana.captura("26-registro-detalle");
        }]],
        [[300, () => ventana.clic(ventana.uno("entrada-9"))]],
        [[400, () => {
            ventana.comprobar(ventana.uno("detalleRegistro") === null, "otro clic lo pliega");
            ventana.clic(ventana.uno("entrada-9"));
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.detallesPedidos.length === 1 && ventana.uno("detalleRegistro") !== null, "el detalle se pide una sola vez");
            ventana.detallesAntes = apiFalsa.detallesPedidos.length;
            ventana.clic(ventana.uno("entrada-6"));
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.detallesPedidos.length === ventana.detallesAntes, "una línea sin detalle no se despliega");
            ventana.clic(ventana.uno("masRegistro"));
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.masPedidas === 1 && ventana.tiene("Viejo · parar contenedor · relay") && ventana.uno("masRegistro") === null, "«Cargar más» trae lo de antes");
            ventana.clic(ventana.uno("filtroRegistro-level:warn"));
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.lecturasRegistro[apiFalsa.lecturasRegistro.length - 1] === "level:warn" && ventana.uno("filtroRegistro-level:warn").activo, "el filtro «Avisos y errores» vuelve a leer con level:warn");
            ventana.comprobar(ventana.tiene("Contenedor caído · vaultwarden") && ventana.tiene("Disco casi lleno · /") && !ventana.tiene("Paquetes actualizados"), "  y solo quedan los avisos y los errores");
            apiFalsa.nuevaEntrada({ fuente: "apt", nivel: "info", titulo: "Línea nueva de info", conDetalle: false });
            apiFalsa.nuevaEntrada({ fuente: "container", nivel: "error", titulo: "Línea nueva de error", conDetalle: false });
        }]],
        [[300, () => {
            ventana.comprobar(ventana.tiene("Línea nueva de error") && !ventana.tiene("Línea nueva de info"), "una línea nueva llega sola si pasa el filtro");
            ventana.clic(ventana.uno("filtroRegistro-todo"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.tiene("Línea nueva de info") && ventana.tiene("Paquetes actualizados") && ventana.uno("filtroRegistro-todo").activo, "«Todo» lo enseña todo otra vez");
            ventana.comprobar(ventana.textos().indexOf("€") < 0, "(sin euros en Proyectos, Servidor ni Registro)");
            // «Detalles» de una alerta: con otro filtro puesto, para ver que lo
            // quita, y con más líneas de las que caben, para ver que la lleva a
            // la vista.
            ventana.clic(ventana.uno("filtroRegistro-panel"));
            for (let k = 0; k < 30; k++)
                apiFalsa.nuevaEntrada({ fuente: "system", nivel: "info", titulo: "Relleno " + k, conDetalle: false });
        }]],
        [[400, () => ventana.seccion("inicio")]],
        [[400, () => {
            const b = ventana.porNombre("botonDetalles");
            ventana.comprobar(b.length === 2, "«Detalles» en las alertas que tienen su línea en el Registro", String(b.length));
            ventana.masAntes = apiFalsa.masPedidas;
            ventana.lecturasAntes = apiFalsa.lecturasRegistro.length;
            ventana.clic(b[0]);
        }]],
        [[900, () => {
            const e = ventana.uno("entrada-1");
            ventana.comprobar(ventana.uno("seccionRegistro") !== null && apiFalsa.lecturasRegistro.length === ventana.lecturasAntes + 1 && apiFalsa.registro.filtro === "" && ventana.uno("filtroRegistro-todo").activo, "«Detalles» lleva al Registro, sin filtro", JSON.stringify(apiFalsa.lecturasRegistro.slice(ventana.lecturasAntes)));
            ventana.comprobar(apiFalsa.masPedidas === ventana.masAntes + 1 && e !== null && e.resaltada, "  trae páginas más viejas hasta dar con la línea de la alerta, y la resalta", String(apiFalsa.masPedidas - ventana.masAntes));
            ventana.comprobar(apiFalsa.detallesPedidos[apiFalsa.detallesPedidos.length - 1] === 1 && ventana.hijo(e, "detalleRegistro") !== null, "  con su detalle desplegado");
            const f = ventana.uno("desplazableRegistro");
            const y = e ? e.mapToItem(f.contentItem, 0, 0).y : -1;
            ventana.comprobar(e !== null && f.contentY > 0 && y >= f.contentY && y + 20 <= f.contentY + f.height, "  y la lleva a la vista", "y " + y + ", contentY " + f.contentY + ", alto " + f.height);
            ventana.captura("27-registro-desde-alerta");
        }]],
        // Una alerta cuya línea ya no está.
        [[300, () => {
            apiFalsa.alertas = apiFalsa.alertas.map(a => a.id === "a2" ? Object.assign({}, a, { entrada: 999 }) : a);
            ventana.seccion("inicio");
        }]],
        [[400, () => ventana.clic(ventana.porNombre("botonDetalles")[1])]],
        [[600, () => {
            ventana.comprobar(ventana.textoAviso() === "Esa línea ya no está en el Registro" && ventana.porNombre("detalleRegistro").length === 0, "si la línea ya no está, lo dice", ventana.textoAviso());
            apiFalsa.alertas = apiFalsa.alertas.map(a => a.id === "a2" ? Object.assign({}, a, { entrada: 7 }) : a);
        }]],
        pasosNotas.pasos,
        // =====================================================================
        // Fase 5: Finanzas
        // =====================================================================
        [[50, () => falso.abierto = true]],
        [[600, () => ventana.seccion("finanzas")]],
        [[700, () => {
            ventana.comprobar(ventana.uno("seccionFinanzas") !== null && apiFalsa.lecturasFinanzas === 1, "la tira lleva a Finanzas, que se lee la primera vez que se mira", String(apiFalsa.lecturasFinanzas));
            ventana.comprobar(ventana.tiene("OCTUBRE 2026") && ventana.tiene("PATRIMONIO") && ventana.tiene("FLUJO DEL MES"), "el resumen del mes, con su nombre");
            const tp = ventana.uno("tarjetaPatrimonio"), tf = ventana.uno("tarjetaFlujo");
            ventana.comprobar(tp !== null && tf !== null && tf.detalle === "Ingresos 1.850,00 € · gastos 770,42 €" && tf.valor === "1.079,58 €" && tp.valor === "12.345,67 €", "con el cajón desplegado salen los euros, con formato de aquí", tp && tf ? tf.detalle + " | " + tf.valor + " | " + tp.valor : "");
            ventana.comprobar(ventana.tiene("41 % de la meta") && ventana.tiene("un 23 % menos que septiembre"), "  el % de la meta y la comparación con el mes anterior");
            ventana.comprobar(ventana.tiene("Mercadona") && ventana.tiene("-45,23 €") && ventana.tiene("20 oct") && !ventana.tiene("Gasolina"), "los movimientos del mes, los de la primera página");
            ventana.comprobar(ventana.uno("masFinanzas") !== null && ventana.uno("finanzasWeb") !== null, "  con «Cargar más» y «Abrir en la web»");
            ventana.comprobar(ventana.uno("avisoTradeRepublic") !== null && ventana.uno("iniciarTradeRepublic") !== null && apiFalsa.lecturasTR >= 1, "la sesión caducada de Trade Republic avisa, y con el permiso hay botón");
            ventana.captura("28-finanzas");
            // Con el cajón a medio plegar (no del todo fuera) no sale ninguna cantidad.
            falso.abierto = false;
        }]],
        [[900, () => {
            const t = ventana.textos();
            ventana.comprobar(t.indexOf("€") < 0 && !/\d,\d\d/.test(t) && ventana.cualquiera("seccionFinanzas") !== null, "con el cajón replegado no sale ninguna cantidad", t.slice(0, 80));
            falso.abierto = true;
        }]],
        [[700, () => {
            ventana.comprobar(ventana.uno("tarjetaPatrimonio").valor === "12.345,67 €" && ventana.uno("tarjetaFlujo").detalle === "Ingresos 1.850,00 € · gastos 770,42 €", "al volver a desplegar, otra vez los euros");
            ventana.clic(ventana.uno("masFinanzas"));
        }]],
        [[300, () => {
            ventana.comprobar(apiFalsa.masFinanzasPedidas === 1 && ventana.tiene("Gasolina") && ventana.tiene("Seguro") && ventana.uno("masFinanzas") === null, "«Cargar más» trae los de antes y se quita");
            // El formulario (plegado de entrada): se despliega y valida, sin llamar al NUC.
            ventana.comprobar(ventana.uno("formEfectivo") === null, "el formulario de efectivo empieza plegado");
            ventana.clic(ventana.uno("alternarEfectivo"));
        }]],
        [[700, () => ventana.clic(ventana.uno("apuntarEfectivo"))]],
        [[200, () => {
            ventana.comprobar(apiFalsa.efectivos.length === 0 && ventana.uno("errorForm") !== null && ventana.uno("errorForm").text.indexOf("importe") >= 0, "un importe vacío no sale hacia el NUC y lo dice", ventana.uno("errorForm") ? ventana.uno("errorForm").text : "");
            ventana.uno("campoImporte").texto = "12,50";
            ventana.uno("campoConcepto").texto = "Cafetería";
            ventana.clic(ventana.uno("apuntarEfectivo"));
        }]],
        [[200, () => {
            ventana.comprobar(apiFalsa.efectivos.length === 0 && ventana.uno("errorForm").text.indexOf("categoría") >= 0, "sin categoría tampoco", ventana.uno("errorForm").text);
            ventana.clic(ventana.uno("catEfectivo-2"));
        }]],
        [[200, () => {
            ventana.comprobar(ventana.uno("catEfectivo-2").activo, "elegir una categoría la marca");
            apiFalsa.errorEfectivo = "Escribe un concepto de hasta 200 caracteres.";
            ventana.clic(ventana.uno("apuntarEfectivo"));
        }]],
        [[200, () => {
            ventana.comprobar(apiFalsa.efectivos.length === 1 && ventana.igual(apiFalsa.efectivos[0], { importe: 1250, concepto: "Cafetería", categoria: 2, fecha: "" }), "se manda en céntimos, con concepto y categoría", JSON.stringify(apiFalsa.efectivos));
            ventana.comprobar(ventana.uno("errorForm") !== null && ventana.uno("errorForm").text === "Escribe un concepto de hasta 200 caracteres." && ventana.uno("campoImporte").texto === "12,50", "un rechazo del servidor se enseña junto al formulario y no borra lo escrito");
            apiFalsa.errorEfectivo = "";
            apiFalsa.conflictoEfectivo = true;
            ventana.clic(ventana.uno("apuntarEfectivo"));
        }]],
        [[300, () => {
            ventana.comprobar(ventana.textoAviso().indexOf("Finanzas no pudo apuntarlo") === 0 && ventana.uno("campoConcepto").texto === "Cafetería", "un 409 avisa y deja el formulario como estaba", ventana.textoAviso());
            ventana.clic(ventana.uno("apuntarEfectivo"));
        }]],
        [[400, () => {
            ventana.comprobar(apiFalsa.efectivos.length === 3 && ventana.textoAviso() === "Gasto en efectivo apuntado" && !/\d/.test(ventana.textoAviso()), "apuntado: el aviso no lleva ninguna cantidad", ventana.textoAviso());
            ventana.comprobar(ventana.tiene("Cafetería") && ventana.tiene("-12,50 €") && ventana.uno("campoImporte").texto === "" && ventana.uno("errorForm") === null && ventana.uno("tarjetaFlujo").detalle === "Ingresos 1.850,00 € · gastos 782,92 €", "  el movimiento sale, el formulario se vacía y el resumen se pone al día", ventana.uno("tarjetaFlujo").detalle);
            ventana.captura("29-finanzas-efectivo");
            // Sin el permiso de Trade Republic: el aviso se queda, el botón no.
            apiFalsa.permisos = { acciones_docker: true, login_traderepublic: false };
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("avisoTradeRepublic") !== null && ventana.uno("iniciarTradeRepublic") === null, "sin login_traderepublic no hay botón de iniciar sesión (el aviso se queda)");
            apiFalsa.permisos = { acciones_docker: true, login_traderepublic: true };
            apiFalsa.trCaducada = false;
            apiFalsa.cargarTradeRepublic();
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("avisoTradeRepublic") === null, "con la sesión buena no hay aviso");
            ventana.enlaces = [];
        }]],
        [[50, () => ventana.clic(ventana.uno("finanzasWeb"))]],
        [[300, () => {
            ventana.comprobar(ventana.igual(ventana.enlaces[ventana.enlaces.length - 1], ["xdg-open", apiFalsa.urlWeb("#/finanzas")]), "«Abrir en la web» abre la sección de Finanzas de la web", JSON.stringify(ventana.enlaces));
            // El enlace aparta el cajón: se vuelve a sacar, y Finanzas sin datos.
            falso.abierto = true;
        }]],
        [[700, () => {
            apiFalsa.finanzas = Object.assign({}, apiFalsa.finanzas, { habilitado: false, listo: false });
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("finanzasApagado") !== null && ventana.uno("resumenFinanzas") === null && ventana.uno("formEfectivo") === null, "con Finanzas apagado en el NUC lo dice y no enseña nada más");
            ventana.seccion("inicio");
        }]],
        [[500, () => ventana.comprobar(ventana.tiene("34 %") && ventana.textos().indexOf("€") < 0, "Inicio sigue con el % de la meta y sin euros")]],
        // --- Fase 5: Revisiones ---
        [[400, () => {
            ventana.lecturas0 = apiFalsa.lecturasRevisiones.length;
            ventana.seccion("revisiones");
        }]],
        [[700, () => {
            ventana.comprobar(ventana.uno("seccionRevisiones") !== null, "la tira lleva a Revisiones");
            ventana.comprobar(apiFalsa.lecturasRevisiones.length === ventana.lecturas0 + 1 && apiFalsa.revisionesPedida === "", "al entrar se lee esta semana (una vez)", JSON.stringify(apiFalsa.lecturasRevisiones));
            ventana.comprobar(ventana.uno("revisionSemana").text === "Semana 43 · 19–25 oct", "el selector dice la semana y su rango", ventana.uno("revisionSemana").text);
            const dias = ventana.nombresCon("reminder-");
            ventana.comprobar(dias.length === 7, "salen los siete reminders de la semana", String(dias.length));
            ventana.comprobar(ventana.tiene("Lunes tranquilo.") && ventana.tiene("Todavía no"), "  con su texto y, los que no han llegado, «Todavía no»");
            ventana.comprobar(ventana.uno("campoRevision") !== null && ventana.porNombre("campoRevision").length === 1, "el reminder de hoy, vacío, se abre para escribir (y sólo ése)");
            
            ventana.comprobar(ventana.uno("crear-planning") !== null && ventana.uno("plegar-retro") !== null && ventana.uno("crear-retro") === null, "el planning dice «crear desde la plantilla» y la retro, que existe, se pliega y despliega");
            ventana.comprobar(ventana.uno("tarjetaDomingo") !== null, "la tarjeta del domingo sale en la semana de hoy");
            ventana.comprobar(ventana.textos().indexOf("€") < 0, "(sin euros en Revisiones)");
            ventana.captura("28-revisiones");
            // Escribir con el teclado y guardar con Ctrl+Intro.
            ventana.escrituras0 = apiFalsa.escriturasRev.length;
            ventana.tecla("H");
            ventana.tecla("o");
            ventana.tecla("y");
            ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
        }]],
        [[500, () => {
            const u = apiFalsa.escriturasRev[apiFalsa.escriturasRev.length - 1];
            ventana.comprobar(apiFalsa.escriturasRev.length === ventana.escrituras0 + 1 && u.op === "reminder" && ventana.igual(u.cuerpo, { fecha: "2026-10-20", antes: "", texto: "Hoy" }), "Ctrl+Intro guarda el reminder de hoy con el texto del que se partió", u ? JSON.stringify(u.cuerpo) : "(nada)");
            ventana.comprobar(ventana.uno("campoRevision") === null && ventana.tiene("Hoy"), "  y el campo se cierra y el texto sale");
            // Escape cancela sin escribir.
            ventana.escrituras0 = apiFalsa.escriturasRev.length;
            ventana.clic(ventana.uno("escribir-2026-10-19"));
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("campoRevision") !== null && ventana.uno("campoRevision").texto === "Lunes tranquilo.\n\n- gym\n- leído", "«Editar» abre el campo con el texto que hay");
            ventana.tecla("x");
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("campoRevision") === null && apiFalsa.escriturasRev.length === ventana.escrituras0 && apiFalsa.notasRev.dias["2026-10-19"].indexOf("x") < 0, "Escape cancela: no se escribe nada");
            // Conflicto: la nota cambia por otro lado mientras se escribe.
            ventana.clic(ventana.uno("escribir-2026-10-20"));
        }]],
        [[300, () => {
            ventana.tecla("!");
            apiFalsa.revConflicto = true;
            ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.notasRev.dias["2026-10-20"] === "Escrito desde Obsidian", "con un 409 el NUC no escribe encima", apiFalsa.notasRev.dias["2026-10-20"]);
            ventana.comprobar(ventana.textoAviso().indexOf("Tus notas han cambiado") === 0, "  y se avisa", ventana.textoAviso());
            ventana.comprobar(ventana.uno("campoRevision") !== null && ventana.uno("campoRevision").texto === "Hoy!" && ventana.uno("avisoConflicto") !== null, "  y lo escrito se queda en el campo, con su aviso", ventana.uno("campoRevision") ? ventana.uno("campoRevision").texto : "(sin campo)");
            ventana.tecla(Qt.Key_Escape);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("campoRevision") === null && ventana.tiene("Escrito desde Obsidian"), "  cancelar deja lo que había en las notas");
            // Crear el planning desde la plantilla y escribir un apartado.
            ventana.escrituras0 = apiFalsa.escriturasRev.length;
            ventana.clic(ventana.uno("crear-planning"));
        }]],
        [[500, () => {
            const u = apiFalsa.escriturasRev[apiFalsa.escriturasRev.length - 1];
            ventana.comprobar(apiFalsa.escriturasRev.length === ventana.escrituras0 + 1 && ventana.igual(u.cuerpo, { tipo: "planning", semana: "2026-S43", crear: true }), "«Crear desde la plantilla» pide crear el planning de la semana", u ? JSON.stringify(u.cuerpo) : "");
            ventana.comprobar(ventana.uno("apartado-planning:0") !== null && ventana.uno("apartado-planning:1") !== null && ventana.tiene("Prioridades") && ventana.uno("crear-planning") === null, "  y salen sus apartados");
            ventana.clic(ventana.uno("escribir-planning:1"));
        }]],
        [[300, () => {
            ventana.comprobar(ventana.uno("campoRevision") !== null, "«Escribir» en un apartado abre el campo");
            ventana.tecla("R");
            ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
        }]],
        [[500, () => {
            const u = apiFalsa.escriturasRev[apiFalsa.escriturasRev.length - 1];
            ventana.comprobar(ventana.igual(u.cuerpo, { tipo: "planning", semana: "2026-S43", i: 1, titulo: "Riesgos", antes: "", cuerpo: "R" }), "guardar un apartado manda su semana, su número, su título y el texto del que se partió", JSON.stringify(u.cuerpo));
            ventana.comprobar(ventana.uno("campoRevision") === null, "  y el campo se cierra");
            // La retro, plegada, se abre y se escribe por apartados.
            ventana.clic(ventana.uno("plegar-retro"));
        }]],
        [[400, () => {
            ventana.comprobar(ventana.tiene("Acabé el cajón.") && ventana.uno("apartado-retro:1") !== null, "«Ver y escribir» despliega la retro por apartados");
            // Sin permiso de escribir (el NUC lo dice por reminder).
            apiFalsa.revEditables = false;
            ventana.clic(ventana.uno("revisionAnterior"));
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.revisionesPedida === "2026-S42" && ventana.uno("revisionSemana").text.indexOf("Semana 42") === 0, "‹ lee la semana anterior", apiFalsa.revisionesPedida);
            ventana.comprobar(ventana.uno("tarjetaDomingo") === null, "  y sin la tarjeta del domingo (no es la semana de hoy)");
            ventana.comprobar(ventana.porNombre("escribir-2026-10-12").length === 0, "un reminder que el NUC marca como no editable no ofrece escribir");
            ventana.comprobar(ventana.uno("revisionEstaSemana") !== null, "  y «Esta semana» vuelve");
            apiFalsa.revEditables = true;
            ventana.clic(ventana.uno("revisionEstaSemana"));
        }]],
        [[500, () => {
            ventana.comprobar(apiFalsa.revisionesPedida === "" && ventana.uno("revisionSemana").text.indexOf("Semana 43") === 0, "«Esta semana» vuelve a la de hoy");
            ventana.comprobar(!ventana.uno("revisionSiguiente").encendido === false, "› está a mano en la semana de hoy");
            // La tarjeta del domingo: el planning de la semana que viene.
            ventana.escrituras0 = apiFalsa.escriturasRev.length;
            ventana.clic(ventana.uno("pasoPlanning"));
        }]],
        [[700, () => {
            const u = apiFalsa.escriturasRev[apiFalsa.escriturasRev.length - 1];
            ventana.comprobar(apiFalsa.revisionesPedida === "2026-S44", "el paso «Planning de S44» lee la semana que viene", apiFalsa.revisionesPedida);
            ventana.comprobar(u && ventana.igual(u.cuerpo, { tipo: "planning", semana: "2026-S44", crear: true }) && ventana.uno("apartado-planning:0") !== null, "  y, como no existe, lo crea desde la plantilla y lo abre");
            ventana.comprobar(!ventana.uno("revisionSiguiente").encendido, "› no pasa de una semana por delante");
            ventana.clic(ventana.uno("revisionEstaSemana"));
        }]],
        [[500, () => ventana.clic(ventana.uno("pasoTareas"))]],
        [[500, () => {
            ventana.comprobar(ventana.uno("seccionRevisiones") === null && ventana.uno("seccionTareas") !== null, "el paso «Ir a Tareas» cambia de sección");
            ventana.seccion("inicio");
        }]],
        // =====================================================================
        // Tareas: arrastrar, edición desde el detalle y avisos del móvil
        // =====================================================================
        [[50, () => ventana.seccion("tareas")]],
        [[600, () => ventana.clic(ventana.uno("vista-plazo"))]],
        [[300, () => {
            ventana.comprobar(ventana.uno("actualizarTareas") !== null, "Tareas tiene el botón de actualizar");
            ventana.comprobar(ventana.uno("verCalendario") === null && ventana.cualquiera("calendarioLateral") === null && ventana.uno("tituloMes") === null, "el cajón ya no tiene calendario (es el de la isla)");
            // Arrastrar una fila (por su asa) a un destino de la tira de días.
            const f = ventana.filaDe("Cambiar los discos del NAS", "r") || ventana.filaDe("Cambiar los discos del NAS", "a");
            ventana.traer(f);
            ventana.asa = ventana.hijo(f, f.ctx === "r" ? "asaFila" : "asaTarjeta");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            const p = ventana.asa.mapToItem(envoltura, ventana.asa.width / 2, ventana.asa.height / 2);
            ventana.px = p.x;
            ventana.qy = p.y;
            ev.mousePress(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        }]],
        [[100, () => ev.mouseMove(envoltura, ventana.px + 8, ventana.qy - 10, -1, Qt.LeftButton, Qt.NoModifier)]],
        [[100, () => ev.mouseMove(envoltura, ventana.px + 30, ventana.qy + 40, -1, Qt.LeftButton, Qt.NoModifier)]],
        [[600, () => {
            const d = ventana.uno("destinoDia-3");
            const q = d.mapToItem(envoltura, d.width / 2, d.height / 2);
            ventana.px = q.x;
            ventana.qy = q.y;
            ev.mouseMove(envoltura, q.x, q.y, -1, Qt.LeftButton, Qt.NoModifier);
        }]],
        [[300, () => {
            ventana.comprobar(ventana.ui().arrastrada !== null && ventana.ui().arrastrada.plano === "Cambiar los discos del NAS", "arrastrando por el asa se lleva la tarea");
            ventana.comprobar(ventana.uno("tiraDias").visible, "al arrastrar baja la tira de días");
            ventana.captura("15-tareas-arrastre");
            ev.mouseRelease(envoltura, ventana.px, ventana.qy, Qt.LeftButton, Qt.NoModifier, -1);
        }]],
        [[600, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { fecha: "2026-10-23" }), "soltar sobre un día de la tira le pone esa fecha", ventana.ultimaJSON());
            ventana.comprobar(ventana.ui().arrastrada === null, "  y el arrastre acaba");
        }]],
        // A «+1 s»: una semana desde hoy (20 oct → 27 oct).
        [[100, () => {
            const f = ventana.filaDe("Cambiar los discos del NAS", "r") || ventana.filaDe("Cambiar los discos del NAS", "a");
            ventana.traer(f);
            const a = ventana.hijo(f, f.ctx === "r" ? "asaFila" : "asaTarjeta");
            const p = a.mapToItem(envoltura, a.width / 2, a.height / 2);
            ev.mousePress(envoltura, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
            ventana.px = p.x;
            ventana.qy = p.y;
        }]],
        [[100, () => ev.mouseMove(envoltura, ventana.px + 8, ventana.qy - 10, -1, Qt.LeftButton, Qt.NoModifier)]],
        [[100, () => ev.mouseMove(envoltura, ventana.px + 30, ventana.qy + 40, -1, Qt.LeftButton, Qt.NoModifier)]],
        [[600, () => {
            const d = ventana.uno("destinoSemana");
            const q = d.mapToItem(envoltura, d.width / 2, d.height / 2);
            ventana.px = q.x;
            ventana.qy = q.y;
            ev.mouseMove(envoltura, q.x, q.y, -1, Qt.LeftButton, Qt.NoModifier);
        }]],
        [[300, () => ev.mouseRelease(envoltura, ventana.px, ventana.qy, Qt.LeftButton, Qt.NoModifier, -1)]],
        [[600, () => ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { fecha: "2026-10-27" }), "soltar sobre «+1 s» la mueve una semana desde hoy", ventana.ultimaJSON())]],
        // Edición desde el detalle: claude_off, fecha, prioridad, proyecto.
        [[100, () => {
            ventana.clicFila("Cambiar los discos del NAS", ventana.filaDe("Cambiar los discos del NAS", "r") ? "r" : "a");
        }]],
        [[600, () => {
            const c = ventana.uno("claudeOff");
            ventana.comprobar(c !== null, "el detalle tiene el interruptor «Claude no la hace»");
            ventana.traer(c);
            ventana.clic(c);
        }]],
        [[500, () => {
            ventana.comprobar(ventana.ultima().op === "editar" && ventana.igual(ventana.ultima().cuerpo, { claudeOff: true }), "el interruptor manda claudeOff: true", ventana.ultimaJSON());
            ventana.clic(ventana.uno("panelPrioridad"));
        }]],
        [[600, () => ventana.clic(ventana.uno("prio-alta"))]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { prioridad: "alta" }), "el botón de prioridad cambia la prioridad", ventana.ultimaJSON());
            ventana.clic(ventana.uno("panelFecha"));
        }]],
        [[600, () => {
            ventana.captura("t17-detalle-fecha");
            ventana.clic(ventana.uno("fecha-sin"));
        }]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { fecha: "" }), "el botón de fecha puede quitarla", ventana.ultimaJSON());
            ventana.clic(ventana.uno("panelProyecto"));
        }]],
        [[600, () => ventana.clic(ventana.uno("proy-clase"))]],
        [[500, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { seccion: "clase" }), "el botón de proyecto mueve la tarea", ventana.ultimaJSON());
            ventana.comprobar(ventana.uno("tiraDias") !== null ? !ventana.uno("tiraDias").visible : true, "la tira de días no se ve si no se arrastra");
        }]],
        // El aviso del móvil.
        [[100, () => apiFalsa.confirmaciones = [{ id: "m1", tipo: "confirmar_envio", titulo: "Enviar el parte a Juanjo", detalle: "parte-semana.pdf", pendiente: true }]]],
        [[800, () => {
            ventana.comprobar(ventana.uno("avisoEnviar") !== null && ventana.tiene("Enviar el parte a Juanjo"), "un aviso confirmar_envio enseña la tarjeta con Enviar y No enviar");
            ventana.captura("16-tareas-aviso-movil");
            ventana.clic(ventana.uno("avisoEnviar"));
        }]],
        [[600, () => {
            ventana.comprobar(ventana.igual(apiFalsa.respuestasAviso, [{ id: "m1", envio: true }]), "«Enviar» responde envio: true", JSON.stringify(apiFalsa.respuestasAviso));
            ventana.comprobar(ventana.uno("avisoEnviar") === null, "  y la tarjeta se va");
            apiFalsa.confirmaciones = [{ id: "m2", tipo: "confirmar_envio", titulo: "Otro", detalle: "", pendiente: true }];
        }]],
        [[800, () => ventana.clic(ventana.uno("avisoNoEnviar"))]],
        [[600, () => ventana.comprobar(ventana.igual(apiFalsa.respuestasAviso[1], { id: "m2", envio: false }), "«No enviar» responde envio: false", JSON.stringify(apiFalsa.respuestasAviso))]],
        // =====================================================================
        // Clase: las tareas de Aules (Tareas con soloArea: "Clase")
        // =====================================================================
        [[100, () => ventana.seccion("clase")]],
        [[900, () => {
            const t = ventana.uno("tareasClase");
            ventana.comprobar(t !== null && t.soloArea === "Clase", "Clase lleva debajo Tareas con soloArea «Clase»");
            ventana.comprobar(ventana.uno("botonAules") !== null && ventana.hijo(t, "botonAnadir") !== null, "  bajo el botón de Aules, con su fila de añadir");
            const planos = ventana.filasDe(t).map(f => f.t.plano);
            ventana.comprobar(planos.indexOf("Entrega de prueba con fecha") >= 0, "soloArea: sale la tarea de área Clase", JSON.stringify(planos));
            ventana.comprobar(planos.indexOf("Leer el tema 4") < 0 && planos.indexOf("Cambiar los discos del NAS") < 0 && planos.indexOf("Revisar la copia de seguridad") < 0, "  y ninguna de otras áreas", JSON.stringify(planos));
            ventana.comprobar(ventana.hijo(t, "tarjetaAhora") === null && ventana.hijo(t, "ahoraVacio") === null && ventana.hijo(t, "vista-plazo") === null && ventana.hijo(t, "vista-proyecto") === null, "  sin «Ahora» ni vistas");
            let tira = null;
            ventana.recorrer(t, it => { if (it.objectName === "tiraDias") tira = it; });
            ventana.comprobar(tira !== null, "  y con la tira de días para arrastrar");
            ventana.captura("t19-clase-tareas");
            const c = ventana.hijo(t, "campoNueva");
            c.enfocar();
            c.texto = "Entrega nueva de Aules";
        }]],
        [[100, () => {
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.tecla(Qt.Key_Return);
        }]],
        [[400, () => {
            ventana.comprobar(ventana.igual(ventana.ultima().cuerpo, { seccion: "clase", texto: "Entrega nueva de Aules", prioridad: "media", area: "Clase" }), "soloArea: lo que se añade lleva el área y va a la sección Clase", ventana.ultimaJSON());
            ventana.comprobar(ventana.filasDe(ventana.uno("tareasClase")).some(f => f.t.plano === "Entrega nueva de Aules"), "  y sale en la lista");
        }]],
        [[100, () => {
            const t = ventana.uno("tareasClase");
            const f = ventana.filasDe(t).find(x => x.t.plano === "Entrega de prueba con fecha");
            ventana.escrituras0 = apiFalsa.escrituras.length;
            ventana.clic(ventana.hijo(f, "casillaFila") || f);
        }]],
        [[500, () => ventana.comprobar(apiFalsa.escrituras.length > ventana.escrituras0, "soloArea: marcar una fila escribe en el panel", String(apiFalsa.escrituras.length - ventana.escrituras0))]],
        [[100, () => ventana.seccion("inicio")]],
        [[50, () => ventana.comprobar(ventana.textos().indexOf("€") < 0, "no aparece ningún € en todo el texto del cajón")]],
        // =====================================================================
        // Secciones perezosas (SeccionPerezosa.qml): se crean al mirarlas, se
        // descargan al rato, y el esqueleto sale sólo con carga lenta
        // =====================================================================
        [[50, () => {
            const c = ventana.contenidoRaiz();
            c.retardoDescarga = 500;
            c.retardoEsqueleto = 150;
            ventana.seccion("clase");
        }]],
        [[700, () => {
            ventana.comprobar(ventana.cualquiera("seccionClase") !== null && ventana.cualquiera("seccionClase").visible, "perezosa: al mirar Clase, existe y se ve");
            ventana.seccion("inicio");
        }]],
        [[200, () => {
            ventana.comprobar(ventana.cualquiera("seccionClase") !== null && !ventana.cualquiera("seccionClase").visible, "perezosa: al dejarla sigue viva, escondida, un rato");
        }]],
        [[1500, () => {
            ventana.comprobar(ventana.cualquiera("seccionClase") === null, "perezosa: pasado el retardo, Clase se descarga");
            ventana.comprobar(ventana.cualquiera("seccionTareas") === null && ventana.cualquiera("seccionFinanzas") === null && ventana.cualquiera("seccionRevisiones") === null, "perezosa: las demás secciones también están descargadas, sólo existe Inicio");
            ventana.comprobar(ventana.uno("desplazableInicio") !== null, "perezosa: Inicio existe y se ve");
        }]],
        // Carga lenta (los datos tardan): sale el esqueleto, y desaparece al llegar.
        [[50, () => {
            ventana.claseGuardada = apiFalsa.clase;
            apiFalsa.clase = null;
            ventana.seccion("clase");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.uno("esqueleto") !== null, "esqueleto: con los datos tardando más de 150 ms, sale");
            ventana.comprobar(ventana.uno("esqueletoCabecera") !== null && ventana.uno("esqueletoFilas") !== null, "esqueleto: lleva cabecera y tarjetas");
            apiFalsa.clase = ventana.claseGuardada;
        }]],
        [[200, () => {
            ventana.comprobar(ventana.uno("esqueleto") === null && ventana.uno("seccionClase") !== null, "esqueleto: al llegar los datos se va y se ve la sección");
            ventana.seccion("inicio");
        }]],
        // Carga rápida (los datos llegan antes de 150 ms): no sale nunca.
        [[1500, () => {
            ventana.comprobar(ventana.cualquiera("seccionClase") === null, "esqueleto: (Clase descargada otra vez antes de la prueba rápida)");
            ventana.claseGuardada = apiFalsa.clase;
            apiFalsa.clase = null;
            ventana.seccion("clase");
        }]],
        [[40, () => {
            apiFalsa.clase = ventana.claseGuardada;
        }]],
        [[60, () => {
            ventana.comprobar(ventana.uno("esqueleto") === null, "esqueleto: con los datos a los 40 ms, no sale");
        }]],
        [[500, () => {
            ventana.comprobar(ventana.uno("esqueleto") === null && ventana.uno("seccionClase") !== null, "esqueleto: tampoco después, y la sección se ve");
            ventana.seccion("inicio");
            ventana.contenidoRaiz().retardoDescarga = 45000;
        }]],
        [[300, () => {
            console.log("Resultado: " + (ventana.hechas - ventana.fallos.length) + " de " + ventana.hechas + " bien" + (ventana.fallos.length ? "; fallan: " + ventana.fallos.join(" | ") : ""));
            Qt.quit();
        }]]
    )

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
