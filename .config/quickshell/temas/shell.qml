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
                "etiqueta": "Cristal negro",
                "vidrio": Qt.rgba(0, 0, 0, 0.70),
                "canto": Qt.rgba(1, 1, 1, 0.30),
                "barra": Qt.rgba(1, 1, 1, 0.70),
                "radio": 6,
                "brillo": 0
            },
            "liquido": {
                "etiqueta": "Cristal claro",
                // El cuerpo, blanco al 0.2, ya mezclado con los dos colores
                // del fondo de la muestra: translúcido, el canto blanco de
                // debajo se vería a través y lo volvería lechoso.
                "vidrio": Qt.tint("#5a4a72", Qt.rgba(1, 1, 1, 0.2)),
                "vidrioIzq": Qt.tint("#3a4a7a", Qt.rgba(1, 1, 1, 0.2)),
                "vidrioDer": Qt.tint("#7a4a6a", Qt.rgba(1, 1, 1, 0.2)),
                "canto": Qt.rgba(1, 1, 1, 0.8),
                "barra": Qt.rgba(1, 1, 1, 1),
                "radio": 6,
                "brillo": 0.2
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
        radius: 20
        lectura: 1

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
                        radius: 12
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
                                    // Una muestra con el cuerpo ya mezclado con
                                    // el fondo lo da a los dos lados.
                                    gradient: fila.m.vidrioIzq ? vidrioMezclado : null

                                    Gradient {
                                        id: vidrioMezclado

                                        orientation: Gradient.Horizontal
                                        GradientStop {
                                            position: 0.0
                                            color: fila.m.vidrioIzq ?? fila.m.vidrio
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: fila.m.vidrioDer ?? fila.m.vidrio
                                        }
                                    }

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
                                        anchors.centerIn: parent
                                        width: parent.width * 0.6
                                        height: 3
                                        radius: 2
                                        color: fila.m.barra
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
                                text: fila.modelData
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
