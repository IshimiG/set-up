import QtQuick
import QtQuick.Layouts
import "shared"
import "TareasLogica.js" as Logica

// Una tarjeta de «Ahora»: una de las tres tareas más urgentes (o las fijadas a
// mano), grande y con la cuenta atrás. Lo que importa de un vistazo es cuánto
// queda; la prioridad se lee en el punto y en la barra de la izquierda. Un
// clic despliega lo mismo que la fila (TareaDetalle).
Rectangle {
    id: tarjeta

    required property var t
    required property var ctrl
    property string ctx: "a"

    readonly property bool abierta: tarjeta.ctrl.abiertos[tarjeta.ctx + tarjeta.t.linea] === true
    readonly property bool elegida: tarjeta.ctrl.seleccion.ctx === tarjeta.ctx && tarjeta.ctrl.seleccion.linea === tarjeta.t.linea
    readonly property bool editandome: tarjeta.ctrl.edicion.ctx === tarjeta.ctx && tarjeta.ctrl.edicion.linea === tarjeta.t.linea
    readonly property color tinte: Theme.colorPrioridad(tarjeta.t.pausa ? "pausa" : tarjeta.t.efectiva)

    implicitHeight: pila.implicitHeight + 24
    radius: 12
    color: tarjeta.elegida ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    border.color: tarjeta.elegida ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    // La barra de la prioridad, a la izquierda, como en la web.
    Rectangle {
        x: 8
        y: 12
        width: 3
        height: parent.height - 24
        radius: 1.5
        color: tarjeta.tinte
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            tarjeta.ctrl.seleccionar(tarjeta.ctx, tarjeta.t.linea);
            tarjeta.ctrl.alternar(tarjeta.ctx, tarjeta.t.linea);
        }
    }

    Column {
        id: pila

        x: 22
        y: 12
        width: parent.width - 34
        spacing: 6

        // Lo de arriba: la prioridad y la casilla.
        Item {
            width: parent.width
            height: 22
            visible: !tarjeta.editandome

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    visible: tarjeta.t.fijada
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: tarjeta.tinte
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tarjeta.t.pausa ? "En pausa" : (tarjeta.t.efectiva ? Logica.NOMBRES[tarjeta.t.efectiva] : "Sin prioridad")
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            Casilla {
                objectName: "casillaTarjeta"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                lado: 22
                marcada: tarjeta.t.hecha
                tinte: tarjeta.tinte
                enabled: !tarjeta.ctrl.api.tareasOcupado
                onActivado: {
                    tarjeta.ctrl.seleccionar(tarjeta.ctx, tarjeta.t.linea);
                    tarjeta.ctrl.marcar(tarjeta.t);
                }
            }
        }

        Text {
            objectName: "textoTarjeta"
            width: parent.width
            visible: !tarjeta.editandome
            text: tarjeta.t.plano
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // Lo de abajo: la cuenta atrás y de qué es.
        Item {
            width: parent.width
            height: 30
            visible: !tarjeta.editandome

            Text {
                objectName: "cuentaAtras"
                anchors.verticalCenter: parent.verticalCenter
                text: Logica.cuentaAtras(tarjeta.t)
                color: tarjeta.t.dias !== null && tarjeta.t.dias < 0 ? Theme.prioMaxima : (tarjeta.t.dias === 0 ? Theme.warn : (tarjeta.t.dias === null ? Theme.muted : Theme.strong))
                font.family: Theme.font
                font.pixelSize: 17
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !tarjeta.t.pausa
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 2
                    color: tarjeta.t.seccionColor !== "" ? tarjeta.t.seccionColor : "transparent"
                    border.width: tarjeta.t.seccionColor !== "" ? 0 : 1
                    border.color: Theme.muted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const mismo = tarjeta.t.area.toLowerCase() === tarjeta.t.seccionTitulo.toLowerCase();
                        const lugar = tarjeta.t.seccionTitulo + (tarjeta.t.area && !mismo ? " · " + tarjeta.t.area : "");
                        return lugar + (tarjeta.t.vence ? " · " + Logica.fechaCorta(tarjeta.t.vence) : "");
                    }
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
        }

        Plegable {
            width: parent.width
            abierto: tarjeta.abierta && !tarjeta.editandome

            TareaDetalle {
                t: tarjeta.t
                ctrl: tarjeta.ctrl
                width: parent.width
            }
        }

        Loader {
            width: parent.width
            active: tarjeta.editandome
            visible: active

            sourceComponent: TareaEditor {
                t: tarjeta.t
                ctrl: tarjeta.ctrl
            }
        }
    }
}
