import QtQuick
import Quickshell
import "shared"

// Prueba de shared/Cristal.qml: pinta una lámina sobre un gris medio con el
// tema que diga el fichero de estado ($XDG_STATE_HOME de prueba), imprime cómo
// la ha pintado y guarda la captura en $PRUEBA_PNG. La lanza prueba.sh, al
// lado, una vez con el renderizador por software (el de offscreen, sin
// shaders: tiene que salir el respaldo plano) y otra con OpenGL, si la máquina
// lo tiene (tiene que salir el shader del vidrio); prueba.sh mira los píxeles.
//
// La lámina mide 260×120 con radio 16, en (20, 20), sobre una ventana de
// 300×160 rellena de #808080.
FloatingWindow {
    implicitWidth: 300
    implicitHeight: 160
    color: "#808080"

    Item {
        id: escena

        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#808080"
        }

        Cristal {
            id: lamina

            x: 20
            y: 20
            width: 260
            height: 120
            radius: 16
        }
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            console.log("tema=" + Theme.nombreTema + " api=" + escena.GraphicsInfo.api + " vidrio=" + lamina.conVidrio + " shader=" + lamina.conShader);
            escena.grabToImage(r => {
                r.saveToFile(Quickshell.env("PRUEBA_PNG"));
                console.log("guardada");
                Qt.quit();
            });
        }
    }
}
