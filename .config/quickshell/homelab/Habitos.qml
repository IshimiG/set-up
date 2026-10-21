import QtQuick
import QtQuick.Layouts
import "shared"

// Los hábitos de hoy, como los de la semana en la web: gym, leído y
// programado, que se marcan en ciclo (sin marcar, sí, no), y la energía de 1 a
// 10. Cada cambio se escribe en la nota de la semana del vault; los totales
// de la semana los calcula el NUC. Sale de api.habitos y se escribe con
// api.anotarHabito (que ya enseña el cambio al momento).
ColumnLayout {
    id: habitos

    required property var api
    readonly property var datos: habitos.api ? habitos.api.habitos : null
    readonly property var filas: [
        {
            campo: "gym",
            nombre: "Gym"
        },
        {
            campo: "lectura",
            nombre: "Leído"
        },
        {
            campo: "programar",
            nombre: "Programado"
        }
    ]

    visible: habitos.datos !== null && habitos.datos.habilitado
    spacing: 8

    // sin marcar → sí → no → sin marcar.
    function siguiente(v) {
        return v === null ? "si" : (v ? "no" : "");
    }

    Text {
        text: "HÁBITOS DE HOY"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    Text {
        Layout.fillWidth: true
        visible: habitos.datos !== null && habitos.datos.hoy === null
        text: "Hoy no está en la semana que se ha leído."
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 11
    }

    Repeater {
        model: habitos.datos && habitos.datos.hoy ? habitos.filas : []

        delegate: RowLayout {
            id: fila

            required property var modelData
            readonly property var valor: habitos.datos.hoy[fila.modelData.campo]

            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: fila.modelData.nombre
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
            }

            Text {
                text: habitos.datos.totales[fila.modelData.campo] + " semana"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
            }

            Rectangle {
                objectName: "habito-" + fila.modelData.campo
                // El valor que enseña, para quien lo mire (la prueba): "si", "no" o "".
                property string estado: fila.valor === null ? "" : (fila.valor ? "si" : "no")

                implicitWidth: 28
                implicitHeight: 28
                radius: 8
                color: fila.valor === true ? Qt.rgba(Theme.ok.r, Theme.ok.g, Theme.ok.b, 0.3) : (sobre.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                border.width: 1
                border.color: fila.valor === true ? Theme.ok : Theme.rule

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: fila.valor === true ? "" : (fila.valor === false ? "–" : "")
                    color: fila.valor === true ? Theme.strong : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                HoverHandler {
                    id: sobre
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: habitos.api.anotarHabito(fila.modelData.campo, habitos.siguiente(fila.valor))
                }
            }
        }
    }

    // La energía: del 1 al 10; pulsar la que está puesta la quita.
    ColumnLayout {
        Layout.fillWidth: true
        visible: habitos.datos !== null && habitos.datos.hoy !== null
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Energía"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
            }

            Text {
                text: (habitos.datos ? habitos.datos.totales.energia : "–") + " media"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: 10

                delegate: Rectangle {
                    id: nivel

                    required property int index
                    readonly property int numero: nivel.index + 1
                    readonly property bool puesta: habitos.datos && habitos.datos.hoy && habitos.datos.hoy.energia === nivel.numero

                    objectName: "energia-" + nivel.numero
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 7
                    color: nivel.puesta ? Qt.rgba(1, 1, 1, 0.22) : (sobreNivel.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: 1
                    border.color: nivel.puesta ? Qt.rgba(1, 1, 1, 0.5) : Theme.rule

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: nivel.numero
                        color: nivel.puesta ? Theme.strong : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    HoverHandler {
                        id: sobreNivel
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: habitos.api.anotarHabito("energia", nivel.puesta ? "" : String(nivel.numero))
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: habitos.datos !== null && habitos.datos.hoy !== null && !habitos.datos.existe
        text: "Esta semana aún no tiene nota: se crea desde la plantilla al marcar el primer día."
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }

    Text {
        Layout.fillWidth: true
        visible: habitos.datos !== null && habitos.datos.error !== ""
        text: habitos.datos ? habitos.datos.error : ""
        color: Theme.warn
        font.family: Theme.font
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }
}
