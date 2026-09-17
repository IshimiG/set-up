import QtQuick
import QtQuick.Layouts
import Quickshell
import "shared"

// El reloj de la pastilla. Clic abre el calendario.
//
// El día y la fecha van atenuados y la hora a plena opacidad, igual que en
// waybar: así la hora se lee de un vistazo y el resto queda como contexto.
//
// Lo que sí se ha perdido respecto a waybar es el clic que cambiaba a la fecha
// larga con el número de semana. Ya no hace falta un segundo formato apretado en
// la barra: la fecha larga y la semana están en la cabecera del calendario, que
// es donde se buscan.
Item {
    id: root

    required property var shell
    required property string screenName
    required property bool active

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : 26

    // El formato se pide con la configuración regional española explícita y no
    // con la del sistema: aquí LANG es en_GB y sólo LC_TIME es es_ES, así que
    // dejarlo al azar de qué variable gana daría "Wed 16" algunos días.
    readonly property var loc: Qt.locale("es_ES")

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.shell.now.toLocaleDateString(root.loc, "ddd d")
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
        }

        Text {
            text: root.shell.now.toLocaleTimeString(root.loc, "HH:mm")
            color: root.active || hover.hovered ? Theme.strong : Theme.text
            font.family: Theme.font
            font.pixelSize: 12

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.shell.toggle(root.screenName, "calendar")
    }
}
