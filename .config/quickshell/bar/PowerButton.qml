import QtQuick
import Quickshell
import "shared"

// El botón de sesión. Clic abre el menú, clic derecho bloquea directo, que es la
// única de las cinco opciones que se usa a diario.
//
// En reposo va atenuado y al pasar por encima se enciende en el rojo de los
// estados críticos, para que quede claro que detrás hay algo que apaga el
// equipo. Sigue encendido mientras el menú está abierto, no sólo bajo el ratón:
// el panel sale de este botón, así que el botón tiene que seguir siendo su
// origen aunque el cursor se haya ido a elegir una opción.
//
// Eso último era, en waybar, todo un montaje: un script que preguntaba por las
// instancias vivas de Quickshell, un módulo con return-type json y señales
// SIGRTMIN+9 mandadas desde tres sitios distintos. Aquí es la propiedad
// "active", que la isla ya sabe.
Item {
    id: root

    required property var shell
    required property string screenName
    required property bool active

    implicitWidth: 22
    implicitHeight: parent ? parent.height : 26

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        font.family: Theme.font
        font.pixelSize: 13

        color: root.active || hover.hovered ? Theme.danger : Theme.strong
        opacity: root.active || hover.hovered ? 1 : 0.55

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.shell.toggle(root.screenName, "power")
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            root.shell.close();
            Quickshell.execDetached(["hyprlock"]);
        }
    }
}
