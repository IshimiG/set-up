import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "shared"

// Una notificación en pantalla: la lámina de cristal con el icono de la
// aplicación, el título, el cuerpo y los botones de acción que la propia
// aplicación haya ofrecido.
Item {
    id: card

    required property var notif
    // Cuándo llegó, para la línea de "hace tanto" del historial. La tarjeta en
    // vivo no la usa, pero el mismo componente sirve para las dos cosas.
    property bool history: false

    signal dismissed
    signal invoked(string identifier)

    implicitWidth: Theme.cardWidth
    implicitHeight: body.implicitHeight

    // Las críticas no se van solas; el resto se queda el plazo que pida la
    // aplicación, pero nunca menos del suelo de Theme.minTimeout, y si no pide
    // ninguno se le da el de su urgencia. Pedir cero sigue significando
    // "no te vayas sola".
    readonly property int timeout: {
        if (card.history)
            return 0;
        const asked = card.notif.expireTimeout;
        if (asked > 0)
            return Math.max(asked, Theme.minTimeout);
        if (asked === 0)
            return 0;
        return Theme.timeoutFor(card.notif.urgency);
    }

    // El reloj se para mientras el ratón está encima: una notificación no debe
    // desaparecer justo cuando vas a pulsar uno de sus botones.
    Timer {
        running: card.timeout > 0 && !hover.hovered
        interval: card.timeout
        onTriggered: card.dismissed()
    }

    HoverHandler {
        id: hover
    }

    // La capa exterior es *solo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire.
    Rectangle {
        id: body

        anchors.fill: parent
        implicitHeight: content.implicitHeight + Theme.pad * 2
        radius: Theme.radius

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

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, body.radius - 1)

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

        // Las críticas llevan un filo rojo a la izquierda. Es la única
        // concesión al color: en la barra el rojo significa exactamente esto.
        Rectangle {
            visible: card.notif.urgency === NotificationUrgency.Critical
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: 3
            color: Theme.danger
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // La imagen que manda la aplicación manda sobre su icono: si
                // hay una foto de quien escribe, dice más que el logotipo del
                // programa.
                IconImage {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    visible: source != ""
                    source: {
                        if (card.notif.image)
                            return card.notif.image;
                        if (card.notif.appIcon)
                            return Quickshell.iconPath(card.notif.appIcon, true);
                        return "";
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: card.notif.appName || "Sistema"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }

                        // El aspa sólo aparece con el ratón encima: en reposo
                        // la tarjeta no necesita adornos.
                        Text {
                            visible: hover.hovered && !card.history
                            text: "󰅖"
                            color: closeHover.hovered ? Theme.strong : Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 12

                            HoverHandler {
                                id: closeHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: card.dismissed()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.notif.summary
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif.body
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                // El cuerpo admite marcado, que es lo que se le ha dicho al
                // servidor en bodyMarkupSupported.
                textFormat: Text.StyledText
                // Un mensaje largo no puede empujar el resto de la pila fuera
                // de la pantalla.
                maximumLineCount: 6
                elide: Text.ElideRight
            }

            // Los botones que la aplicación haya ofrecido. La acción llamada
            // "default" no se pinta: es la que se invoca al pulsar la tarjeta.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: children.length > 0

                Repeater {
                    model: card.notif.actions

                    delegate: Rectangle {
                        id: action

                        required property var modelData

                        visible: modelData.identifier !== "default"
                        width: visible ? label.implicitWidth + 22 : 0
                        height: visible ? 26 : 0
                        radius: 9

                        color: Qt.rgba(1, 1, 1, actionHover.hovered ? 0.20 : 0.10)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, actionHover.hovered ? 0.38 : 0.20)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: action.modelData.text
                            color: Theme.strong
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        HoverHandler {
                            id: actionHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: card.invoked(action.modelData.identifier)
                        }
                    }
                }
            }
        }

        // Pulsar la tarjeta invoca la acción por defecto si la hay —abrir el
        // mensaje, ir al evento— y, si no, simplemente la descarta. Va el
        // último, así que los botones y el aspa, que están por delante, se
        // quedan con los suyos.
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onPressed: {
                const actions = card.notif.actions;
                for (let i = 0; i < actions.length; i++) {
                    if (actions[i].identifier === "default") {
                        card.invoked("default");
                        return;
                    }
                }
                card.dismissed();
            }
        }
    }
}
