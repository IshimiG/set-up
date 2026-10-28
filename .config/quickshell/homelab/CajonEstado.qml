import QtQuick
import Quickshell
import Quickshell.Io

// El ancho del cajón entre reinicios: un JSON diminuto en
// $XDG_STATE_HOME/quickshell-homelab/cajon.json (como TareasEstado). Un fichero
// que falta o está roto no es un problema: se empieza con el ancho de siempre.
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

    signal leido(int ancho)

    function guardar(ancho) {
        estado.pendiente = JSON.stringify({
            ancho: Math.round(ancho)
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

        interval: 600
        onTriggered: estado.volcar()
    }

    FileView {
        id: fichero

        path: estado.carpeta + "/cajon.json"
        atomicWrites: true
        watchChanges: false

        onLoaded: {
            try {
                const d = JSON.parse(fichero.text());
                if (typeof d.ancho === "number" && d.ancho > 0)
                    estado.leido(d.ancho);
            } catch (e) {
                console.warn("ancho del cajón ilegible, se usa el de siempre: " + e);
            }
        }
    }
}
