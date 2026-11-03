import QtQuick
import QtTest
import Quickshell
import "shared"

// Prueba sin pantalla del selector de tema (la lanza panel.sh, al lado, una
// vez por tema). Panel.qml es el shell.qml de quickshell/temas convertido en
// FloatingWindow, con una lista (pruebaElegidos) en lugar de lanzar tema.sh y
// un contador (pruebaSalidas) en lugar del Qt.quit. Cada comprobación imprime
// OK o FALLO; al final, "Todo OK" o el recuento de fallos.
ShellRoot {
    id: prueba

    readonly property string dir: Quickshell.env("PRUEBA_DIR") + "/capturas/"
    readonly property string esperado: Quickshell.env("PRUEBA_TEMA")
    property int fallos: 0
    property int paso: 0
    property int seleccionInicial: -1

    Panel {
        id: panel
    }

    TestEvent {
        id: ev
    }

    function ok(cond, msg) {
        console.log((cond ? "OK    " : "FALLO ") + "[" + prueba.esperado + "] " + msg);
        if (!cond)
            prueba.fallos++;
    }

    function captura(nombre) {
        panel.pruebaCard.grabToImage(r => r.saveToFile(prueba.dir + prueba.esperado + "-" + nombre));
    }

    function buscarTexto(item, texto, acc) {
        if (item.text === texto)
            acc.push(item);
        for (let i = 0; i < item.children.length; i++)
            prueba.buscarTexto(item.children[i], texto, acc);
        return acc;
    }

    function marcas() {
        return prueba.buscarTexto(panel.pruebaCard, "󰄬", []).length;
    }

    readonly property var pasos: [function () {
            prueba.ok(Theme.nombreTema === prueba.esperado, "el tema activo es " + Theme.nombreTema);
            prueba.ok(Theme.temas.length >= 2 && Theme.temas.indexOf("default") >= 0 && Theme.temas.indexOf("liquido") >= 0, "lista los temas: " + Theme.temas.join(", "));
            prueba.ok(panel.pruebaFilas.count === Theme.temas.length, "una fila por tema (" + panel.pruebaFilas.count + ")");
            prueba.ok(panel.shown, "el panel sale abierto");
            prueba.ok(panel.sel === Theme.temas.indexOf(prueba.esperado), "la selección empieza en el tema activo (" + panel.sel + ")");
            prueba.ok(prueba.marcas() === 1, "una sola marca de activo");
            const fila = panel.pruebaFilas.itemAt(Theme.temas.indexOf(prueba.esperado));
            prueba.ok(fila.activo && prueba.buscarTexto(fila, "󰄬", []).length === 1, "la marca está en la fila del tema activo");
            prueba.seleccionInicial = panel.sel;
            prueba.captura("abierto.png");
            ev.keyClick(Qt.Key_Down, Qt.NoModifier, -1);
            ev.keyClick(Qt.Key_Down, Qt.NoModifier, -1);
        }, function () {
            prueba.ok(panel.sel === Theme.temas.length - 1, "↓ lleva a la última fila (" + panel.sel + ")");
            ev.keyClick(Qt.Key_Up, Qt.NoModifier, -1);
            ev.keyClick(Qt.Key_Up, Qt.NoModifier, -1);
            ev.keyClick(Qt.Key_Up, Qt.NoModifier, -1);
        }, function () {
            prueba.ok(panel.sel === 0, "↑ lleva a la primera y no se pasa (" + panel.sel + ")");
            prueba.captura("primera.png");
            ev.keyClick(Qt.Key_Down, Qt.NoModifier, -1);
        }, function () {
            prueba.captura("segunda.png");
            ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        }, function () {
            prueba.ok(panel.pruebaElegidos.length === 1 && panel.pruebaElegidos[0] === Theme.temas[1], "Enter aplica el tema seleccionado (" + panel.pruebaElegidos.join(",") + ")");
            prueba.ok(!panel.shown, "y el panel se recoge");
        }, function () {
            prueba.ok(panel.pruebaSalidas === 1, "el proceso sale al terminar de recogerse");
            panel.pruebaElegidos = [];
            panel.shown = true;
        }, function () {
            const fila = panel.pruebaFilas.itemAt(0);
            ev.mouseClick(fila, fila.width / 2, fila.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        }, function () {
            prueba.ok(panel.pruebaElegidos.length === 1 && panel.pruebaElegidos[0] === Theme.temas[0], "un clic en una fila aplica ese tema (" + panel.pruebaElegidos.join(",") + ")");
            prueba.ok(!panel.shown, "y el panel se recoge");
        }, function () {
            panel.pruebaElegidos = [];
            panel.shown = true;
        }, function () {
            ev.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
        }, function () {
            prueba.ok(!panel.shown && panel.pruebaElegidos.length === 0, "Escape cierra sin aplicar nada");
        }, function () {
            prueba.ok(panel.pruebaSalidas === 3, "salió una vez por cada cierre (" + panel.pruebaSalidas + ")");
            console.log(prueba.fallos === 0 ? "Todo OK" : prueba.fallos + " FALLOS");
            Qt.quit();
        }]

    Timer {
        // Lo que tarda en terminar la animación más larga, con margen.
        interval: 800
        repeat: true
        running: true
        onTriggered: {
            prueba.pasos[prueba.paso]();
            prueba.paso++;
            if (prueba.paso >= prueba.pasos.length)
                stop();
        }
    }
}
