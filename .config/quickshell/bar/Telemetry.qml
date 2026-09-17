import QtQuick
import Quickshell
import Quickshell.Io

// Todas las lecturas de la barra, en un solo sitio y desde un solo proceso.
//
// Esto es lo que waybar no podía hacer. Allí cada monitor dibujaba su propia
// barra, y cada barra ejecutaba su propia copia de cada módulo: gpu.sh cada 3 s
// y loopback.sh cada 5 s, por dos, más las dos copias de mouse-battery.py
// peleándose por el mismo nodo /dev/hidraw. Aquí se lee una vez y lo pintan los
// dos.
//
// Y casi nada de esto lanza ya un proceso:
//
//   - cpu, memoria y temperatura salen de /proc y /sys leídos con FileView.
//     Cero forks.
//   - la gpu es la única que sigue necesitando un proceso, porque no hay forma
//     de sacar la telemetría de NVIDIA de /sys. Pero se llama a nvidia-smi
//     directamente en vez de a gpu.sh, que era bash + nvidia-smi + jq + seis
//     sed: de nueve forks por vuelta a uno.
//   - la batería del ratón sigue siendo mouse-battery.py porque UPower no ve el
//     Razer (comprobado: `upower -e` sólo devuelve DisplayDevice). Pero se
//     ejecuta una vez en lugar de dos.
//   - el loopback deja de tener intervalo: se pregunta al hacer clic, y para los
//     cambios que vengan de fuera hay una única suscripción a `pactl subscribe`.
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

    // --- GPU ---------------------------------------------------------------
    property bool gpuHay: false
    property int gpuPct: 0
    property int gpuGrados: 0
    property int gpuVram: 0
    property int gpuVramTotal: 0
    property real gpuVatios: 0
    property string gpuNombre: ""

    // --- Ratón -------------------------------------------------------------
    // Texto vacío significa "no contesta", que para este ratón quiere decir
    // apagado: un Razer dormido no responde a la petición HID. El módulo se
    // esconde en lugar de enseñar un cero, que es lo que hacía creer que la
    // batería estaba agotada.
    property string ratonTexto: ""
    property string ratonClase: ""

    // --- Loopback del micrófono --------------------------------------------
    property bool loopActivo: false
    property string loopAviso: ""

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
    // escribir a mano. Se sondea al arrancar probando uno tras otro bajo el
    // directorio del dispositivo PCI —que sí es estable— hasta que uno responde.
    // Se usa la ruta del dispositivo y no /sys/class/hwmon justamente por lo
    // mismo: allí la numeración también baila.
    property int candidatoHwmon: 0
    property bool hwmonListo: false

    FileView {
        id: fTemp
        path: "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon" + tel.candidatoHwmon + "/temp1_input"
        blockLoading: true
        printErrors: false
    }

    // El sondeo va por pasos desde un temporizador y no encadenado desde
    // onLoadFailed: cambiar el "path" desde dentro del manejador de fallo no
    // vuelve a intentarlo, comprobado.
    Timer {
        id: sondeo
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            if (!isNaN(parseInt(fTemp.text()))) {
                tel.hwmonListo = true;
                sondeo.running = false;
                return;
            }
            if (tel.candidatoHwmon >= 8) {
                sondeo.running = false;
                console.warn("no se ha encontrado el hwmon del k10temp; la temperatura se queda en blanco");
                return;
            }
            tel.candidatoHwmon++;
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
        onTriggered: {
            tel.muestrear();
            if (!gpu.running)
                gpu.running = true;
        }
    }

    // =======================================================================
    // Lo que sí necesita procesos
    // =======================================================================

    Process {
        id: gpu
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,name", "--format=csv,noheader,nounits"]

        stdout: StdioCollector {
            onStreamFinished: {
                const linea = this.text.trim().split("\n")[0];
                if (linea === "") {
                    tel.gpuHay = false;
                    return;
                }
                const c = linea.split(",").map(s => s.trim());
                tel.gpuPct = parseInt(c[0]) || 0;
                tel.gpuGrados = parseInt(c[1]) || 0;
                tel.gpuVram = parseInt(c[2]) || 0;
                tel.gpuVramTotal = parseInt(c[3]) || 0;
                tel.gpuVatios = parseFloat(c[4]) || 0;
                tel.gpuNombre = c[5] || "";
                tel.gpuHay = true;
            }
        }
    }

    // Un minuto sobra: la carga de un ratón no se mueve más rápido.
    Process {
        id: raton
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/mouse-battery.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    tel.ratonTexto = j.text || "";
                    tel.ratonClase = j.class || "";
                } catch (e) {
                    tel.ratonTexto = "";
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: tel.activo
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!raton.running)
            raton.running = true
    }

    // El loopback del micrófono sobrevive como script porque comparte estado con
    // la app GTK3 por GSettings y carga un module-loopback de PulseAudio, que el
    // servicio Pipewire de Quickshell no toca.
    Process {
        id: loopback
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/loopback.sh", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    tel.loopActivo = j.alt === "on";
                    tel.loopAviso = j.tooltip || "";
                } catch (e) {}
            }
        }
    }

    function preguntarLoopback() {
        if (!loopback.running)
            loopback.running = true;
    }

    function alternarLoopback() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/loopback.sh", "toggle"]);
    }

    // En vez del intervalo de 5 segundos que tenía waybar: una única suscripción
    // a los eventos de PulseAudio, y se vuelve a preguntar sólo cuando algo se
    // mueve de verdad. Los eventos de "client" van y vienen constantemente —cada
    // pactl que se ejecuta es uno—, así que sólo interesan los de módulo, que es
    // lo que carga y descarga el loopback.
    Process {
        running: true
        command: ["pactl", "subscribe"]

        stdout: SplitParser {
            onRead: linea => {
                if (linea.indexOf("module") >= 0)
                    tel.preguntarLoopback();
            }
        }
    }

    Component.onCompleted: tel.preguntarLoopback()
}
