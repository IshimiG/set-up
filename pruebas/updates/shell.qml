import QtQuick
import QtTest
import Quickshell

// Prueba sin pantalla del aviso de actualizaciones (la lanza prueba.sh, al
// lado). Aviso.qml es el shell.qml del repo convertido en FloatingWindow, con
// dos contadores en lugar de la terminal y del Qt.quit. Cada comprobación
// imprime OK o FALLO; al final, el recuento.
//
// La máscara no se puede probar de verdad sin compositor: offscreen nadie
// recorta los clics. Lo que sí se comprueba es lo que la máscara recorta: que
// las regiones miden la tarjeta en su sitio y que los dos botones quedan
// enteros dentro. Era justo lo que fallaba: la región se quedaba con la
// tarjeta encogida de la animación de entrada y acababa en el canto de arriba
// del botón.
ShellRoot {
    id: prueba

    readonly property string dir: Quickshell.env("PRUEBA_DIR") + "/capturas/"
    property int fallos: 0
    property int paso: 0

    Aviso {
        id: aviso
    }

    TestEvent {
        id: ev
    }

    function ok(cond, msg) {
        console.log((cond ? "OK    " : "FALLO ") + msg);
        if (!cond)
            prueba.fallos++;
    }

    function buscar(item, texto) {
        if (item.texto === texto)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const r = prueba.buscar(item.children[i], texto);
            if (r)
                return r;
        }
        return null;
    }

    function igual(region, item) {
        return region.x === item.x && region.y === item.y && region.width === item.width && region.height === item.height;
    }

    // Las cuatro esquinas del item, ya en coordenadas de la ventana y con las
    // transformaciones que tenga, dentro del rectángulo de la región.
    function enteroDentro(region, item) {
        const esquinas = [[0, 0], [item.width, 0], [0, item.height], [item.width, item.height]];
        for (const [ex, ey] of esquinas) {
            const p = item.mapToItem(null, ex, ey);
            if (p.x < region.x || p.x > region.x + region.width || p.y < region.y || p.y > region.y + region.height)
                return false;
        }
        return true;
    }

    function captura(item, nombre) {
        item.grabToImage(r => r.saveToFile(prueba.dir + nombre));
    }

    function clic(item, x, y) {
        ev.mouseClick(item, x, y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function centro(item) {
        prueba.clic(item, item.width / 2, item.height / 2);
    }

    readonly property Item card: aviso.pruebaCard
    readonly property Item mas: prueba.buscar(aviso.pruebaCard, "Más tarde")
    readonly property Item actualizar: prueba.buscar(aviso.pruebaCard, "Actualizar ahora")

    readonly property var pasos: [function () {
            prueba.ok(aviso.shown && !aviso.collapsed, "la tarjeta sale desplegada");
            prueba.ok(prueba.mas !== null && prueba.actualizar !== null, "están los dos botones");
            prueba.ok(aviso.mask === aviso.pruebaRegionCard, "desplegada, la máscara es la de la tarjeta");
            prueba.ok(prueba.igual(aviso.pruebaRegionCard, prueba.card), "la región mide la tarjeta en su sitio, sin la animación (" + aviso.pruebaRegionCard.height + " de alto)");
            prueba.ok(prueba.enteroDentro(aviso.pruebaRegionCard, prueba.actualizar), "«Actualizar ahora» queda entero dentro de la máscara");
            prueba.ok(prueba.enteroDentro(aviso.pruebaRegionCard, prueba.mas), "«Más tarde» queda entero dentro de la máscara");
            prueba.ok(prueba.actualizar.width > prueba.mas.width, "el principal es el más ancho (" + prueba.actualizar.width + " frente a " + prueba.mas.width + ")");
            prueba.captura(prueba.card, "tarjeta.png");
        }, function () {
            // En el relleno de la izquierda, a media altura: cristal y nada más.
            prueba.clic(prueba.card, 8, prueba.card.height / 2);
        }, function () {
            prueba.ok(aviso.shown && aviso.pruebaLanzadas === 0, "un clic en el cristal no descarta ni lanza nada");
            ev.mouseMove(prueba.actualizar, prueba.actualizar.width / 2, prueba.actualizar.height - 4, -1, Qt.NoButton, Qt.NoModifier);
        }, function () {
            prueba.captura(prueba.card, "hover.png");
            // La flecha de esconder, centrada en el relleno de arriba.
            prueba.clic(prueba.card, prueba.card.width / 2, 14);
        }, function () {
            prueba.ok(aviso.collapsed && aviso.shown, "la flecha esconde sin descartar");
            prueba.ok(aviso.mask === aviso.pruebaRegionTab, "escondida, la máscara es la de la pestaña");
            prueba.ok(prueba.igual(aviso.pruebaRegionTab, aviso.pruebaTab), "la región mide la pestaña en su sitio");
            prueba.captura(aviso.pruebaTab, "pestana.png");
            prueba.centro(aviso.pruebaTab);
        }, function () {
            prueba.ok(!aviso.collapsed, "la pestaña la vuelve a bajar");
            // Pulsado por la parte de abajo, que es la que antes no respondía,
            // y dos veces seguidas.
            prueba.clic(prueba.actualizar, prueba.actualizar.width / 2, prueba.actualizar.height - 4);
            prueba.clic(prueba.actualizar, prueba.actualizar.width / 2, prueba.actualizar.height - 4);
        }, function () {
            prueba.ok(aviso.pruebaLanzadas === 1, "«Actualizar ahora» lanza una sola terminal aunque se pulse dos veces (" + aviso.pruebaLanzadas + ")");
            prueba.ok(!aviso.shown, "y la tarjeta se recoge");
        }, function () {
            prueba.ok(aviso.pruebaSalidas === 1, "el proceso sale al terminar de recogerse");
            aviso.shown = true;
        }, function () {
            prueba.centro(prueba.mas);
        }, function () {
            prueba.ok(!aviso.shown && aviso.pruebaLanzadas === 1, "«Más tarde» descarta sin lanzar nada");
        }, function () {
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
