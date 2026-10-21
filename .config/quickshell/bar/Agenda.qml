import QtQuick
import Quickshell
import Quickshell.Io
import "shared/AgendaFormato.js" as Formato

// La agenda del calendario: lo que tiene fecha en el panel del homelab (las
// tareas de 00 Inicio y las entregas de Aules, lo mismo que va a Google
// Calendar).
//
// La barra no habla con el NUC: quien habla es el cajón del homelab, que es
// otro proceso, y deja la agenda en un fichero de $XDG_RUNTIME_DIR
// (homelab/Agenda.qml). Aquí solo se vigila ese fichero, sin sondear: el
// vigilante de FileView avisa cuando aparece, cuando se reemplaza y cuando se
// borra. El formato, en shared/AgendaFormato.js.
//
// Una sola lectura para los dos monitores, como Telemetry. Sin fichero, o con
// uno roto, datos es null y el calendario se queda con la rejilla sola.
Scope {
    id: agenda

    // La agenda leída (ver leer() en AgendaFormato.js), o null.
    readonly property var datos: p.datos

    // Las pruebas lo cambian.
    property string ruta: Formato.ruta(Quickshell.env("XDG_RUNTIME_DIR"))

    QtObject {
        id: p
        property var datos: null
    }

    FileView {
        id: fichero

        path: agenda.ruta
        watchChanges: agenda.ruta !== ""
        // Que no exista es lo normal (el cajón no está en marcha): no es un
        // error que haya que contar.
        printErrors: false

        onFileChanged: fichero.reload()
        onLoaded: p.datos = Formato.leer(fichero.text())
        onLoadFailed: p.datos = null
        onPathChanged: if (agenda.ruta === "")
            p.datos = null
    }
}
