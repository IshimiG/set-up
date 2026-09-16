import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Recordatorio rápido: SUPER+R, se escribe cuándo y qué, y Enter lo programa.
//
// La ventana no habla con systemd ni con el fichero de recordatorios: le pasa
// las dos cosas tal cual a ~/.config/hypr/scripts/recordar.sh como dos
// argumentos sueltos. Así no hay que escapar nada de lo que se acabe de
// teclear, y la confirmación —o el error, si no se entiende el cuándo— llega
// por el propio sistema de notificaciones, que para eso está.
PanelWindow {
    id: root

    WlrLayershell.namespace: "reminder"
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

    // Superficie a pantalla completa: la tarjeta se centra dentro y así un clic
    // en cualquier otro sitio la cierra.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // --- Glassmorphism ---------------------------------------------------
    // Mismos valores que el resto de superficies, que salen de waybar. El alfa
    // del cuerpo no puede bajar de 0.5 o el layer_rule deja de desenfocar.
    readonly property color cGlassTop: Qt.rgba(0, 0, 0, 0.76)
    readonly property color cGlassBottom: Qt.rgba(0, 0, 0, 0.64)
    readonly property color cEdgeTop: Qt.rgba(1, 1, 1, 0.30)
    readonly property color cEdgeBottom: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cText: Qt.rgba(1, 1, 1, 0.78)
    readonly property color cStrong: "#ffffff"
    readonly property color cMuted: Qt.rgba(1, 1, 1, 0.55)
    readonly property color cFaint: Qt.rgba(1, 1, 1, 0.35)
    readonly property color cRule: Qt.rgba(1, 1, 1, 0.12)

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int cardW: 460
    readonly property int pad: 22

    property bool shown: false

    readonly property bool listo: whenField.text.trim() !== "" && whatField.text.trim() !== ""

    function closeWindow() {
        root.shown = false;
        quitTimer.start();
    }

    function schedule() {
        if (!root.listo)
            return;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/recordar.sh", whenField.text.trim(), whatField.text.trim()]);
        root.closeWindow();
    }

    Component.onCompleted: root.shown = true

    Timer {
        id: quitTimer
        interval: 180
        onTriggered: Qt.quit()
    }

    // Clic fuera de la tarjeta: cierra. Declarado antes que la tarjeta, así que
    // queda por debajo y los campos de texto, que están por delante, se quedan
    // con los suyos. La comprobación geométrica evita cerrar al clicar dentro.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            const p = mapToItem(card, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height)
                root.closeWindow();
        }
    }

    // La capa exterior es *solo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire.
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: root.cardW
        height: content.implicitHeight + root.pad * 2
        radius: 20

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.cEdgeTop
            }
            GradientStop {
                position: 1.0
                color: root.cEdgeBottom
            }
        }

        scale: root.shown ? 1 : 0.88
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? 380 : 170
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.2
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 140 : 170
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, card.radius - 1)

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.cGlassTop
                }
                GradientStop {
                    position: 1.0
                    color: root.cGlassBottom
                }
            }
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 10

            // Cuándo. Va primero y con el foco porque es lo que más se tarda en
            // decidir; el texto sale solo una vez sabes para cuándo es.
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "󰀠"
                    color: root.cMuted
                    font.family: root.font
                    font.pixelSize: 18
                }

                TextField {
                    id: whenField

                    Layout.fillWidth: true
                    focus: true
                    placeholderText: "en 20m · mañana 9:00 · 18:30"
                    placeholderTextColor: root.cFaint
                    color: root.cStrong
                    font.family: root.font
                    font.pixelSize: 16
                    padding: 0
                    background: Rectangle {
                        color: "transparent"
                    }

                    Keys.onEscapePressed: root.closeWindow()
                    Keys.onReturnPressed: whatField.forceActiveFocus()
                    Keys.onEnterPressed: whatField.forceActiveFocus()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: root.cRule
            }

            // Qué.
            TextField {
                id: whatField

                Layout.fillWidth: true
                placeholderText: "¿de qué te aviso?"
                placeholderTextColor: root.cFaint
                color: root.cText
                font.family: root.font
                font.pixelSize: 14
                padding: 0
                background: Rectangle {
                    color: "transparent"
                }

                Keys.onEscapePressed: root.closeWindow()
                Keys.onReturnPressed: root.schedule()
                Keys.onEnterPressed: root.schedule()
                // Shift+Tab vuelve arriba; el Tab normal ya lo hace QML solo.
                KeyNavigation.backtab: whenField
            }

            // El pie sólo dice qué hacer cuando ya se puede hacer algo: con un
            // campo a medias, "Enter para programar" sería mentira.
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                horizontalAlignment: Text.AlignRight
                text: root.listo ? "Enter para programar" : "Tab para pasar al texto"
                color: root.cFaint
                font.family: root.font
                font.pixelSize: 11
            }
        }
    }
}
