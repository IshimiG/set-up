import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// La pila de avisos que salta a la pantalla, colgada de la esquina superior
// derecha por debajo de la barra.
//
// Va aparte de la isla a propósito: un aviso aparece solo, sin que nadie pulse
// nada, y desplegar media barra por su cuenta sería justo lo que no se quiere.
// La ventana crece y encoge con su contenido, así que fuera de las tarjetas el
// escritorio sigue recibiendo sus clics.
PanelWindow {
    id: panel

    required property var shell
    required property var server

    WlrLayershell.namespace: "notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // Un aviso no roba el teclado: lo que estés escribiendo sigue yendo donde
    // estabas escribiéndolo.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
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

    anchors.top: true
    anchors.right: true
    margins.top: Theme.dropTop
    margins.right: Theme.dropSide

    color: "transparent"
    visible: stack.children.length > 0

    implicitWidth: Theme.cardWidth
    implicitHeight: Math.max(1, stack.implicitHeight)

    ColumnLayout {
        id: stack

        anchors.fill: parent
        spacing: Theme.gap

        Repeater {
            model: panel.server.trackedNotifications

            delegate: NotificationCard {
                id: entry

                required property var modelData

                notif: modelData
                Layout.fillWidth: true

                onDismissed: modelData.dismiss()
                onInvoked: identifier => {
                    const actions = modelData.actions;
                    for (let i = 0; i < actions.length; i++) {
                        if (actions[i].identifier === identifier) {
                            actions[i].invoke();
                            return;
                        }
                    }
                }

                // Entra deslizándose desde el borde derecho, que es de donde
                // viene.
                opacity: 0
                transform: Translate {
                    id: slide
                    x: 30
                }

                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter

                    NumberAnimation {
                        target: entry
                        property: "opacity"
                        to: 1
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: slide
                        property: "x"
                        to: 0
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
                    }
                }
            }
        }
    }
}
