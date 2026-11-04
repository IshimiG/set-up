import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// Selector de tema: SUPER+SHIFT+T. Una tarjeta pequeña centrada con los temas
// de Theme.temas, el activo marcado y una mini-vista previa de cada uno.
// ↑/↓ mueven, Enter o un clic aplican (~/.config/hypr/scripts/tema.sh <tema>)
// y cierran; Escape o un clic fuera, sólo cierran.
//
// La tarjeta es un Cristal del tema activo, así que cambia de aspecto con él:
// el panel mismo es la primera vista previa. Se lanza al abrirlo (como el
// recordatorio) y no arranca con la sesión.
PanelWindow {
    id: root

    WlrLayershell.namespace: "temas"
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

    // Superficie a pantalla completa (como el recordatorio): un clic fuera de
    // la tarjeta la cierra.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property int cardW: 340
    readonly property int pad: 18
    readonly property int filaH: 64

    // Las muestras de la vista previa. Theme sólo expone los valores del tema
    // ACTIVO, así que aquí van unas pocas fijas por tema, a mano: si cambian
    // los colores de un tema en shared/Theme.qml (cristal, canto, radio,
    // brillo), actualízalas aquí. Un tema que no esté en esta tabla sale con
    // la muestra de default. Se buscan por nombre, no por posición.
    readonly property var muestras: ({
            "default": {
                "nombre": "Default",
                "etiqueta": "Cristal negro",
                "vidrio": Qt.rgba(0, 0, 0, 0.70),
                "canto": Qt.rgba(1, 1, 1, 0.30),
                "barra": Qt.rgba(1, 1, 1, 0.70),
                "radio": 6,
                "brillo": 0,
                "puntos": ["#ffffff", "#6dc89e", "#e90b25"]
            },
            "liquido": {
                "nombre": "Líquido",
                "etiqueta": "Cristal claro",
                "vidrio": Qt.rgba(0.84, 0.89, 1, 0.38),
                "canto": Qt.rgba(1, 1, 1, 0.65),
                "barra": Qt.rgba(1, 1, 1, 1),
                "radio": 11,
                "brillo": 0.33,
                "puntos": ["#ffffff", "#30d158", "#ff453a"]
            },
            "catppuccin": {
                "nombre": "Catppuccin Mocha",
                "etiqueta": "Pastel redondeado",
                "vidrio": Qt.rgba(0.118, 0.118, 0.180, 0.80),
                "canto": "#cba6f7",
                "barra": "#cba6f7",
                "radio": 10,
                "brillo": 0.2,
                "puntos": ["#cba6f7", "#a6e3a1", "#f38ba8"]
            },
            "tokyonight": {
                "nombre": "Tokyo Night",
                "etiqueta": "Neón índigo",
                "vidrio": Qt.rgba(0.102, 0.106, 0.149, 0.78),
                "canto": "#7aa2f7",
                "barra": "#7aa2f7",
                "radio": 7,
                "brillo": 0,
                "puntos": ["#7aa2f7", "#bb9af7", "#7dcfff"]
            },
            "gruvbox": {
                "nombre": "Gruvbox Dark",
                "etiqueta": "Plano y retro",
                "vidrio": "#282828",
                "canto": "#fe8019",
                "barra": "#fe8019",
                "radio": 0,
                "brillo": 0,
                "puntos": ["#fabd2f", "#b8bb26", "#fb4934"]
            },
            "kanagawa": {
                "nombre": "Kanagawa Wave",
                "etiqueta": "Tinta sobria",
                "vidrio": Qt.rgba(0.122, 0.122, 0.157, 0.86),
                "canto": "#54546d",
                "barra": "#7e9cd8",
                "radio": 5,
                "brillo": 0,
                "puntos": ["#7e9cd8", "#98bb6c", "#e46876"]
            },
            "phosphor": {
                "nombre": "Phosphor",
                "etiqueta": "Fósforo verde",
                "vidrio": "#000000",
                "canto": "#00ff00",
                "barra": "#00ff00",
                "radio": 0,
                "brillo": 0,
                "puntos": ["#00ff00", "#00a600", "#006a00"]
            }
        })

    function muestra(nombre) {
        return root.muestras[nombre] ?? root.muestras["default"];
    }

    property bool shown: false
    property int sel: 0

    function elegir(i) {
        if (i < 0 || i >= Theme.temas.length)
            return;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/tema.sh", Theme.temas[i]]);
        root.closeWindow();
    }

    function closeWindow() {
        root.shown = false;
        quitTimer.start();
    }

    Component.onCompleted: {
        root.sel = Math.max(0, Theme.temas.indexOf(Theme.nombreTema));
        root.shown = true;
    }

    Timer {
        id: quitTimer
        // Lo justo para que termine de encogerse antes de que el proceso se vaya.
        interval: 340
        onTriggered: Qt.quit()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            const p = mapToItem(card, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height)
                root.closeWindow();
        }
    }

    Cristal {
        id: card

        anchors.centerIn: parent
        width: root.cardW
        height: content.implicitHeight + root.pad * 2
        radius: Theme.nombreTema === "default" ? 20 : Theme.radius

        // Mismo gesto de entrada y salida que el recordatorio y el lanzador.
        scale: root.shown ? 1 : 0.82
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? Theme.animIn : Theme.animOut
                easing.type: root.shown ? Easing.OutBack : Easing.InBack
                easing.overshoot: root.shown ? Theme.overshootIn : Theme.overshootOut
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 140 : Theme.animOut - 60
                easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
            }
        }

        FocusScope {
            id: content

            focus: true
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            implicitHeight: titulo.height + 12 + lista.height + 12 + pie.height

            Keys.onEscapePressed: root.closeWindow()
            Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
            Keys.onDownPressed: root.sel = Math.min(Theme.temas.length - 1, root.sel + 1)
            Keys.onReturnPressed: root.elegir(root.sel)
            Keys.onEnterPressed: root.elegir(root.sel)

            Text {
                id: titulo
                text: "Tema"
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            Column {
                id: lista

                anchors.top: titulo.bottom
                anchors.topMargin: 12
                width: parent.width
                spacing: 6

                Repeater {
                    model: Theme.temas

                    delegate: Rectangle {
                        id: fila

                        required property int index
                        required property string modelData
                        readonly property bool activo: modelData === Theme.nombreTema
                        readonly property bool marcada: root.sel === index
                        readonly property var m: root.muestra(modelData)

                        width: lista.width
                        height: root.filaH
                        radius: Theme.nombreTema === "default" ? 12 : Theme.radiusSmall
                        color: fila.marcada ? Qt.rgba(1, 1, 1, Theme.liquido ? 0.22 : 0.10) : (hover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        border.width: fila.activo ? 1 : 0
                        border.color: Theme.faint

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        // La vista previa: un fondo fijo (el mismo en todas, para
                        // que se comparen) con una mini lámina del cristal del tema.
                        Rectangle {
                            id: previa

                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 72
                            height: 44
                            radius: 8
                            clip: true
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: "#3a4a7a"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "#7a4a6a"
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 8
                                radius: fila.m.radio
                                color: fila.m.canto

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Math.max(0, fila.m.radio - 1)
                                    color: fila.m.vidrio

                                    Rectangle {
                                        visible: fila.m.brillo > 0
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: parent.height * fila.m.brillo
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0.0
                                                color: Qt.rgba(1, 1, 1, 0.35)
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: Qt.rgba(1, 1, 1, 0)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: parent.height * 0.32
                                        width: parent.width * 0.6
                                        height: 3
                                        radius: Math.min(2, fila.m.radio)
                                        color: fila.m.barra
                                    }

                                    // Los acentos del tema: activo, bien y peligro.
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: parent.height * 0.62
                                        spacing: 4

                                        Repeater {
                                            model: fila.m.puntos

                                            delegate: Rectangle {
                                                required property string modelData

                                                width: 5
                                                height: 5
                                                radius: fila.m.radio === 0 ? 0 : 3
                                                color: modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.left: previa.right
                            anchors.leftMargin: 14
                            anchors.right: marca.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: fila.m.nombre
                                color: fila.marcada ? Theme.strong : Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: fila.activo ? Font.Medium : Font.Normal
                            }
                            Text {
                                text: fila.m.etiqueta
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        // El tema activo lleva un visto.
                        Text {
                            id: marca

                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: fila.activo ? "󰄬" : ""
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 16
                        }

                        HoverHandler {
                            id: hover
                        }

                        TapHandler {
                            onTapped: {
                                root.sel = fila.index;
                                root.elegir(fila.index);
                            }
                        }
                    }
                }
            }

            Text {
                id: pie

                anchors.top: lista.bottom
                anchors.topMargin: 12
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: "↑↓ elegir · Enter aplicar · Esc cerrar"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }
}
