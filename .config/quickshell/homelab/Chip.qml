import QtQuick
import "shared"

// Un botón pequeño de cristal: texto (y, si hace falta, un glifo o un punto de
// color) sobre la lámina blanca de siempre. Lo usan el editor de tareas, las
// vistas, los hábitos y el botón de Aules.
Rectangle {
    id: chip

    property string texto: ""
    property string glifo: ""
    // Un punto de color delante del texto (la prioridad, el proyecto).
    property color punto: "transparent"
    property bool conPunto: false
    property real puntoRadio: 3.5
    property bool activo: false
    property bool encendido: true
    property int tamano: 11

    signal activado

    implicitWidth: fila.implicitWidth + 18
    implicitHeight: 26
    radius: 8
    opacity: chip.encendido ? 1 : 0.4
    color: chip.activo ? Qt.rgba(1, 1, 1, 0.14) : (sobre.hovered && chip.encendido ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
    border.width: 1
    border.color: chip.activo ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Row {
        id: fila

        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            visible: chip.conPunto
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 7
            implicitHeight: 7
            radius: chip.puntoRadio
            color: chip.punto
        }

        Text {
            visible: chip.glifo !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip.glifo
            color: chip.activo ? Theme.strong : Theme.text
            font.family: Theme.font
            font.pixelSize: chip.tamano
        }

        Text {
            visible: chip.texto !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip.texto
            color: chip.activo ? Theme.strong : Theme.text
            font.family: Theme.font
            font.pixelSize: chip.tamano
        }
    }

    HoverHandler {
        id: sobre
        cursorShape: chip.encendido ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: if (chip.encendido)
            chip.activado()
    }
}
