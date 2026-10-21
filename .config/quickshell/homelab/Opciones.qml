import QtQuick
import QtQuick.Layouts
import "shared"
import "TareasLogica.js" as Logica

// Lo que se elige al escribir una tarea, nueva o ya hecha: el área, la
// sección (el proyecto), la prioridad y la fecha. Lo comparten la fila de
// «añadir» y el editor de una tarea; quien lo usa lee las propiedades.
ColumnLayout {
    id: opciones

    // Las secciones de Api.tareas (sin las de En pausa no se pierde nada: se
    // pueden elegir también).
    property var secciones: []
    property var areas: []
    // Lo elegido.
    property string seccion: ""
    property string prioridad: ""
    property string fecha: ""
    property alias area: campoArea.texto
    // «Hoy» del NUC (2026-10-20), para los atajos de fecha.
    property string hoy: ""
    // Un mensaje de lo que falta o está mal, bajo los campos.
    property string error: ""
    readonly property bool enfocado: campoArea.enfocado || campoFecha.enfocado

    signal aceptado
    signal cancelado

    spacing: 8

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    Etiqueta {
        text: "ÁREA"
    }

    Campo {
        id: campoArea

        objectName: "opArea"
        Layout.fillWidth: true
        pista: "Opcional: Casa, Homelab…"
        onAceptado: opciones.aceptado()
        onCancelado: opciones.cancelado()
    }

    Etiqueta {
        text: "SECCIÓN"
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: opciones.secciones

            delegate: Chip {
                required property var modelData

                objectName: "opSeccion-" + modelData.id
                texto: modelData.titulo
                activo: opciones.seccion === modelData.id
                conPunto: true
                puntoRadio: 2
                punto: modelData.pausa ? Theme.prioPausa : (modelData.color !== "" ? modelData.color : Theme.muted)
                onActivado: opciones.seccion = modelData.id
            }
        }
    }

    Etiqueta {
        text: "PRIORIDAD"
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: Logica.NIVELES

            delegate: Chip {
                required property string modelData

                objectName: "opPrio-" + modelData
                texto: Logica.NOMBRES[modelData]
                activo: opciones.prioridad === modelData
                conPunto: true
                punto: Theme.colorPrioridad(modelData)
                onActivado: opciones.prioridad = modelData
            }
        }

        Chip {
            objectName: "opPrio-ninguna"
            texto: "Sin prioridad"
            activo: opciones.prioridad === ""
            onActivado: opciones.prioridad = ""
        }
    }

    Etiqueta {
        text: "FECHA"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Campo {
            id: campoFecha

            objectName: "opFecha"
            Layout.preferredWidth: 110
            pista: "AAAA-MM-DD"
            Component.onCompleted: texto = opciones.fecha
            onTextoChanged: if (texto !== opciones.fecha)
                opciones.fecha = texto.trim()
            onAceptado: opciones.aceptado()
            onCancelado: opciones.cancelado()
        }

        Chip {
            objectName: "opHoy"
            texto: "Hoy"
            onActivado: opciones.fecha = Logica.fechaMasDias(opciones.hoy, 0)
        }

        Chip {
            objectName: "opManana"
            texto: "Mañana"
            onActivado: opciones.fecha = Logica.fechaMasDias(opciones.hoy, 1)
        }

        Chip {
            objectName: "opSemana"
            texto: "+1 sem"
            onActivado: opciones.fecha = Logica.fechaMasDias(opciones.hoy, 7)
        }

        Chip {
            objectName: "opSinFecha"
            texto: "Sin"
            onActivado: opciones.fecha = ""
        }
    }

    Text {
        Layout.fillWidth: true
        visible: opciones.error !== ""
        text: opciones.error
        color: Theme.prioMaxima
        font.family: Theme.font
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    // La fecha que se escribe y la que se elige con los atajos van a la vez:
    // el campo sigue a la propiedad.
    onFechaChanged: if (campoFecha.texto !== opciones.fecha)
        campoFecha.texto = opciones.fecha
}
