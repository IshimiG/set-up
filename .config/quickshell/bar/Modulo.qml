import QtQuick
import QtQuick.Layouts
import "shared"

// Un módulo de la barra: un glifo, opcionalmente una cifra al lado, y un globo
// al pasar por encima. Lo usan los módulos comunes de TelemetryBlock.qml y los
// de cada equipo (equipo/Equipo.qml en la rama de cada máquina), por eso vive
// en su propio fichero en vez de como componente en línea.
//
// El globo lo dibuja el bloque, no el módulo: así sólo hay uno y se coloca
// respecto a la pastilla entera en vez de pelearse por el sitio con los
// vecinos. Por eso cada módulo tiene que saber de qué bloque es.
Item {
    id: mod

    // El SideBlock que lo contiene. Los módulos de un equipo lo reciben del
    // hueco en el que van (ver TelemetryBlock.qml).
    required property Item bloque

    property string glifo: ""
    property string valor: ""
    property string pista: ""
    property color tinte: Theme.strong
    // Para lo que está apagado o silenciado: sigue ahí y sigue siendo
    // clicable, pero deja de pesar.
    property real atenuado: 1

    signal pulsado
    signal pulsadoDerecho
    signal pulsadoMedio
    signal rueda(int delta)

    visible: mod.glifo !== "" || mod.valor !== ""
    implicitWidth: visible ? linea.implicitWidth : 0
    // La altura de la pastilla. Fija y no la del padre: un módulo de un equipo
    // va dentro de una fila anidada, y atarlo a su altura sería un bucle.
    implicitHeight: 26
    opacity: mod.atenuado

    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    RowLayout {
        id: linea

        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: mod.glifo !== ""
            text: mod.glifo
            color: mod.tinte
            font.family: Theme.font
            font.pixelSize: 12

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }
        }

        Text {
            visible: mod.valor !== ""
            text: mod.valor
            color: mod.tinte
            font.family: Theme.font
            font.pixelSize: 12

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }
        }
    }

    HoverHandler {
        id: encima
        cursorShape: Qt.PointingHandCursor
    }

    Connections {
        target: encima
        function onHoveredChanged() {
            if (!mod.bloque)
                return;
            if (encima.hovered) {
                mod.bloque.pistaDe = mod;
                mod.bloque.pista = mod.pista;
            } else if (mod.bloque.pista === mod.pista) {
                mod.bloque.pista = "";
            }
        }
    }

    // Y si el dato cambia mientras el ratón sigue encima, el globo se
    // actualiza en vez de quedarse con la cifra de hace tres segundos.
    onPistaChanged: if (encima.hovered && mod.bloque)
        mod.bloque.pista = mod.pista

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: mod.pulsado()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: mod.pulsadoDerecho()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: mod.pulsadoMedio()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => mod.rueda(event.angleDelta.y)
    }
}
