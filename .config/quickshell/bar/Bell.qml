import QtQuick
import Quickshell
import "shared"

// La campana. Clic abre el historial, clic derecho pone y quita el silencio.
//
// En reposo va atenuada como el resto de botones que casi nunca se pulsan; con
// el silencio puesto se enciende en el naranja de los avisos, porque un silencio
// olvidado es justo lo que conviene ver.
//
// Lo que es nuevo respecto a waybar: la campana reacciona cuando entra algo —da
// un respingo— y deja un punto encendido mientras quede algo sin mirar. Antes la
// barra no daba ninguna pista de que hubiera llegado nada: el historial guardaba
// cien avisos y el glifo seguía exactamente igual.
Item {
    id: root

    required property var shell
    required property string screenName
    required property bool active

    implicitWidth: 22
    implicitHeight: parent ? parent.height : 26

    Text {
        id: glyph

        anchors.centerIn: parent
        text: root.shell.silent ? "󰂛" : "󰂚"
        font.family: Theme.font
        font.pixelSize: 13

        color: root.shell.silent ? Theme.warn : Theme.strong
        // El atenuado va por opacidad y no por color para que el respingo y el
        // punto de aviso no tengan que recalcular nada.
        opacity: root.shell.silent || root.active || hover.hovered ? 1 : (root.shell.unread ? 0.85 : 0.55)

        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        // El respingo se hace sobre el glifo y no sobre el Item entero para que
        // no arrastre al punto de aviso ni empuje a los vecinos del RowLayout.
        transform: Rotation {
            id: swing
            origin.x: glyph.width / 2
            // Pivota arriba, como una campana colgada de su eje.
            origin.y: 0
            angle: 0
        }
    }

    // Campanilleo: dos vaivenes que se van apagando. Corto a propósito —es un
    // aviso, no una animación que haya que esperar—.
    SequentialAnimation {
        id: ring

        NumberAnimation {
            target: swing
            property: "angle"
            to: 13
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: swing
            property: "angle"
            to: -9
            duration: 130
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: swing
            property: "angle"
            to: 5
            duration: 110
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: swing
            property: "angle"
            to: 0
            duration: 140
            easing.type: Easing.OutBack
            easing.overshoot: 2.0
        }
    }

    Connections {
        target: root.shell
        // Con el silencio puesto no campanillea: si has pedido silencio, el
        // movimiento en el rabillo del ojo es tan intrusivo como el aviso.
        function onArrived() {
            if (!root.shell.silent)
                ring.restart();
        }
    }

    // El punto de "hay algo sin mirar". Va pegado arriba a la derecha del glifo,
    // fuera de su caja, para que no desplace nada al aparecer.
    Rectangle {
        id: dot

        anchors.right: glyph.right
        anchors.rightMargin: -2
        anchors.top: glyph.top
        anchors.topMargin: 1

        width: 5
        height: 5
        radius: 2.5
        color: Theme.ok

        // No tiene sentido con el silencio puesto: ahí la campana ya está
        // encendida en naranja diciendo otra cosa.
        readonly property bool wanted: root.shell.unread && !root.shell.silent

        opacity: wanted ? 1 : 0
        scale: wanted ? 1 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
                easing.overshoot: 3.0
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.shell.toggle(root.screenName, "notifications")
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.shell.silent = !root.shell.silent
    }
}
