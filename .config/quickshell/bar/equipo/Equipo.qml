import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../shared"

// Lo de la barra que sólo tiene la torre: la GPU de NVIDIA, la batería del
// ratón Razer y el loopback del micrófono. Lo carga shell.qml (ver "Lo de cada
// equipo" allí) y TelemetryBlock.qml lo coloca en sus huecos: el loopback antes
// del volumen, la GPU y el ratón detrás de la memoria, que es donde estaban.
//
// Las lecturas van aquí y no en cada fila porque hay una fila por monitor: se
// leen una vez y las pintan las dos, igual que Telemetry.qml.
Scope {
    id: equipo

    required property var shell

    // Con la barra escondida no hay nadie mirando, así que no se lee nada.
    readonly property bool activo: !equipo.shell.hidden

    // Lo que TelemetryBlock.qml espera de un equipo.
    property Component antesDelVolumen: filaLoopback
    property Component trasLaMemoria: filaGpuRaton
    property Component desplegable: null
    property string modoDesplegable: ""

    // --- GPU ---------------------------------------------------------------
    property bool gpuHay: false
    // Si nvidia-smi ha contestado bien alguna vez. Mientras no lo haya hecho,
    // el primer fallo basta para dejar de preguntar (ver el Process de abajo).
    property bool gpuVista: false
    property bool gpuDescartada: false
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
    // Si el loopback está configurado (el esquema GSettings de la extensión de
    // GNOME existe).
    property bool loopHay: true

    // =======================================================================
    // Lecturas
    // =======================================================================

    // La GPU es la única lectura que sigue necesitando un proceso, porque no
    // hay forma de sacar la telemetría de NVIDIA de /sys. Se llama a nvidia-smi
    // directamente: un fork por vuelta, al ritmo de Telemetry.qml.
    Timer {
        interval: 3000
        running: equipo.activo && !equipo.gpuDescartada
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!gpu.running)
            gpu.running = true
    }

    Process {
        id: gpu
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,name", "--format=csv,noheader,nounits"]

        // Se exige que el primer campo sea un número: nvidia-smi sin tarjeta
        // escribe "NVIDIA-SMI has failed…" por la salida normal. Si nunca ha
        // contestado bien, el primer fallo descarta la GPU y deja de lanzarse;
        // si ya contestó alguna vez, un fallo suelto sólo esconde el módulo
        // hasta la siguiente vuelta.
        stdout: StdioCollector {
            onStreamFinished: {
                const linea = this.text.trim().split("\n")[0];
                const c = linea.split(",").map(s => s.trim());
                if (linea === "" || isNaN(parseInt(c[0]))) {
                    equipo.gpuHay = false;
                    if (!equipo.gpuVista)
                        equipo.gpuDescartada = true;
                    return;
                }
                equipo.gpuVista = true;
                equipo.gpuPct = parseInt(c[0]) || 0;
                equipo.gpuGrados = parseInt(c[1]) || 0;
                equipo.gpuVram = parseInt(c[2]) || 0;
                equipo.gpuVramTotal = parseInt(c[3]) || 0;
                equipo.gpuVatios = parseFloat(c[4]) || 0;
                equipo.gpuNombre = c[5] || "";
                equipo.gpuHay = true;
            }
        }
    }

    // La batería del ratón sigue siendo mouse-battery.py porque UPower no ve el
    // Razer (`upower -e` sólo devuelve DisplayDevice). Un minuto sobra: la carga
    // de un ratón no se mueve más rápido.
    Process {
        id: raton
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/mouse-battery.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    equipo.ratonTexto = j.text || "";
                    equipo.ratonClase = j.class || "";
                } catch (e) {
                    equipo.ratonTexto = "";
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: equipo.activo
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!raton.running)
            raton.running = true
    }

    // El loopback sobrevive como script porque comparte estado con la app GTK3
    // por GSettings y carga un module-loopback de PulseAudio, que el servicio
    // Pipewire de Quickshell no toca.
    Process {
        id: loopback
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/loopback.sh", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    equipo.loopHay = j.alt !== "none";
                    equipo.loopActivo = j.alt === "on";
                    equipo.loopAviso = j.tooltip || "";
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

    // Sin intervalo: una única suscripción a los eventos de PulseAudio, y se
    // vuelve a preguntar sólo cuando se carga o descarga un módulo, que es lo
    // que hace el loopback. Los eventos de "client" van y vienen constantemente
    // (cada pactl que se ejecuta es uno), así que ésos no.
    Process {
        running: true
        command: ["pactl", "subscribe"]

        stdout: SplitParser {
            onRead: linea => {
                if (linea.indexOf("module") >= 0)
                    equipo.preguntarLoopback();
            }
        }
    }

    Component.onCompleted: equipo.preguntarLoopback()

    // =======================================================================
    // Módulos
    // =======================================================================

    Component {
        id: filaLoopback

        RowLayout {
            id: fila

            // El bloque lo da el hueco de TelemetryBlock.qml que carga la fila.
            readonly property var bloque: parent ? parent.bloque : null

            spacing: 14

            Modulo {
                bloque: fila.bloque
                // Sin glifo el módulo desaparece, que es lo que toca si el
                // loopback nunca se ha configurado: no hay nada que encender.
                glifo: !equipo.loopHay ? "" : (equipo.loopActivo ? "󰍬" : "󰍭")
                tinte: equipo.loopActivo ? Theme.ok : Theme.strong
                // No se esconde cuando está apagado: sin glifo no habría dónde
                // hacer clic para encenderlo.
                atenuado: equipo.loopActivo ? 1 : 0.45
                pista: equipo.loopAviso

                onPulsado: equipo.alternarLoopback()
                onPulsadoDerecho: Quickshell.execDetached(["pavucontrol"])
                onRueda: delta => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/loopback.sh", delta > 0 ? "up" : "down"])
            }
        }
    }

    Component {
        id: filaGpuRaton

        RowLayout {
            id: fila

            readonly property var bloque: parent ? parent.bloque : null

            spacing: 14

            Modulo {
                bloque: fila.bloque
                glifo: equipo.gpuHay ? "󰢮" : ""
                valor: equipo.gpuHay ? equipo.gpuPct + "% " + equipo.gpuGrados + "°" : ""
                tinte: fila.bloque ? fila.bloque.tintePorUso(equipo.gpuPct) : Theme.strong
                pista: {
                    if (!equipo.gpuHay)
                        return "";
                    let p = equipo.gpuNombre;
                    p += "\nUso " + equipo.gpuPct + "% · " + equipo.gpuGrados + "°C";
                    p += "\nVRAM " + equipo.gpuVram + " / " + equipo.gpuVramTotal + " MiB";
                    if (equipo.gpuVatios > 0)
                        p += "\nConsumo " + equipo.gpuVatios.toFixed(0) + " W";
                    return p;
                }

                onPulsado: if (fila.bloque)
                    fila.bloque.abrirBtop()
            }

            Modulo {
                bloque: fila.bloque
                glifo: equipo.ratonTexto === "" ? "" : "󰍽"
                valor: equipo.ratonTexto
                tinte: {
                    if (equipo.ratonClase === "critical")
                        return Theme.danger;
                    if (equipo.ratonClase === "warning")
                        return Theme.warn;
                    if (equipo.ratonClase === "charging")
                        return Theme.ok;
                    return Theme.strong;
                }
                pista: equipo.ratonTexto === "" ? "" : "Razer Viper V3 Pro SE · " + equipo.ratonTexto
            }
        }
    }
}
