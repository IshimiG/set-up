import QtQuick
import "shared"

// El asa para arrastrar una tarea: seis puntos a la izquierda de la fila. Solo
// el asa arrastra (el resto de la fila es del clic y del desplazamiento de la
// lista). Lo arrastrado es un fantasma que vive en Tareas.qml (ctrl), porque
// la lista recorta lo que se sale de ella; aquí solo se avisa de cuándo
// empieza, por dónde va y cuándo se suelta.
Item {
    id: asa

    required property var t
    required property var ctrl

    implicitWidth: 16
    implicitHeight: 24
    opacity: asa.ctrl.api.tareasOcupado ? 0.3 : (sobre.hovered || arrastre.active ? 0.9 : 0.4)

    Text {
        anchors.centerIn: parent
        text: "⋮⋮"
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 12
        font.bold: true
    }

    HoverHandler {
        id: sobre

        cursorShape: arrastre.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    DragHandler {
        id: arrastre

        target: null
        enabled: !asa.ctrl.api.tareasOcupado
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: {
            if (active)
                asa.ctrl.empezarArrastre(asa.t, centroid.scenePosition);
            else
                asa.ctrl.soltarArrastre();
        }
        onCentroidChanged: {
            if (active) {
                asa.ctrl.moverArrastre(centroid.scenePosition);
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 140
        }

    }

}
