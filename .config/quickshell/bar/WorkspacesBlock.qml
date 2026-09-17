import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "shared"

// Los escritorios, a la izquierda de la barra.
//
// Cada uno es un punto de su propio color, igual que en waybar. Los colores no
// son decorativos: son los mismos de siempre y sirven para reconocer el
// escritorio de un vistazo sin leer el número.
//
// Se conserva también lo que waybar llamaba "persistent-workspaces": del 1 al 3
// se ven siempre aunque estén vacíos, porque son los que se usan a diario y el
// bloque no debe cambiar de ancho cada vez que se cierra la última ventana.
SideBlock {
    id: root

    // "shell" lo declara SideBlock; volver a declararlo aquí lo ensombrecería.

    readonly property int minimos: 3

    readonly property var colores: ({
            "1": "#e90b25",
            "2": "#e59625",
            "3": "#ffd966",
            "4": "#deffa0",
            "5": "#6dc89e",
            "6": "#40e0d0",
            "7": "#00aef2",
            "8": "#bf3e81",
            "9": "#df6280",
            "10": "#ffe9ff"
        })

    // Los escritorios que hay que pintar: los que existen, más los persistentes
    // que falten, ordenados por número.
    readonly property var lista: {
        const vivos = {};
        const todos = Hyprland.workspaces.values;
        for (let i = 0; i < todos.length; i++) {
            const w = todos[i];
            // Los escritorios especiales (scratchpad) tienen id negativo y no
            // pintan nada en la barra.
            if (w.id > 0)
                vivos[w.id] = w;
        }

        const ids = [];
        for (let n = 1; n <= root.minimos; n++)
            ids.push(n);
        for (const clave in vivos) {
            const n = parseInt(clave);
            if (ids.indexOf(n) < 0)
                ids.push(n);
        }
        ids.sort((a, b) => a - b);

        return ids.map(n => ({
                    id: n,
                    ws: vivos[n] ?? null
                }));
    }

    Repeater {
        model: root.lista

        delegate: Item {
            id: punto

            required property var modelData

            readonly property var ws: punto.modelData.ws
            readonly property bool enfocado: punto.ws ? punto.ws.focused : false
            // Vacío es "existe pero no tiene ventanas", y también "ni siquiera
            // existe", que es el caso de los persistentes sin abrir.
            readonly property bool vacio: !punto.ws || punto.ws.toplevels.values.length === 0

            implicitWidth: 14
            implicitHeight: parent ? parent.height : 26

            Text {
                id: glifo

                anchors.centerIn: parent
                text: "󱓻"
                font.family: Theme.font
                font.pixelSize: 13

                // El enfocado va siempre en verde, por encima del color que le
                // toque por número: así el ojo lo encuentra sin tener que
                // recordar de qué color era el escritorio en el que está.
                color: punto.enfocado ? Theme.ok : (root.colores[punto.modelData.id] ?? "#ffffff")
                opacity: punto.vacio && !punto.enfocado ? 0.5 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                // Un saltito al recibir el foco, con el mismo rebote que usa
                // todo lo demás. Es lo que hace que cambiar de escritorio se
                // note en la barra y no sólo en la pantalla.
                scale: punto.enfocado ? 1.25 : (raton.hovered ? 1.15 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.6
                    }
                }
            }

            HoverHandler {
                id: raton
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    if (punto.ws)
                        punto.ws.activate();
                    else
                        // Un persistente que todavía no existe: se crea al ir a
                        // él, que es lo que hacía "on-click: activate".
                        Hyprland.dispatch("workspace " + punto.modelData.id);
                }
            }
        }
    }
}
