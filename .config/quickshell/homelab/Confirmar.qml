import QtQuick
import QtQuick.Layouts
import "shared"

// La confirmación de una acción de Docker que el NUC marca con una palabra
// (decisión E10, como en la web): parar Caddy, bajar o actualizar un stack,
// todo lo de Immich. El botón no se enciende hasta que lo escrito es la
// palabra exacta. Escape, «Cancelar» o un clic fuera de la hoja la cierran
// sin hacer nada. La palabra la vuelve a comprobar el NUC.
FocusScope {
    id: confirmar

    property bool abierto: false
    property string titulo: ""
    property string texto: ""
    property string palabra: ""
    property string boton: ""
    property bool peligro: false
    // Lo que se confirma; quien abre lo pone y lo lee en «aceptado».
    property var pendiente: null

    readonly property bool vale: confirmar.palabra === "" || campo.texto === confirmar.palabra

    signal aceptado(string escrito)
    signal cancelado

    function abrir(o) {
        confirmar.titulo = o.titulo || "";
        confirmar.texto = o.texto || "";
        confirmar.palabra = o.palabra || "";
        confirmar.boton = o.boton || "Aceptar";
        confirmar.peligro = !!o.peligro;
        confirmar.pendiente = o.pendiente === undefined ? null : o.pendiente;
        campo.texto = "";
        confirmar.abierto = true;
        Qt.callLater(() => {
            if (confirmar.palabra !== "")
                campo.enfocar();
            else
                confirmar.forceActiveFocus();
        });
    }

    function cancelar() {
        if (!confirmar.abierto)
            return;
        confirmar.abierto = false;
        confirmar.cancelado();
    }

    function aceptar() {
        if (!confirmar.abierto || !confirmar.vale)
            return;
        const escrito = confirmar.palabra === "" ? "" : campo.texto;
        confirmar.abierto = false;
        confirmar.aceptado(escrito);
    }

    visible: opacity > 0.01
    opacity: confirmar.abierto ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: confirmar.abierto ? Theme.animIn / 2 : Theme.animOut / 2
            easing.type: confirmar.abierto ? Easing.OutQuad : Easing.InOutQuint
        }
    }

    Keys.onPressed: event => {
        if (!confirmar.abierto)
            return;
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            confirmar.cancelar();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            confirmar.aceptar();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.glassBottom

        TapHandler {
            onTapped: confirmar.cancelar()
        }
    }

    Rectangle {
        id: hoja

        objectName: "hojaConfirmar"
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 340)
        height: columna.implicitHeight + 36
        radius: 14
        color: Theme.glassDense
        border.width: 1
        border.color: confirmar.peligro ? Theme.prioMaxima : Theme.edgeTop
        scale: confirmar.abierto ? 1 : 0.94

        Behavior on scale {
            NumberAnimation {
                duration: confirmar.abierto ? Theme.animIn : Theme.animOut
                easing.type: confirmar.abierto ? Easing.OutBack : Easing.InOutQuint
                easing.overshoot: Theme.overshootIn
            }
        }

        // Pulsar dentro de la hoja no la cierra.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        ColumnLayout {
            id: columna

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 10

            Text {
                objectName: "tituloConfirmar"
                Layout.fillWidth: true
                text: confirmar.titulo
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Text {
                objectName: "textoConfirmar"
                Layout.fillWidth: true
                visible: text !== ""
                text: confirmar.texto
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: confirmar.palabra !== ""
                text: "Escribe «" + confirmar.palabra + "» para confirmar"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Campo {
                id: campo

                objectName: "campoConfirmar"
                Layout.fillWidth: true
                visible: confirmar.palabra !== ""
                pista: confirmar.palabra
                onAceptado: confirmar.aceptar()
                onCancelado: confirmar.cancelar()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }

                Chip {
                    objectName: "cancelarConfirmar"
                    texto: "Cancelar"
                    tamano: 12
                    implicitHeight: 30
                    onActivado: confirmar.cancelar()
                }

                Chip {
                    objectName: "aceptarConfirmar"
                    texto: confirmar.boton
                    tamano: 12
                    implicitHeight: 30
                    activo: true
                    conPunto: confirmar.peligro
                    punto: Theme.prioMaxima
                    encendido: confirmar.vale
                    onActivado: confirmar.aceptar()
                }
            }
        }
    }
}
