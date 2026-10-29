import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "shared"

// El abecedario ruso en una ventana de cristal, con el mismo aspecto que el
// lanzador. SUPER+Y la abre y la cierra por IPC (hyprland.lua). Clic en una
// letra: copia la minúscula; clic derecho: la mayúscula. Escape o clic fuera,
// cierran. El buscador filtra por letra, romanización o palabra de ejemplo.
PanelWindow {
    id: root

    // Mismo namespace que el layer_rule de ~/.config/hypr/hyprland.lua.
    WlrLayershell.namespace: "alfabeto"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Letra mayúscula, minúscula, nombre, sonido aproximado en español y una
    // palabra de ejemplo con el sonido. Los datos vienen de la nota del vault
    // «1. Alfabeto - Алфавит».
    readonly property var letras: [
        {u: "А", l: "а", nombre: "a", sonido: "a", ejemplo: "águila"},
        {u: "Б", l: "б", nombre: "be", sonido: "b", ejemplo: "beso"},
        {u: "В", l: "в", nombre: "ve", sonido: "v (como b labiodental)", ejemplo: "vaca"},
        {u: "Г", l: "г", nombre: "ge", sonido: "g", ejemplo: "gato"},
        {u: "Д", l: "д", nombre: "de", sonido: "d", ejemplo: "dado"},
        {u: "Е", l: "е", nombre: "ye", sonido: "ye", ejemplo: "yes"},
        {u: "Ё", l: "ё", nombre: "yo", sonido: "yo", ejemplo: "yoga"},
        {u: "Ж", l: "ж", nombre: "zhe", sonido: "zh, como la j francesa", ejemplo: "Jacques"},
        {u: "З", l: "з", nombre: "ze", sonido: "z (sonora, como s de mismo)", ejemplo: "zorro"},
        {u: "И", l: "и", nombre: "i", sonido: "i", ejemplo: "iglú"},
        {u: "Й", l: "й", nombre: "i breve", sonido: "i corta, y", ejemplo: "yoga"},
        {u: "К", l: "к", nombre: "ka", sonido: "k", ejemplo: "kilo"},
        {u: "Л", l: "л", nombre: "el", sonido: "l", ejemplo: "lápiz"},
        {u: "М", l: "м", nombre: "em", sonido: "m", ejemplo: "mano"},
        {u: "Н", l: "н", nombre: "en", sonido: "n", ejemplo: "nube"},
        {u: "О", l: "о", nombre: "o", sonido: "o", ejemplo: "oso"},
        {u: "П", l: "п", nombre: "pe", sonido: "p", ejemplo: "pan"},
        {u: "Р", l: "р", nombre: "er", sonido: "r suave o vibrante", ejemplo: "rosa"},
        {u: "С", l: "с", nombre: "es", sonido: "s", ejemplo: "sol"},
        {u: "Т", l: "т", nombre: "te", sonido: "t", ejemplo: "té"},
        {u: "У", l: "у", nombre: "u", sonido: "u", ejemplo: "uva"},
        {u: "Ф", l: "ф", nombre: "ef", sonido: "f", ejemplo: "foca"},
        {u: "Х", l: "х", nombre: "ja", sonido: "j fuerte, h aspirada", ejemplo: "jamón / Achtung"},
        {u: "Ц", l: "ц", nombre: "tse", sonido: "ts", ejemplo: "tsunami"},
        {u: "Ч", l: "ч", nombre: "che", sonido: "ch", ejemplo: "chico"},
        {u: "Ш", l: "ш", nombre: "sha", sonido: "sh", ejemplo: "champú"},
        {u: "Щ", l: "щ", nombre: "shcha", sonido: "shch, sh suave y larga", ejemplo: "sh alargada"},
        {u: "Ъ", l: "ъ", nombre: "signo duro", sonido: "no suena; separa sonidos", ejemplo: "separa"},
        {u: "Ы", l: "ы", nombre: "y", sonido: "i gutural, sin equivalente exacto", ejemplo: "-"},
        {u: "Ь", l: "ь", nombre: "signo blando", sonido: "no suena; suaviza la anterior", ejemplo: "suaviza"},
        {u: "Э", l: "э", nombre: "e", sonido: "e", ejemplo: "elefante"},
        {u: "Ю", l: "ю", nombre: "yu", sonido: "yu", ejemplo: "yogur"},
        {u: "Я", l: "я", nombre: "ya", sonido: "ya", ejemplo: "llama"}
    ]

    property string query: ""
    property string aviso: ""

    readonly property var filtradas: {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return root.letras;
        return root.letras.filter(x => x.u.toLowerCase().includes(q) || x.l.includes(q) || x.nombre.includes(q) || x.sonido.toLowerCase().includes(q) || x.ejemplo.toLowerCase().includes(q));
    }

    // "mapped" es que la superficie exista; "shown", que la tarjeta esté a la
    // vista. Quitar la superficie destruye todo al instante, así que al cerrar
    // se recoge primero la tarjeta y luego se quita (igual que el lanzador).
    property bool mapped: false
    property bool shown: false

    visible: root.mapped

    function openWindow() {
        if (root.shown)
            return;
        cierre.stop();
        input.text = "";
        root.aviso = "";
        root.mapped = true;
        arranque.restart();
    }

    function closeWindow() {
        if (!root.mapped)
            return;
        arranque.stop();
        root.shown = false;
        cierre.restart();
    }

    function toggleWindow() {
        if (root.shown)
            root.closeWindow();
        else
            root.openWindow();
    }

    function copiar(texto) {
        copiador.command = ["wl-copy", texto];
        copiador.running = true;
        root.aviso = "Copiada: " + texto;
    }

    // Deja que la superficie se pinte antes de empezar la animación.
    Timer {
        id: arranque
        interval: 60
        onTriggered: {
            root.shown = true;
            input.forceActiveFocus();
        }
    }

    Timer {
        id: cierre
        interval: 180
        onTriggered: root.mapped = false
    }

    Process {
        id: copiador
    }

    // SUPER+Y llama a toggle. Si el proceso no estaba vivo, hyprland.lua lo
    // arranca con ALFABETO_ABRIR=1 para que esa misma pulsación ya la abra.
    IpcHandler {
        target: "alfabeto"

        function toggle(): void {
            root.toggleWindow();
        }

        function open(): void {
            root.openWindow();
        }

        function close(): void {
            root.closeWindow();
        }
    }

    Component.onCompleted: if (Quickshell.env("ALFABETO_ABRIR") === "1")
        root.openWindow()

    readonly property int cardW: 760
    readonly property int pad: 20
    readonly property int cellW: 136
    readonly property int cellH: 104
    readonly property int cols: 5

    // Clic fuera de la tarjeta: cierra. Va antes que la tarjeta para quedar por
    // debajo; la comprobación geométrica evita cerrar al clicar dentro.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            const p = mapToItem(card, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height)
                root.closeWindow();
        }
    }

    // La capa exterior es sólo el canto con degradado; el cristal se dibuja
    // encima dejando 1px al aire (igual que el lanzador).
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardW
        height: content.implicitHeight + root.pad * 2
        radius: 24
        clip: true

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.94

        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 160 : 140
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? Theme.animIn : 180
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.6
            }
        }

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
            radius: card.radius - 1

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
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.pad
            width: root.cardW - root.pad * 2
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "›"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 22
                }

                TextField {
                    id: input
                    Layout.fillWidth: true
                    focus: true
                    placeholderText: "Buscar letra, sonido o ejemplo…"
                    placeholderTextColor: Theme.muted
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 17
                    padding: 0
                    background: Rectangle {
                        color: "transparent"
                    }

                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.closeWindow()
                }

                Text {
                    text: root.filtradas.length + " / " + root.letras.length
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.preferredHeight: root.cellH * 4
                clip: true
                cellWidth: width / root.cols
                cellHeight: root.cellH
                model: root.filtradas
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: celda
                    required property var modelData
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 14
                        color: Qt.rgba(1, 1, 1, ratonCelda.containsMouse ? 0.10 : 0.03)
                        border.width: 1
                        border.color: ratonCelda.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: celda.modelData.u + " " + celda.modelData.l
                                color: Theme.strong
                                font.family: Theme.font
                                font.pixelSize: 30
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: celda.modelData.nombre
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: celda.modelData.sonido
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: celda.modelData.ejemplo
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10
                                font.italic: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: ratonCelda
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => root.copiar(mouse.button === Qt.RightButton ? celda.modelData.u : celda.modelData.l)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.filtradas.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: "Ninguna letra coincide"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 14
            }

            Text {
                Layout.fillWidth: true
                text: root.aviso !== "" ? root.aviso : "Clic: copia la minúscula   ·   Clic derecho: la mayúscula   ·   Esc: cierra"
                color: root.aviso !== "" ? Theme.ok : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }
}
