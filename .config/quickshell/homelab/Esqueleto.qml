pragma ComponentBehavior: Bound
import QtQuick
import "shared"

// El cuerpo esqueleto: tarjetas con borde redondeado y, dentro, un bloque
// cuadrado (avatar), una barra de título, una de subtítulo y dos de texto de
// distinta longitud, todo en bloques sólidos. Un brillo diagonal recorre las
// barras. Se enseña en lugar de un hueco mientras una sección carga
// (SeccionPerezosa.qml).
//
// Inspirado en Skeleton Loader de ASCII Magic (MIT):
// https://www.ascii-magic.com/ascii/skeleton-loader
//
// Una sola animación (`fase`) mueve el brillo de todas las barras, y sólo corre
// mientras el esqueleto se ve. Los colores salen de Theme.qml.
//
//   variante "filas":    cabecera y una lista de tarjetas a todo el ancho
//   variante "tarjetas": cabecera y una rejilla de tarjetas (2 columnas si caben)
Item {
    id: esqueleto

    property string variante: "filas"
    // Cuántas tarjetas se dibujan como máximo (el resto se recorta al alto).
    property int cantidad: 8

    // El brillo: 0 -> 1 y vuelta a empezar, compartido por todas las barras.
    property real fase: 0

    readonly property color base: Qt.rgba(1, 1, 1, 0.07)
    readonly property color brillo: Qt.rgba(1, 1, 1, 0.20)
    readonly property int hueco: Theme.gap + 2
    // Lo que avanza el brillo en x por cada px de y (la diagonal).
    readonly property real inclinacion: 0.6
    readonly property int banda: 90

    NumberAnimation on fase {
        running: esqueleto.visible
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: 1800
    }

    // Una barra sólida con el brillo encima. (cx, cy) es dónde está la tarjeta
    // en el cuerpo; (x, y), dónde está la barra en la tarjeta.
    component Barra: Rectangle {
        id: barra

        property real cx: 0
        property real cy: 0
        // El recorrido del brillo en la diagonal: del ancho del cuerpo más lo que
        // se inclina en el alto.
        readonly property real recorrido: cuerpo.width + cuerpo.height * esqueleto.inclinacion + esqueleto.banda
        // Dónde queda el centro del brillo, en coordenadas de la barra.
        readonly property real centro: esqueleto.fase * barra.recorrido - esqueleto.banda / 2 - (barra.cx + barra.x) - esqueleto.inclinacion * (barra.cy + barra.y)

        radius: 5
        color: esqueleto.base
        clip: true

        Rectangle {
            x: barra.centro - esqueleto.banda / 2
            width: esqueleto.banda
            height: barra.height
            visible: x < barra.width && x + width > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: esqueleto.brillo
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    // Una tarjeta del esqueleto, con sus cinco bloques.
    component Tarjeta: Rectangle {
        id: tarjeta

        // Dónde está en el cuerpo, para el brillo.
        property real cx: 0
        property real cy: 0
        property int n: 0

        implicitHeight: 88
        radius: Theme.gap + 4
        color: "transparent"
        border.width: 1
        border.color: Theme.rule

        Barra {
            x: 12
            y: 12
            width: 64
            height: 64
            radius: 10
            cx: tarjeta.cx
            cy: tarjeta.cy
        }
        Barra {
            x: 88
            y: 14
            width: Math.max(40, (tarjeta.width - 88 - 14) * (tarjeta.n % 2 === 0 ? 0.55 : 0.45))
            height: 12
            cx: tarjeta.cx
            cy: tarjeta.cy
        }
        Barra {
            x: 88
            y: 32
            width: Math.max(30, (tarjeta.width - 88 - 14) * 0.32)
            height: 9
            cx: tarjeta.cx
            cy: tarjeta.cy
        }
        Barra {
            x: 88
            y: 50
            width: Math.max(40, (tarjeta.width - 88 - 14) * 0.85)
            height: 8
            cx: tarjeta.cx
            cy: tarjeta.cy
        }
        Barra {
            x: 88
            y: 63
            width: Math.max(30, (tarjeta.width - 88 - 14) * (tarjeta.n % 3 === 0 ? 0.6 : 0.7))
            height: 8
            cx: tarjeta.cx
            cy: tarjeta.cy
        }
    }

    Item {
        id: cuerpo

        anchors.fill: parent
        anchors.margins: Theme.pad
        clip: true

        Barra {
            id: cabecera

            objectName: "esqueletoCabecera"
            width: Math.min(160, cuerpo.width * 0.5)
            height: 18
        }

        Column {
            id: filas

            objectName: "esqueletoFilas"
            visible: esqueleto.variante !== "tarjetas"
            y: cabecera.height + esqueleto.hueco
            width: parent.width
            spacing: esqueleto.hueco

            Repeater {
                model: esqueleto.variante !== "tarjetas" ? esqueleto.cantidad : 0

                Tarjeta {
                    required property int index

                    width: filas.width
                    n: index
                    cy: filas.y + index * (implicitHeight + esqueleto.hueco)
                }
            }
        }

        Flow {
            id: rejilla

            objectName: "esqueletoTarjetas"
            visible: esqueleto.variante === "tarjetas"
            y: cabecera.height + esqueleto.hueco
            width: parent.width
            spacing: esqueleto.hueco

            Repeater {
                model: esqueleto.variante === "tarjetas" ? esqueleto.cantidad : 0

                Tarjeta {
                    required property int index
                    readonly property bool dos: rejilla.width >= 420

                    width: dos ? (rejilla.width - esqueleto.hueco) / 2 : rejilla.width
                    n: index
                    cx: dos && index % 2 === 1 ? width + esqueleto.hueco : 0
                    cy: rejilla.y + (dos ? Math.floor(index / 2) : index) * (implicitHeight + esqueleto.hueco)
                }
            }
        }
    }
}
