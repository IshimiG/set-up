import QtQuick
import QtTest
import Quickshell
import "homelab"
import "shared"

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
        property var api: apiFalsa
    }

    // La API falsa de la fase 2 (ApiFalsa.qml, al lado) y los avisos reales con
    // la orden sustituida: nada de notify-send de verdad.
    ApiFalsa {
        id: apiFalsa
    }

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
            ventana.comprobar(ventana.tiene("Entrega de prueba con fecha") && ventana.tiene("Una tarea sin proyecto"), "el Inicio enseña las tareas de la API");
            ventana.comprobar(ventana.tiene("vencida hace 2 días") && ventana.tiene("mañana"), "las tareas enseñan su «cuando»");
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
        [[50, () => ventana.comprobar(ventana.textos().indexOf("€") < 0, "no aparece ningún € en todo el texto del cajón")]],
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
