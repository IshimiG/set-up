import QtQuick
import QtTest
import Quickshell
import "homelab"

// Prueba sin pantalla del cajón (la lanza prueba.sh, al lado): el Cajon.qml
// del repo en una ventana de 700x900, con un shell falso y el ratón movido con
// TestEvent. Cada comprobación imprime OK o FALLO; al final, el recuento.
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

        Cajon {
            id: cajon
            anchors.fill: parent
            shell: falso
        }
    }

    TestEvent { id: ev }

    property var fallos: []
    property int hechas: 0

    function comprobar(ok, que) {
        console.log((ok ? "OK     " : "FALLO  ") + que + "  (progreso " + cajon.progreso.toFixed(3) + ", abierto " + falso.abierto + ", asoma " + cajon.asoma + ")");
        ventana.hechas++;
        if (!ok)
            ventana.fallos.push(que);
    }

    function captura(nombre) {
        envoltura.grabToImage(r => r.saveToFile(ventana.dir + nombre + ".png"));
    }

    function asaX() {
        return cajon.xCajon - cajon.asaHueco - cajon.asaAncho / 2;
    }

    property real px: 0
    readonly property int py: 450

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
            p[1]();
            motor.interval = ventana.i < ventana.pasos.length ? ventana.pasos[ventana.i][0] : 100;
            motor.restart();
        }
    }
}
