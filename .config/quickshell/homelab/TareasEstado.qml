import QtQuick
import Quickshell
import Quickshell.Io
import "TareasLogica.js" as Logica

// Lo que Tareas recuerda entre reinicios: la vista elegida y los grupos que se
// han plegado o desplegado a mano. Va en un JSON pequeño bajo el estado del
// usuario ($XDG_STATE_HOME o ~/.local/state, en quickshell-homelab/), no en la
// configuración (que es del repo). Se lee una vez al crearse (señal «leido») y
// se escribe, con un respiro para no escribir en cada clic, con guardar().
//
// Un fichero que falta, ilegible o con algo raro no es un problema: se
// empieza con lo de siempre.
Item {
    id: estado

    // La carpeta; la prueba pone la suya con PANEL_ESTADO_DIR.
    readonly property string carpeta: {
        const prueba = Quickshell.env("PANEL_ESTADO_DIR");
        if (prueba)
            return prueba;
        const xdg = Quickshell.env("XDG_STATE_HOME");
        return (xdg ? xdg : Quickshell.env("HOME") + "/.local/state") + "/quickshell-homelab";
    }
    property string ruta: estado.carpeta + "/tareas.json"

    // Ya se ha intentado leer: hasta entonces no se escribe (se pisaría lo guardado).
    property bool listo: false
    signal leido(string vista, var plegados)

    // La carpeta existe (FileView no la crea).
    property bool carpetaLista: false

    // Lo último escrito o leído, para no escribir lo mismo.
    property string ultimo: ""
    property string pendiente: ""

    // Pone el texto que toca, solo si de verdad cambia algo.
    function guardar(vista, plegados) {
        const texto = JSON.stringify({
            vista: vista,
            plegados: plegados
        });
        if (texto === estado.ultimo)
            return;
        estado.pendiente = texto;
        respiro.restart();
    }

    function volcar() {
        if (!estado.listo || !estado.carpetaLista || estado.pendiente === "")
            return;
        estado.ultimo = estado.pendiente;
        fichero.setText(estado.pendiente);
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

        path: estado.ruta
        atomicWrites: true
        // Solo este proceso lo escribe.
        watchChanges: false

        onLoaded: {
            try {
                const d = JSON.parse(fichero.text());
                const vista = Logica.VISTAS.some(v => v[0] === d.vista) ? d.vista : "plazo";
                const plegados = {};
                if (d.plegados && typeof d.plegados === "object")
                    for (const k of Object.keys(d.plegados))
                        if (typeof d.plegados[k] === "boolean")
                            plegados[k] = d.plegados[k];
                estado.ultimo = JSON.stringify({
                    vista: vista,
                    plegados: plegados
                });
                estado.listo = true;
                estado.leido(vista, plegados);
            } catch (e) {
                console.warn("estado de las tareas ilegible, se empieza de cero: " + e);
                estado.listo = true;
            }
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("no se pudo leer el estado de las tareas: " + err);
            estado.listo = true;
        }
    }
}
