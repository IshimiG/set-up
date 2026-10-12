import QtQuick
import Quickshell
import Quickshell.Io

// Las lecturas comunes de la barra, en un solo sitio y desde un solo proceso.
//
// Esto es lo que waybar no podía hacer. Allí cada monitor dibujaba su propia
// barra, y cada barra ejecutaba su propia copia de cada módulo. Aquí se lee una
// vez y lo pintan los dos.
//
// cpu, memoria y temperatura salen de /proc y /sys leídos con FileView: cero
// forks. Lo que sólo tiene una máquina (la GPU de NVIDIA, la batería del ratón
// Razer y el loopback del micrófono de la torre) lo lee su equipo/Equipo.qml.
Scope {
    id: tel

    // El daemon, para saber si la barra está escondida.
    required property var shell

    // Con la barra escondida no hay nadie mirando, así que no se lee nada. Es
    // gratis y es lo correcto: SUPER+SHIFT+V apaga también la telemetría.
    readonly property bool activo: !tel.shell.hidden

    // --- Un solo latido ----------------------------------------------------
    // Tres segundos, que es lo que tenían cpu, temperatura y gpu en waybar. La
    // memoria iba a cinco, pero no merece un temporizador propio: un segundo
    // temporizador para ahorrarse una lectura de /proc/meminfo, que no cuesta
    // ni un fork, sería cambiar un despertar por otro.
    //
    // El uso de CPU es el único dato que obliga a muestrear: es un incremento
    // entre dos lecturas de /proc/stat, no un valor que se pueda preguntar.
    readonly property int latido: 3000

    // --- CPU ---------------------------------------------------------------
    property int cpu: 0
    property real carga: 0
    property var previa: null

    // --- Memoria -----------------------------------------------------------
    property int memPct: 0
    property real memUsada: 0
    property real memTotal: 0
    property real swapUsada: 0

    // --- Temperatura -------------------------------------------------------
    property int grados: 0

    // =======================================================================
    // Lectura de /proc y /sys
    // =======================================================================

    FileView {
        id: fStat
        path: "/proc/stat"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: fMem
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
    }

    // El número de hwmonN cambia entre arranques, así que la ruta no se puede
    // escribir a mano. Se busca una vez al arrancar, por el nombre del sensor:
    // k10temp (o zenpower) en AMD, que es la torre, y coretemp en Intel, que es
    // el portátil. En los dos su temp1 es la del encapsulado entero: "Tctl" en
    // AMD, "Package id 0" en Intel. Antes se sondeaba bajo el dispositivo PCI
    // del k10temp, que sólo existe en la torre; buscar por nombre resuelve lo
    // mismo —la numeración que baila— y vale para cualquier máquina, por un
    // único fork al arrancar.
    property bool hwmonListo: false
    property string sensor: ""

    FileView {
        id: fTemp
        blockLoading: true
        printErrors: false
    }

    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat \"$h/name\" 2>/dev/null) in k10temp|zenpower|coretemp) echo \"$h/temp1_input\"; cat \"$h/temp1_label\" 2>/dev/null; exit;; esac; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lineas = this.text.split("\n");
                if (lineas[0] === "") {
                    console.warn("no hay sensor de CPU conocido (k10temp, zenpower, coretemp); la temperatura se queda en blanco");
                    return;
                }
                fTemp.path = lineas[0];
                tel.sensor = lineas[1] || "";
                tel.hwmonListo = true;
            }
        }
    }

    function muestrear() {
        // Ojo con el orden: primero se calcula con lo que hay y sólo después se
        // pide la relectura. FileView.reload() es asíncrono, así que leer justo
        // después de pedirla devuelve todavía el texto viejo, el incremento sale
        // cero y la división da NaN.

        const lineaCpu = fStat.text().split("\n")[0];
        if (lineaCpu.startsWith("cpu ")) {
            const n = lineaCpu.trim().split(/\s+/).slice(1).map(Number);
            // Los campos son user, nice, system, idle, iowait, irq, softirq...
            // El tiempo parado es idle + iowait.
            const total = n.reduce((a, b) => a + b, 0);
            const ocio = n[3] + n[4];
            if (tel.previa) {
                const dTotal = total - tel.previa.total;
                const dOcio = ocio - tel.previa.ocio;
                // Si no ha pasado tiempo entre muestras se conserva el valor
                // anterior en vez de enseñar un cero o un NaN.
                if (dTotal > 0)
                    tel.cpu = Math.max(0, Math.min(100, Math.round(100 * (1 - dOcio / dTotal))));
            }
            tel.previa = {
                total: total,
                ocio: ocio
            };
        }

        const m = {};
        const lineas = fMem.text().split("\n");
        for (let i = 0; i < lineas.length; i++) {
            const dos = lineas[i].split(":");
            if (dos.length === 2)
                m[dos[0]] = parseInt(dos[1]);
        }
        if (m.MemTotal > 0) {
            // MemAvailable y no MemFree: lo segundo deja fuera la caché, que el
            // sistema devuelve en cuanto hace falta, y hace parecer que la
            // memoria está llena cuando no lo está.
            const usadaKb = m.MemTotal - m.MemAvailable;
            tel.memUsada = usadaKb / 1048576;
            tel.memTotal = m.MemTotal / 1048576;
            tel.memPct = Math.round(100 * usadaKb / m.MemTotal);
            tel.swapUsada = ((m.SwapTotal || 0) - (m.SwapFree || 0)) / 1048576;
        }

        if (tel.hwmonListo) {
            const t = parseInt(fTemp.text());
            if (!isNaN(t))
                tel.grados = Math.round(t / 1000);
        }

        fStat.reload();
        fMem.reload();
        if (tel.hwmonListo)
            fTemp.reload();
    }

    Timer {
        interval: tel.latido
        running: tel.activo
        repeat: true
        triggeredOnStart: true
        onTriggered: tel.muestrear()
    }
}
