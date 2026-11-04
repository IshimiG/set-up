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
    Cristal {
        id: body

        anchors.fill: parent
        implicitHeight: content.implicitHeight + 9 * 2
        radius: Theme.radius

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
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 9
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // El icono sólo existe si carga de verdad: nada de hueco ni
                // del cuadro rosa y negro de «falta el icono». La imagen que
                // manda la aplicación (la foto de quien escribe) va antes que
                // el logotipo del programa.
                IconImage {
                    id: icono

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    visible: status === Image.Ready
                    // Sin icono que mostrar, ni ancho ni alto: el título
                    // empieza donde empezaría la tarjeta.
                    Layout.maximumWidth: visible ? 20 : 0
                    source: {
                        if (card.notif.image)
                            return card.notif.image;
                        const n = String(card.notif.appIcon || "");
                        if (n === "")
                            return "";
                        if (n.startsWith("/") || n.startsWith("file:"))
                            return n;
                        return Quickshell.iconPath(n, true);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.notif.summary
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: card.notif.appName || "Sistema"
                    visible: !hover.hovered || card.history
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                // El aspa sólo aparece con el ratón encima: en reposo la
                // tarjeta no necesita adornos.
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
                visible: text !== ""
                text: card.notif.body
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                // El cuerpo admite marcado, que es lo que se le ha dicho al
                // servidor en bodyMarkupSupported.
                textFormat: Text.StyledText
                // Un mensaje largo no puede empujar el resto de la pila fuera
                // de la pantalla.
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // Los botones que la aplicación haya ofrecido. La acción llamada
            // "default" no se pinta: es la que se invoca al pulsar la tarjeta.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6
                visible: children.length > 0

                Repeater {
                    model: card.notif.actions

                    delegate: Rectangle {
                        id: action

                        required property var modelData

                        visible: modelData.identifier !== "default"
                        width: visible ? label.implicitWidth + 22 : 0
                        height: visible ? 24 : 0
                        radius: Theme.radiusSmall

                        color: actionHover.hovered ? Theme.rule : "transparent"
                        border.width: 1
                        border.color: Theme.rule

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
