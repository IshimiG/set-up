import QtQuick
import Quickshell
import Quickshell.Io

// El orden de las secciones de la tira entre reinicios: un JSON diminuto en
// $XDG_STATE_HOME/quickshell-homelab/secciones.json (como CajonEstado), propio
// de cada equipo. Un fichero que falta o está roto no es un problema: se queda
// el orden de siempre.
Item {
    id: estado

    readonly property string carpeta: {
        const prueba = Quickshell.env("PANEL_ESTADO_DIR");
        if (prueba)
            return prueba;
        const xdg = Quickshell.env("XDG_STATE_HOME");
        return (xdg ? xdg : Quickshell.env("HOME") + "/.local/state") + "/quickshell-homelab";
    }

    property bool carpetaLista: false
    property string pendiente: ""

    signal leido(var orden)

    function guardar(orden) {
        estado.pendiente = JSON.stringify({
            orden: orden
        });
        respiro.restart();
    }

    function volcar() {
        if (!estado.carpetaLista || estado.pendiente === "")
            return;
        fichero.setText(estado.pendiente);
        estado.pendiente = "";
    }

    Component.onDestruction: estado.volcar()

    Process {
        command: ["mkdir", "-p", estado.carpeta]
        running: true
        onExited: {
            estado.carpetaLista = true;
            estado.volcar();
        }
    }

    Timer {
        id: respiro

        interval: 400
        onTriggered: estado.volcar()
    }

    FileView {
        id: fichero

        path: estado.carpeta + "/secciones.json"
        atomicWrites: true
        watchChanges: false

        onLoaded: {
            try {
                const d = JSON.parse(fichero.text());
                if (Array.isArray(d.orden))
                    estado.leido(d.orden);
            } catch (e) {
                console.warn("orden de las secciones ilegible, se usa el de siempre: " + e);
            }
        }
    }
}
