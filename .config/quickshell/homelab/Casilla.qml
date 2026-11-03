import QtQuick
import "shared"

// La casilla redonda de marcar como hecha: un aro del color que se le dé y, al
// marcarla, el aro relleno con una marca.
Rectangle {
    id: casilla

    property bool marcada: false
    property color tinte: Theme.text
    property int lado: 18

    signal activado

    implicitWidth: casilla.lado
    implicitHeight: casilla.lado
    radius: casilla.lado / 2
    color: casilla.marcada ? Qt.rgba(casilla.tinte.r, casilla.tinte.g, casilla.tinte.b, 0.3) : (sobre.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
    border.width: 1.5
    border.color: casilla.marcada ? casilla.tinte : Theme.muted

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Text {
        anchors.centerIn: parent
        visible: casilla.marcada
        text: ""
        color: Theme.strong
        font.family: Theme.font
        font.pixelSize: casilla.lado * 0.5
    }

    HoverHandler {
        id: sobre
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: casilla.activado()
    }
}
