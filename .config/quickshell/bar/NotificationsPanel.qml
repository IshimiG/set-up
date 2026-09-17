import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "shared"

// El historial, que es lo que la campana enseña al crecer.
//
// Tres cosas que no tenía el centro anterior:
//
//  - Va agrupado por aplicación. Con cinco mensajes de Signal seguidos, antes
//    eran cinco tarjetas iguales apiladas; ahora es un bloque de Signal con
//    cinco líneas y la cuenta en la cabecera.
//  - Se puede borrar una sola entrada, y no sólo vaciarlo todo.
//  - Las entradas siguen teniendo sus acciones. Esto no es evidente: una
//    notificación muere cuando se cierra, y con ella sus acciones. Lo que las
//    mantiene vivas es el RetainableLock de shell.qml, que conserva el objeto
//    aunque ya se haya ido de la pantalla.
//
// La excepción son las entradas que se leen del disco al arrancar: una
// notificación no se puede resucitar en otro proceso, así que ésas se pintan
// igual pero sin nada que pulsar, y lo dicen.
Item {
    id: root

    required property var shell

    implicitWidth: Theme.cardWidth + Theme.pad * 2
    // La altura se toma del propio layout en lugar de sumar a mano sus piezas:
    // sumándolas se olvidaban la regla divisoria y uno de los espaciados, y la
    // última tarjeta quedaba cortada por abajo.
    implicitHeight: columna.implicitHeight + Theme.pad * 2

    // Hasta dónde puede crecer la lista antes de empezar a hacer scroll. Sin
    // tope, treinta notificaciones dejarían la isla más alta que la pantalla.
    readonly property int listaMax: 420

    // Agrupado por aplicación, conservando el orden en que aparecieron: la
    // aplicación de la notificación más reciente va arriba.
    readonly property var groups: {
        const out = [];
        const porApp = {};
        const h = root.shell.history;
        for (let i = 0; i < h.length; i++) {
            const e = h[i];
            const clave = e.appName || "Sistema";
            if (!(clave in porApp)) {
                porApp[clave] = {
                    app: clave,
                    icon: e.appIcon,
                    items: []
                };
                out.push(porApp[clave]);
            }
            porApp[clave].items.push({
                entry: e,
                index: i
            });
        }
        return out;
    }

    // Cuánto hace que llegó, en palabras. Un reloj exacto no dice nada útil de
    // algo que ya pasó; lo que se quiere saber es si fue hace un momento o esta
    // mañana.
    function hace(stamp) {
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

    ColumnLayout {
        id: columna

        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: 10

        RowLayout {
            id: cabecera

            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "Notificaciones"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 13
            }

            // Campana tachada mientras el silencio está puesto, en el naranja de
            // los avisos: no es un fallo, pero sí algo que conviene no olvidarse
            // puesto.
            Text {
                text: root.shell.silent ? "󰂛" : "󰂚"
                color: root.shell.silent ? Theme.warn : (campanaHover.hovered ? Theme.strong : Theme.faint)
                font.family: Theme.font
                font.pixelSize: 14

                HoverHandler {
                    id: campanaHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.shell.silent = !root.shell.silent
                }
            }

            Text {
                visible: root.shell.history.length > 0
                text: "󰩹"
                color: vaciarHover.hovered ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 14

                HoverHandler {
                    id: vaciarHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.shell.clearHistory()
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
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            visible: root.shell.history.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: root.shell.silent ? "Silencio puesto · nada que mostrar" : "No hay nada por aquí"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12
        }

        ListView {
            id: lista

            Layout.fillWidth: true
            // Alto pedido, no "el que sobre": es lo que permite que el layout
            // sepa cuánto mide, y con ello la isla cuánto tiene que crecer.
            Layout.preferredHeight: Math.min(lista.contentHeight, root.listaMax)
            visible: root.shell.history.length > 0
            clip: true
            spacing: Theme.gap
            model: root.groups

            delegate: ColumnLayout {
                id: grupo

                required property var modelData

                width: ListView.view.width
                spacing: 4

                // Cabecera del grupo: icono, nombre y cuántas hay. La cuenta sólo
                // aparece cuando hay más de una, porque "Signal 1" no dice nada.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    spacing: 6

                    IconImage {
                        Layout.preferredWidth: 13
                        Layout.preferredHeight: 13
                        visible: source != ""
                        source: grupo.modelData.icon ? Quickshell.iconPath(grupo.modelData.icon, true) : ""
                    }

                    Text {
                        text: grupo.modelData.app
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Text {
                        visible: grupo.modelData.items.length > 1
                        text: grupo.modelData.items.length
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: grupo.modelData.items

                    delegate: HistoryItem {
                        required property var modelData

                        Layout.fillWidth: true
                        shell: root.shell
                        panel: root
                        entry: modelData.entry
                        index: modelData.index
                    }
                }
            }
        }
    }
}
