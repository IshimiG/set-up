import QtQuick
import QtQuick.Layouts
import "shared"

// La lista de atajos de las tareas, delante de todo (la tecla ?). Un clic fuera
// de la lista, o Escape, la cierra. Las teclas son las de la web.
Rectangle {
    id: ayuda

    property bool visibleAyuda: false

    signal cerrar

    readonly property var teclas: [
        {
            tecla: "n",
            para: "Añadir una tarea"
        },
        {
            tecla: "/",
            para: "Filtrar"
        },
        {
            tecla: "j · k",
            para: "Siguiente · anterior"
        },
        {
            tecla: "Intro · o",
            para: "Abrir o cerrar el detalle"
        },
        {
            tecla: "x",
            para: "Marcar como hecha"
        },
        {
            tecla: "e",
            para: "Editar"
        },
        {
            tecla: "p",
            para: "Fijar en «Ahora»"
        },
        {
            tecla: "1 – 5",
            para: "Prioridad (1 máxima, 5 mínima)"
        },
        {
            tecla: "Esc",
            para: "Cerrar o salir"
        },
        {
            tecla: "?",
            para: "Esta ayuda"
        }
    ]

    // Se apaga con un fundido y un rebote suave, como lo demás.
    visible: opacity > 0.01
    opacity: ayuda.visibleAyuda ? 1 : 0
    color: Theme.glassBottom
    radius: Theme.radius

    Behavior on opacity {
        NumberAnimation {
            duration: ayuda.visibleAyuda ? Theme.animIn / 2 : Theme.animOut / 2
            easing.type: ayuda.visibleAyuda ? Easing.OutQuad : Easing.InOutQuint
        }
    }

    TapHandler {
        onTapped: ayuda.cerrar()
    }

    Rectangle {
        id: hoja

        objectName: "ayudaHoja"
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 330)
        height: lista.implicitHeight + 36
        radius: 14
        color: Theme.glassTop
        border.width: 1
        border.color: Theme.edgeTop
        scale: ayuda.visibleAyuda ? 1 : 0.94

        Behavior on scale {
            NumberAnimation {
                duration: ayuda.visibleAyuda ? Theme.animIn : Theme.animOut
                easing.type: ayuda.visibleAyuda ? Easing.OutBack : Easing.InOutQuint
                easing.overshoot: Theme.overshootIn
            }
        }

        // Pulsar dentro de la hoja no la cierra.
        TapHandler {
        }

        ColumnLayout {
            id: lista

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 8

            Text {
                text: "Atajos de las tareas"
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 14
            }

            Repeater {
                model: ayuda.teclas

                delegate: RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 78
                        implicitHeight: 22
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Theme.rule

                        Text {
                            anchors.centerIn: parent
                            text: modelData.tecla
                            color: Theme.strong
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.para
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Valen con el cajón abierto y después de un clic dentro; se ignoran mientras escribes en un campo."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }
}
