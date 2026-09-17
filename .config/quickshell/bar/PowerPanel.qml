import QtQuick
import QtQuick.Layouts
import Quickshell
import "shared"

// El menú de sesión, ahora como contenido de la isla en vez de una superficie
// propia. Es el mismo menú de siempre: bloquear, suspender, cerrar sesión,
// reiniciar y apagar.
//
// Las tres acciones destructivas piden confirmación en un segundo menú cuya
// primera entrada —la preseleccionada— es "Cancelar", así que un Enter de más no
// apaga el equipo. La decisión va por índice y no por el texto, para que cambiar
// un glifo no rompa nada.
//
// Al pasar a la confirmación la lista baja de cinco filas a dos, y eso encoge la
// isla con la misma animación con la que se abrió: el panel no salta de tamaño,
// se reajusta.
Item {
    id: root

    required property var shell

    implicitWidth: 260
    implicitHeight: content.implicitHeight + Theme.pad * 2

    readonly property int rowH: 38

    readonly property var entries: [
        {
            icon: "󰌾",
            label: "Bloquear",
            cmd: "hyprlock",
            confirm: ""
        },
        {
            icon: "󰒲",
            label: "Suspender",
            // Bloquear antes de suspender, no después: si la pantalla se apaga
            // primero, hay una ventana en la que el escritorio queda visible al
            // despertar.
            cmd: "hyprlock & sleep 0.4; systemctl suspend",
            confirm: ""
        },
        {
            icon: "󰗽",
            label: "Cerrar sesión",
            cmd: "hyprctl dispatch exit",
            confirm: "Cerrar sesión"
        },
        {
            icon: "󰜉",
            label: "Reiniciar",
            cmd: "systemctl reboot",
            confirm: "Reiniciar"
        },
        {
            icon: "󰐥",
            label: "Apagar",
            cmd: "systemctl poweroff",
            confirm: "Apagar"
        }
    ]

    // -1 = menú normal. Cualquier otro valor es el índice de la entrada que
    // espera confirmación, y la lista pasa a ser Cancelar / acción.
    property int pending: -1

    readonly property var model: root.pending < 0 ? root.entries : [
        {
            icon: "󰅖",
            label: "Cancelar",
            cmd: "",
            confirm: ""
        },
        {
            icon: root.entries[root.pending].icon,
            label: root.entries[root.pending].confirm,
            cmd: root.entries[root.pending].cmd,
            confirm: ""
        }
    ]

    // Al cerrarse la isla el menú vuelve a su estado normal, para que la próxima
    // vez no se abra a medias en una confirmación de la vez anterior.
    Connections {
        target: root.shell
        function onModeChanged() {
            if (root.shell.mode !== "power") {
                root.pending = -1;
                list.currentIndex = 0;
            }
        }
    }

    function activate(i) {
        const entry = root.model[i];
        if (root.pending >= 0) {
            // Cancelar cierra el menú entero, igual que hacía el script de
            // fuzzel: al rechazar la confirmación, terminaba.
            if (i === 0)
                root.shell.close();
            else
                root.run(entry.cmd);
            return;
        }
        if (entry.confirm !== "") {
            root.pending = i;
            list.currentIndex = 0;
        } else {
            root.run(entry.cmd);
        }
    }

    // El comando se lanza cuando la isla ya ha terminado de cerrarse, no antes:
    // hyprlock levanta su propia superficie y, si se solapan, el panel se queda
    // un instante por encima del bloqueo.
    property string queued: ""

    function run(cmd) {
        root.queued = cmd;
        root.shell.close();
        launch.restart();
    }

    Timer {
        id: launch
        interval: 220
        onTriggered: {
            if (root.queued !== "")
                Quickshell.execDetached(["sh", "-c", root.queued]);
            root.queued = "";
        }
    }

    // Las teclas las ofrece la isla, que ya se ha quedado con Escape.
    function handleKey(event) {
        if (event.key === Qt.Key_Up) {
            if (list.currentIndex > 0)
                list.currentIndex--;
            return true;
        }
        if (event.key === Qt.Key_Down) {
            if (list.currentIndex < list.count - 1)
                list.currentIndex++;
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(list.currentIndex);
            return true;
        }
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            // Atajo directo por número, contando desde 1 arriba.
            const i = event.key - Qt.Key_1;
            if (i < root.model.length) {
                list.currentIndex = i;
                root.activate(i);
                return true;
            }
        }
        return false;
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.pending < 0 ? "󰐥" : "󰀦"
                color: root.pending < 0 ? Theme.accent : Theme.warn
                font.family: Theme.font
                font.pixelSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: root.pending < 0 ? "Sesión" : "¿Seguro?"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: list.count * root.rowH
            interactive: false
            model: root.model
            currentIndex: 0
            highlightMoveDuration: 140
            highlightResizeDuration: 0

            // La fila activa es otra lámina de cristal, una capa por encima:
            // tinte del acento más un filo blanco que la levanta de la
            // superficie en vez de limitarse a colorearla.
            highlight: Rectangle {
                radius: 10
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
            }

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                width: ListView.view.width
                height: root.rowH

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: row.modelData.icon
                        color: list.currentIndex === row.index ? Theme.strong : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 16
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        color: list.currentIndex === row.index ? Theme.strong : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }

                // El resalte sigue al ratón, de modo que lo que se ve
                // seleccionado y lo que ejecutaría un Enter son siempre lo
                // mismo, aunque se haya llegado hasta ahí con el teclado.
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            list.currentIndex = row.index;
                    }
                }

                TapHandler {
                    onTapped: {
                        list.currentIndex = row.index;
                        root.activate(row.index);
                    }
                }
            }
        }
    }
}
