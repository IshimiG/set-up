import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import ".."
import "../shared"

// Lo de la barra que sólo tiene un portátil: la wifi, con su desplegable, y
// la batería. Lo carga shell.qml (ver "Lo de cada equipo" allí) y
// TelemetryBlock.qml lo coloca en sus huecos: la wifi antes del volumen y la
// batería detrás de la memoria, que es donde estaban.
//
// Vale para cualquier portátil de esta rama: si no hay iwd la wifi no sale, y
// sin batería tampoco la batería.
Scope {
    id: equipo

    required property var shell

    // Lo que TelemetryBlock.qml espera de un equipo.
    property Component antesDelVolumen: filaWifi
    property Component trasLaMemoria: filaBateria
    property Component desplegable: panelWifi
    property string modoDesplegable: "wifi"

    // El estado de la wifi, una sola vez para los dos monitores. Sólo pregunta
    // a menudo mientras el desplegable está abierto (mirando).
    Wifi {
        id: estadoWifi

        shell: equipo.shell
        mirando: equipo.shell.mode === "wifi"
    }

    // Abrir y cerrar el desplegable desde fuera, en el monitor con el foco:
    // qs -c bar ipc call wifi toggle
    IpcHandler {
        target: "wifi"

        function toggle(): string {
            equipo.shell.toggleFocused("wifi");
            return equipo.shell.mode === "wifi" ? "open" : "closed";
        }
    }

    Component {
        id: panelWifi

        // El Loader del desplegable (en SideBlock.qml) dice si está abierto.
        WifiPanel {
            shell: equipo.shell
            wifi: estadoWifi
            abierto: parent ? parent.abierto : false
        }
    }

    // --- Wi-Fi ---------------------------------------------------------------
    // Donde estaba en waybar con Omarchy: justo antes del volumen, con los
    // mismos cinco escalones de señal. El clic despliega el panel; Impala queda
    // en el clic derecho.
    Component {
        id: filaWifi

        RowLayout {
            id: fila

            // El bloque lo da el hueco de TelemetryBlock.qml que carga la fila.
            readonly property var bloque: parent ? parent.bloque : null

            spacing: 14

            Modulo {
                bloque: fila.bloque
                glifo: estadoWifi.glifo
                // Sin conexión no es un fallo, pero tampoco el estado normal: se
                // queda a la vista y apagado, como el volumen en silencio.
                atenuado: estadoWifi.conectada || (fila.bloque && fila.bloque.abierto) ? 1 : 0.45
                pista: {
                    if (!estadoWifi.hay)
                        return "";
                    if (!estadoWifi.encendida)
                        return "Wi-Fi apagada";
                    if (!estadoWifi.conectada)
                        return estadoWifi.estado === "connecting" ? "Conectando…" : "Sin conexión";
                    let p = estadoWifi.actual.nombre + "\n" + estadoWifi.actual.senal + " %";
                    if (estadoWifi.frecuencia > 0)
                        p += " · " + (estadoWifi.frecuencia / 1000).toFixed(1).replace(".", ",") + " GHz";
                    if (estadoWifi.ip !== "")
                        p += "\n" + estadoWifi.ip;
                    return p;
                }

                onPulsado: if (fila.bloque)
                    equipo.shell.toggle(fila.bloque.pantalla, "wifi")
                onPulsadoDerecho: estadoWifi.abrirImpala()
            }
        }
    }

    // --- Batería -------------------------------------------------------------
    // Sale de UPower, que avisa por su cuenta de cada cambio: no hay nada que
    // muestrear. Sin batería (o mientras UPower no ha contestado) el texto
    // queda vacío y el módulo se esconde solo.
    Component {
        id: filaBateria

        RowLayout {
            id: fila

            readonly property var bloque: parent ? parent.bloque : null

            spacing: 14

            Modulo {
                id: bateria

                readonly property var disp: UPower.displayDevice
                readonly property bool hay: bateria.disp !== null && bateria.disp.ready && bateria.disp.isLaptopBattery
                // percentage va de 0 a 1.
                readonly property int pct: bateria.hay ? Math.round(bateria.disp.percentage * 100) : 0
                readonly property bool enchufada: bateria.hay && bateria.disp.state !== UPowerDeviceState.Discharging && bateria.disp.state !== UPowerDeviceState.Empty

                // Los mismos glifos y umbrales que tenía la batería en waybar.
                readonly property var glifosDescarga: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
                readonly property var glifosCarga: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

                function duracion(segundos) {
                    const min = Math.round(segundos / 60);
                    if (min < 60)
                        return min + " min";
                    return Math.floor(min / 60) + " h " + (min % 60) + " min";
                }

                bloque: fila.bloque
                glifo: {
                    if (!bateria.hay)
                        return "";
                    const i = Math.max(0, Math.min(9, Math.floor(bateria.pct / 10)));
                    return bateria.enchufada ? bateria.glifosCarga[i] : bateria.glifosDescarga[i];
                }
                valor: bateria.hay ? bateria.pct + "%" : ""
                tinte: {
                    if (bateria.enchufada)
                        return Theme.ok;
                    if (bateria.pct <= 10)
                        return Theme.danger;
                    if (bateria.pct <= 20)
                        return Theme.warn;
                    return Theme.strong;
                }
                pista: {
                    if (!bateria.hay)
                        return "";
                    let p = "Batería " + bateria.pct + "%";
                    if (bateria.disp.state === UPowerDeviceState.FullyCharged)
                        p += "\nCargada";
                    else if (bateria.enchufada)
                        p += bateria.disp.timeToFull > 0 ? "\nLlena en " + bateria.duracion(bateria.disp.timeToFull) : "\nCargando";
                    else if (bateria.disp.timeToEmpty > 0)
                        p += "\nQuedan " + bateria.duracion(bateria.disp.timeToEmpty);
                    if (Math.abs(bateria.disp.changeRate) > 0.5)
                        p += " · " + Math.abs(bateria.disp.changeRate).toFixed(0) + " W";
                    return p;
                }
            }
        }
    }
}
