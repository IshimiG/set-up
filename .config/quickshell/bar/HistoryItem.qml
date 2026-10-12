import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "shared"

// Una entrada del historial.
//
// Puede estar viva —la notificación sigue existiendo en este proceso, retenida
// por el candado de shell.qml— o ser sólo un recuerdo leído del disco al
// arrancar. La diferencia se ve: una viva tiene sus acciones y se puede pulsar,
// una leída del disco no, porque una acción vive en el proceso de la aplicación
// que la mandó y no hay forma de resucitarla.
Rectangle {
    id: root

    required property var shell
    required property var panel
    required property var entry
    required property int index

    implicitHeight: cuerpo.implicitHeight + 20
    radius: Theme.radius - 2
    color: hover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    border.color: hover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }

    readonly property var notif: root.entry.notif ?? null
    readonly property var acciones: root.notif ? root.notif.actions : []

    // La acción "default" es la convención de freedesktop para "lo que pasa si
    // pulsas el aviso". Si la hay, pulsar la entrada la invoca; el resto de
    // acciones salen como botones.
    readonly property var accionPorDefecto: {
        for (let i = 0; i < root.acciones.length; i++) {
            if (root.acciones[i].identifier === "default")
                return root.acciones[i];
        }
        return null;
    }

    readonly property var accionesVisibles: {
        const out = [];
        for (let i = 0; i < root.acciones.length; i++) {
            if (root.acciones[i].identifier !== "default")
                out.push(root.acciones[i]);
        }
        return out;
    }

    HoverHandler {
        id: hover
        cursorShape: root.accionPorDefecto ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.accionPorDefecto !== null
        onTapped: {
            root.accionPorDefecto.invoke();
            root.shell.close();
        }
    }

    ColumnLayout {
        id: cuerpo

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.entry.summary
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: root.panel.hace(root.entry.time)
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
            }

            // Borrar sólo ésta. Aparece al pasar por encima: un aspa en cada
            // entrada, siempre visible, convertiría la lista en una rejilla de
            // botones.
            Text {
                text: "󰅖"
                color: aspaHover.hovered ? Theme.danger : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
                opacity: hover.hovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }

                HoverHandler {
                    id: aspaHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.shell.forgetEntry(root.index)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.entry.body
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        // Las acciones que la aplicación ofrezca, si la notificación sigue viva.
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: root.accionesVisibles.length > 0
            spacing: 6

            Repeater {
                model: root.accionesVisibles

                delegate: Rectangle {
                    id: boton

                    required property var modelData

                    implicitWidth: etiqueta.implicitWidth + 18
                    implicitHeight: 22
                    radius: 8
                    color: Qt.rgba(1, 1, 1, botonHover.hovered ? 0.18 : 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, botonHover.hovered ? 0.30 : 0.16)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        id: etiqueta
                        anchors.centerIn: parent
                        text: boton.modelData.text
                        color: botonHover.hovered ? Theme.strong : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    HoverHandler {
                        id: botonHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            boton.modelData.invoke();
                            root.shell.close();
                        }
                    }
                }
            }
        }
    }
}
