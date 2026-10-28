import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "homelab/OrdenLogica.js" as OrdenLogica

// Los pasos de la prueba del orden de las secciones de la tira, aparte de
// shell.qml, que sólo los mete en su lista: la lógica (aplicar el orden
// guardado, secciones nuevas al final, ids desconocidos fuera) y el arrastre
// de verdad con el ratón, con lo guardado en secciones.json.
QtObject {
    id: pasosOrden

    required property var v
    required property var zona

    property TestEvent ev: TestEvent {}

    property FileView lector: FileView {
        blockAllReads: true
        printErrors: false
        watchChanges: false
    }

    readonly property var demo: [
        {
            id: "a"
        },
        {
            id: "b"
        },
        {
            id: "c"
        },
        {
            id: "d"
        }
    ]

    function ids(l) {
        return l.map(s => s.id).join("");
    }

    // Lo guardado en disco, o null.
    function guardado() {
        pasosOrden.lector.path = Quickshell.env("PANEL_ESTADO_DIR") + "/secciones.json";
        pasosOrden.lector.reload();
        try {
            return JSON.parse(pasosOrden.lector.text()).orden.join(",");
        } catch (e) {
            return null;
        }
    }

    function centro(nombre) {
        const it = pasosOrden.v.uno(nombre);
        return it.mapToItem(pasosOrden.zona, it.width / 2, it.height / 2);
    }

    function ordenTira() {
        const l = pasosOrden.v.contenidoRaiz().secciones.map(s => s.id);
        return l.slice().sort((x, y) => pasosOrden.v.uno("seccion-" + x).y - pasosOrden.v.uno("seccion-" + y).y).join(",");
    }

    property real py: 0
    property string antes: ""

    readonly property var pasos: [
        [50, () => {
            const o = pasosOrden;
            o.v.comprobar(o.ids(OrdenLogica.ordenar(o.demo, [])) === "abcd", "orden: sin guardar, el de siempre");
            o.v.comprobar(o.ids(OrdenLogica.ordenar(o.demo, ["c", "a", "d", "b"])) === "cadb", "orden: se aplica el guardado");
            o.v.comprobar(o.ids(OrdenLogica.ordenar(o.demo, ["c", "a"])) === "cabd", "orden: las nuevas van al final, en su orden");
            o.v.comprobar(o.ids(OrdenLogica.ordenar(o.demo, ["x", "c", "y", "b"])) === "cbad", "orden: los ids desconocidos se ignoran");
            o.v.comprobar(o.ids(OrdenLogica.ordenar(o.demo, ["b", "b", "a"])) === "bacd", "orden: un id repetido cuenta una vez");
            o.v.comprobar(o.ids(OrdenLogica.ordenar(o.demo, null)) === "abcd" && o.ids(OrdenLogica.ordenar(o.demo, "zzz")) === "abcd", "orden: un guardado que no es lista se ignora");
            o.v.comprobar(OrdenLogica.mover(["a", "b", "c", "d"], 0, 2).join("") === "bcad" && OrdenLogica.mover(["a", "b", "c", "d"], 3, 1).join("") === "adbc", "mover: arriba y abajo");
            o.v.comprobar(OrdenLogica.mover(["a", "b"], 0, 5).join("") === "ab", "mover: fuera de rango no mueve");
            o.v.comprobar(OrdenLogica.destino(0, 90, 42, 9) === 2 && OrdenLogica.destino(3, -500, 42, 9) === 0 && OrdenLogica.destino(3, 900, 42, 9) === 8, "destino: redondea y se queda dentro");
        }],
        [50, () => {
            const o = pasosOrden;
            o.v.contenidoRaiz().shell.abierto = true;
            o.v.contenidoRaiz().shell.fijado = true;
        }],
        [700, () => {
            const o = pasosOrden;
            o.v.comprobar(o.ordenTira() === "inicio,tareas,clase,proyectos,servidor,registro,revisiones,notas,finanzas", "arrastre: la tira empieza en el orden de siempre", o.ordenTira());
            // Un clic sigue eligiendo la sección.
            o.v.seccion("clase");
        }],
        [300, () => {
            const o = pasosOrden;
            o.v.comprobar(o.v.contenidoRaiz().seccion === "clase", "arrastre: un clic sigue eligiendo la sección");
            o.v.seccion("inicio");
        }],
        // Arrastra «servidor» (posición 4) sobre «tareas» (posición 1).
        [300, () => {
            const o = pasosOrden;
            const c = o.centro("seccion-servidor");
            o.py = c.y;
            o.x0 = c.x;
            o.ev.mousePress(o.zona, c.x, c.y, Qt.LeftButton, Qt.NoModifier, -1);
        }],
        [60, () => {
            pasosOrden.py -= 20;
            pasosOrden.ev.mouseMove(pasosOrden.zona, pasosOrden.x0, pasosOrden.py, -1, Qt.LeftButton, Qt.NoModifier);
        }],
        [60, () => {
            pasosOrden.py -= 60;
            pasosOrden.ev.mouseMove(pasosOrden.zona, pasosOrden.x0, pasosOrden.py, -1, Qt.LeftButton, Qt.NoModifier);
        }],
        [60, () => {
            pasosOrden.py -= 60;
            pasosOrden.ev.mouseMove(pasosOrden.zona, pasosOrden.x0, pasosOrden.py, -1, Qt.LeftButton, Qt.NoModifier);
        }],
        [300, () => {
            const o = pasosOrden;
            o.v.comprobar(o.v.contenidoRaiz().arrastrada === "servidor" && o.v.uno("huecoSeccion") !== null, "arrastre: mientras arrastra hay hueco en el destino");
            o.v.comprobar(o.ordenTira() === "inicio,servidor,tareas,clase,proyectos,registro,revisiones,notas,finanzas", "arrastre: los demás se apartan", o.ordenTira());
            o.v.captura("orden-arrastrando");
            o.ev.mouseRelease(o.zona, o.x0, o.py, Qt.LeftButton, Qt.NoModifier, -1);
        }],
        [300, () => {
            const o = pasosOrden;
            const c = o.v.contenidoRaiz();
            o.v.comprobar(c.arrastrada === "" && o.ordenTira() === "inicio,servidor,tareas,clase,proyectos,registro,revisiones,notas,finanzas", "arrastre: al soltar se queda en su sitio", o.ordenTira());
            o.v.comprobar(c.seccion === "inicio", "arrastre: soltar no cambia la sección elegida");
            o.v.comprobar(o.v.uno("huecoSeccion") === null, "arrastre: al soltar el hueco se va");
        }],
        [800, () => {
            const o = pasosOrden;
            o.v.comprobar(o.guardado() === "inicio,servidor,tareas,clase,proyectos,registro,revisiones,notas,finanzas", "arrastre: el orden se guarda en secciones.json", String(o.guardado()));
            // Con una sección elegida por id, sigue siendo la misma.
            o.v.seccion("servidor");
        }],
        [500, () => {
            const o = pasosOrden;
            o.v.comprobar(o.v.contenidoRaiz().actual.id === "servidor" && o.v.cualquiera("seccionServidor") !== null, "arrastre: la sección y su carga perezosa van por id, no por posición");
            o.v.seccion("inicio");
            // Reabrir: un Contenido nuevo lee lo guardado.
            o.v.contenidoRaiz().orden = [];
        }],
        [100, () => {
            const o = pasosOrden;
            o.v.comprobar(o.ordenTira() === "inicio,tareas,clase,proyectos,servidor,registro,revisiones,notas,finanzas", "orden: sin orden vuelve el de siempre");
            o.v.contenidoRaiz().orden = ["finanzas", "zzz", "notas"];
        }],
        [300, () => {
            const o = pasosOrden;
            o.v.comprobar(o.ordenTira() === "finanzas,notas,inicio,tareas,clase,proyectos,servidor,registro,revisiones", "orden: con un guardado parcial y un id desconocido, el resto al final", o.ordenTira());
            o.v.contenidoRaiz().orden = [];
            // Como estaba, para los pasos que siguen.
            o.v.contenidoRaiz().shell.fijado = false;
            o.v.contenidoRaiz().shell.abierto = false;
        }],
        [700, () => {}]
    ]

    property real x0: 0
}
