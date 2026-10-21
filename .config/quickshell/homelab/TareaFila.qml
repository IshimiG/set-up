import QtQuick
import QtQuick.Layouts
import "shared"
import "TareasLogica.js" as Logica

// Una tarea en la lista: casilla, el cuadrado de su proyecto, la chincheta si
// está fijada en «Ahora», el texto, cuándo vence y un chevron. Un clic en la
// fila despliega sus detalles y subtareas (TareaDetalle). La barra de la
// izquierda lleva el color de la prioridad que tiene hoy.
//
// `t` es una entrada de TareasLogica.entradas() y `ctrl` es Tareas.qml, que
// guarda lo que sobrevive a repintar la lista (qué está abierto, cuál está
// elegida, cuál se edita).
Item {
    id: fila

    required property var t
    required property var ctrl
    property string ctx: "r"

    readonly property bool abierta: fila.ctrl.abiertos[fila.ctx + fila.t.linea] === true
    readonly property bool elegida: fila.ctrl.seleccion.ctx === fila.ctx && fila.ctrl.seleccion.linea === fila.t.linea
    readonly property bool editandome: fila.ctrl.edicion.ctx === fila.ctx && fila.ctrl.edicion.linea === fila.t.linea
    readonly property color tinte: fila.t.hecha ? Theme.faint : Theme.colorPrioridad(fila.t.pausa ? "pausa" : fila.t.efectiva)

    implicitHeight: marco.implicitHeight

    Rectangle {
        id: marco

        width: parent.width
        implicitHeight: pila.implicitHeight
        radius: 10
        color: fila.elegida ? Qt.rgba(1, 1, 1, 0.09) : (sobre.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        border.width: fila.elegida ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.22)
        opacity: fila.t.hecha || fila.t.pausa ? 0.6 : 1

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        HoverHandler {
            id: sobre
        }

        // La barra de la prioridad.
        Rectangle {
            x: 3
            y: 8
            width: 3
            height: 18
            radius: 1.5
            color: fila.tinte
            visible: !fila.editandome
        }

        Column {
            id: pila

            width: parent.width

            // La línea de la tarea: toda ella es el botón de desplegar, y la
            // casilla y el resto de lo que se pulsa están encima.
            Item {
                id: cabecera

                objectName: "filaTarea"
                width: parent.width
                height: 34
                visible: !fila.editandome

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        fila.ctrl.seleccionar(fila.ctx, fila.t.linea);
                        fila.ctrl.alternar(fila.ctx, fila.t.linea);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Casilla {
                        objectName: "casillaFila"
                        marcada: fila.t.hecha
                        tinte: fila.tinte
                        enabled: !fila.ctrl.api.tareasOcupado
                        onActivado: {
                            fila.ctrl.seleccionar(fila.ctx, fila.t.linea);
                            fila.ctrl.marcar(fila.t);
                        }
                    }

                    // El cuadrado del proyecto, o solo el borde si no tiene color.
                    Rectangle {
                        visible: fila.ctx === "r" && !fila.t.pausa
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 2
                        color: fila.t.seccionColor !== "" ? fila.t.seccionColor : "transparent"
                        border.width: fila.t.seccionColor !== "" ? 0 : 1
                        border.color: Theme.muted
                    }

                    Text {
                        visible: fila.t.fijada
                        text: ""
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    Text {
                        objectName: "textoFila"
                        Layout.fillWidth: true
                        text: fila.t.plano
                        color: fila.t.hecha ? Theme.muted : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.strikeout: fila.t.hecha
                        elide: Text.ElideRight
                    }

                    // Subtareas hechas, si tiene.
                    Text {
                        visible: fila.t.subtareas.length > 0
                        text: fila.t.subtareas.filter(x => x.hecha).length + "/" + fila.t.subtareas.length
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    Text {
                        visible: text !== ""
                        text: Logica.cuando(fila.t)
                        color: fila.t.hecha ? Theme.faint : (fila.t.dias !== null && fila.t.dias < 0 ? Theme.prioMaxima : (fila.t.dias === 0 ? Theme.warn : Theme.muted))
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    Text {
                        text: fila.abierta ? "" : ""
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9
                    }
                }
            }

            Plegable {
                width: parent.width
                abierto: fila.abierta && !fila.editandome

                TareaDetalle {
                    t: fila.t
                    ctrl: fila.ctrl
                    width: parent.width - 28
                    x: 14
                }
            }

            // El editor, con aire arriba y abajo.
            Item {
                width: 1
                height: 10
                visible: fila.editandome
            }

            Loader {
                width: parent.width - 20
                x: 10
                active: fila.editandome
                visible: active

                sourceComponent: TareaEditor {
                    t: fila.t
                    ctrl: fila.ctrl
                }
            }

            Item {
                width: 1
                height: 10
                visible: fila.editandome
            }
        }
    }
}
