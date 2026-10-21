import QtQuick
import "shared"

// Lo que se despliega y se pliega: la altura sigue a «abierto» con el rebote de
// la casa al abrir (OutBack) y la carrerilla al cerrar (InOutQuint). Solo
// anima cuando cambia «abierto»; si lo de dentro crece mientras está abierto
// (una subtarea nueva), la altura lo sigue sin rebotar.
Item {
    id: plegable

    property bool abierto: false
    default property alias contenido: columna.data
    // true mientras dura el movimiento de abrir o cerrar.
    property bool moviendo: false

    clip: true
    visible: height > 0.5
    height: plegable.abierto ? columna.implicitHeight : 0

    onAbiertoChanged: {
        plegable.moviendo = true;
        fin.restart();
    }

    Timer {
        id: fin
        interval: Theme.animIn + 60
        onTriggered: plegable.moviendo = false
    }

    Behavior on height {
        enabled: plegable.moviendo

        NumberAnimation {
            duration: plegable.abierto ? Theme.animIn : Theme.animOut
            easing.type: plegable.abierto ? Easing.OutBack : Easing.InOutQuint
            easing.overshoot: Theme.overshootIn
        }
    }

    Column {
        id: columna

        width: parent.width
    }
}
