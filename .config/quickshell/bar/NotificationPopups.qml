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

    // La superficie es un marco: mide lo que las tarjetas más Theme.slideRoom
    // de aire por cada lado, y ese mismo aire se le descuenta a los márgenes,
    // así que las tarjetas se quedan exactamente donde estaban —a dropSide del
    // borde, a dropTop de arriba— y lo que sobra es hueco vacío por el que
    // pueden moverse mientras animan.
    //
    // Los márgenes salen negativos a propósito. Lo que la superficie saca
    // fuera de la pantalla no se ve, pero ahí no hay nada que ver: es el sitio
    // por el que la tarjeta entra y se va. Sin este marco la animación se
    // cortaba contra el borde de la propia superficie, y no sólo por donde la
    // tarjeta entra: el rebote se pasa de largo hacia el otro lado antes de
    // asentarse, así que también se partía por la izquierda.
    anchors.top: true
    anchors.right: true
    margins.top: Theme.dropTop - Theme.slideRoom
    margins.right: Theme.dropSide - Theme.slideRoom

    color: "transparent"
    visible: stack.children.length > 0

    implicitWidth: Theme.cardWidth + Theme.slideRoom * 2
    implicitHeight: Math.max(1, stack.implicitHeight) + Theme.slideRoom * 2

    // Ese marco no puede quedarse con los clics del escritorio que hay debajo:
    // sólo recibe pulsaciones lo que de verdad se está viendo.
    mask: Region {
        item: stack
    }

    ColumnLayout {
        id: stack

        anchors.fill: parent
        // El aire es para la animación, no para las tarjetas: ellas siguen
        // midiendo Theme.cardWidth y quedando en su sitio de siempre.
        anchors.margins: Theme.slideRoom
        spacing: Theme.gap

        Repeater {
            model: panel.server.trackedNotifications

            delegate: NotificationCard {
                id: entry

                required property var modelData

                notif: modelData
                Layout.fillWidth: true

                // El hueco que ocupa en la pila es el suyo propio hasta que se
                // retira: entonces encoge a cero y las de abajo suben con ella
                // en vez de dar un salto cuando desaparece.
                property real room: 1
                Layout.preferredHeight: implicitHeight * room

                // Descartar no la borra en el acto: primero se recoge, y sólo
                // cuando ha terminado de irse se le dice al servidor que está
                // cerrada. Si se borrara ya, el delegate se destruiría con la
                // animación a medias y no se vería nada.
                property bool leaving: false

                function retire() {
                    if (entry.leaving)
                        return;
                    entry.leaving = true;
                    leave.start();
                }

                onDismissed: entry.retire()
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
                // viene, y se va por ese mismo borde: el ancla de la escala
                // está a la derecha, así que encoger y deslizarse son el mismo
                // gesto y la tarjeta parece meterse por el canto de la
                // pantalla en vez de apagarse en el sitio.
                opacity: 0
                transformOrigin: Item.Right
                transform: Translate {
                    id: slide
                    x: Theme.slideRoom
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
                        duration: Theme.animIn
                        easing.type: Easing.OutBack
                        easing.overshoot: Theme.overshootIn
                    }
                }

                // Y al revés para irse: la tarjeta coge carrerilla creciendo un
                // pelín antes de encogerse —eso es el InBack, el rebote leído
                // al revés—, y sólo cuando ya no se ve cede su hueco en la
                // pila.
                SequentialAnimation {
                    id: leave

                    ParallelAnimation {
                        NumberAnimation {
                            target: entry
                            property: "scale"
                            to: 0.72
                            duration: Theme.animOut
                            easing.type: Easing.InBack
                            easing.overshoot: Theme.overshootOut
                        }
                        NumberAnimation {
                            target: slide
                            property: "x"
                            to: Theme.slideRoom
                            duration: Theme.animOut
                            easing.type: Easing.InBack
                            easing.overshoot: Theme.overshootOut
                        }
                        NumberAnimation {
                            target: entry
                            property: "opacity"
                            to: 0
                            duration: Theme.animOut - 60
                            easing.type: Easing.InCubic
                        }
                    }

                    NumberAnimation {
                        target: entry
                        property: "room"
                        to: 0
                        duration: 200
                        easing.type: Easing.InOutQuint
                    }

                    ScriptAction {
                        script: entry.modelData.dismiss()
                    }
                }
            }
        }
    }
}
