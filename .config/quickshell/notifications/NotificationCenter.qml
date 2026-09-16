import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// El centro de notificaciones: el panel con lo que ya se ha ido de la pantalla.
//
// Es una superficie a pantalla completa aunque el panel esté pegado a la
// derecha, porque así un clic en cualquier otro sitio lo cierra, igual que en
// el lanzador y el menú de sesión.
PanelWindow {
    id: center

    // El daemon, para llegar al historial y al modo silencioso sin duplicar
    // estado.
    required property var shell

    WlrLayershell.namespace: "notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    screen: {
        const focused = Hyprland.focusedMonitor;
        if (!focused)
            return null;
        const all = Quickshell.screens;
        for (let i = 0; i < all.length; i++) {
            if (all[i].name === focused.name)
                return all[i];
        }
        return null;
    }

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool shown: false

    function close() {
        center.shown = false;
        quitTimer.start();
    }

    Component.onCompleted: center.shown = true

    Timer {
        id: quitTimer
        interval: 200
        onTriggered: center.shell.centerOpen = false
    }

    // Cuánto hace que llegó, en palabras. Un reloj exacto no dice nada útil de
    // algo que ya pasó; lo que se quiere saber es si fue hace un momento o
    // esta mañana.
    function ago(stamp) {
        const secs = Math.max(0, Math.floor((Date.now() - stamp) / 1000));
        if (secs < 60)
            return "ahora";
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return "hace " + mins + " min";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return "hace " + hours + " h";
        return "hace " + Math.floor(hours / 24) + " d";
    }

    // Clic fuera del panel: cierra. Declarado antes que el panel, así que queda
    // por debajo y los clics sobre él los atienden sus propios manejadores; la
    // comprobación geométrica es lo que evita que se cierre al clicar dentro.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            const p = mapToItem(panel, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > panel.width || p.y > panel.height)
                center.close();
        }
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: center.close()
    }

    Rectangle {
        id: panel

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 14
        anchors.topMargin: 38
        anchors.bottomMargin: 14

        width: Theme.cardWidth + Theme.pad * 2
        radius: Theme.radius + 6

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.edgeTop
            }
            GradientStop {
                position: 1.0
                color: Theme.edgeBottom
            }
        }

        transformOrigin: Item.Right
        opacity: center.shown ? 1 : 0
        transform: Translate {
            x: center.shown ? 0 : 40

            Behavior on x {
                NumberAnimation {
                    duration: center.shown ? 300 : 180
                    easing.type: center.shown ? Easing.OutCubic : Easing.InCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: center.shown ? 160 : 180
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, panel.radius - 1)

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.glassTop
                }
                GradientStop {
                    position: 1.0
                    color: Theme.glassBottom
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Notificaciones"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                // Campana tachada mientras el silencio está puesto. Va en el
                // naranja de los avisos de la barra: no es un fallo, pero sí
                // algo que conviene no olvidarse puesto.
                Text {
                    text: center.shell.silent ? "󰂛" : "󰂚"
                    color: center.shell.silent ? Theme.warn : (bellHover.hovered ? Theme.strong : Theme.faint)
                    font.family: Theme.font
                    font.pixelSize: 14

                    HoverHandler {
                        id: bellHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: center.shell.silent = !center.shell.silent
                    }
                }

                Text {
                    visible: center.shell.history.length > 0
                    text: "󰩹"
                    color: clearHover.hovered ? Theme.strong : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 14

                    HoverHandler {
                        id: clearHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: center.shell.history = []
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 20
                visible: center.shell.history.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: center.shell.silent ? "Silencio puesto · nada que mostrar" : "No hay nada por aquí"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.gap
                model: center.shell.history

                delegate: Rectangle {
                    id: item

                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: itemContent.implicitHeight + Theme.pad * 2
                    radius: Theme.radius
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    ColumnLayout {
                        id: itemContent

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.pad
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconImage {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                visible: source != ""
                                source: item.modelData.appIcon ? Quickshell.iconPath(item.modelData.appIcon, true) : ""
                            }

                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.appName || "Sistema"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Text {
                                text: center.ago(item.modelData.time)
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData.summary
                            color: Theme.strong
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: item.modelData.body
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
