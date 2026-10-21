pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "shared"
import "MarkdownLogica.js" as Logica

// Las notas cambiadas en los últimos 7 días (api.notasRecientes), como la
// tarjeta «Notas recientes» de la web: el título, la carpeta y cuándo. Un clic
// abre la nota en Notas. Lo usan Notas (su índice) y el Inicio.
ColumnLayout {
    id: recientes

    // La lista de api.notasRecientes, o null sin leer todavía.
    property var lista: null
    // Cuántas, como mucho.
    property int maximo: 12
    // Sin ninguna, si se dice o no se dice nada (en Inicio, nada).
    property bool decirVacio: true

    signal abrir(string ruta)

    readonly property var vistas: recientes.lista ? recientes.lista.slice(0, recientes.maximo) : []

    spacing: 6

    Text {
        text: "NOTAS RECIENTES"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    Text {
        objectName: "recientesVacio"
        Layout.fillWidth: true
        visible: recientes.decirVacio && recientes.vistas.length === 0
        text: recientes.lista === null ? "Todavía sin leer las notas del NUC" : "Nada modificado en los últimos 7 días."
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: recientes.vistas

        delegate: Rectangle {
            id: fila

            required property var modelData

            objectName: "notaReciente"
            Layout.fillWidth: true
            implicitHeight: pila.implicitHeight + 14
            radius: 10
            color: sobre.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: Theme.rule

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Text {
                id: icono

                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
            }

            ColumnLayout {
                id: pila

                anchors.left: icono.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // El título sale de la nota (su «nombre»): texto plano, nunca
                // HTML.
                Text {
                    objectName: "tituloReciente"
                    Layout.fillWidth: true
                    text: fila.modelData.titulo
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: (Logica.carpeta(fila.modelData.ruta) || "Vault") + " · " + Logica.hace(fila.modelData.modificada)
                    textFormat: Text.PlainText
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }
            }

            HoverHandler {
                id: sobre
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: recientes.abrir(fila.modelData.ruta)
            }
        }
    }
}
