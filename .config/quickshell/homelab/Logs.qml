import QtQuick
import QtQuick.Layouts
import "shared"

// Los logs de un contenedor, delante de Servidor: las últimas 300 líneas y,
// después, las que van saliendo (api.logs). Con «Seguir», la lista baja sola
// con cada línea nueva; sin él, se queda donde se haya dejado. Las líneas van
// a un ListModel al que solo se le añade lo nuevo: si se le diera la lista
// entera cada vez, se perdería por dónde se iba leyendo.
Rectangle {
    id: logs

    required property var api
    readonly property var datos: logs.api ? logs.api.logs : null
    readonly property bool abierto: logs.datos !== null
    property bool seguir: true

    // Hasta dónde se ha copiado de api.logs (su «total») y de qué apertura.
    property int vez: -1
    property int copiadas: 0

    signal cerrar

    function sincronizar() {
        const l = logs.datos;
        if (!l) {
            modelo.clear();
            logs.vez = -1;
            logs.copiadas = 0;
            return;
        }
        if (l.vez !== logs.vez || l.total < logs.copiadas) {
            modelo.clear();
            logs.vez = l.vez;
            logs.copiadas = 0;
            logs.seguir = true;
        }
        const nuevas = Math.min(l.total - logs.copiadas, l.lineas.length);
        for (let i = l.lineas.length - nuevas; i < l.lineas.length; i++)
            modelo.append({
                hora: l.lineas[i].hora,
                texto: l.lineas[i].texto,
                nota: l.lineas[i].nota
            });
        logs.copiadas = l.total;
        const sobran = modelo.count - logs.api.maxLineasLog;
        if (sobran > 0)
            modelo.remove(0, sobran);
        if (logs.seguir && nuevas > 0)
            Qt.callLater(lista.positionViewAtEnd);
    }

    function textoEstado() {
        const l = logs.datos;
        if (!l)
            return "";
        switch (l.estado) {
        case "conectando":
            return "Leyendo el log…";
        case "fin":
            return "El log ha acabado: el contenedor se ha parado.";
        case "cortado":
            return l.error || "Se ha cortado la conexión.";
        default:
            return modelo.count + (modelo.count === 1 ? " línea" : " líneas") + ", en vivo";
        }
    }

    Connections {
        target: logs.api

        function onLogsChanged() {
            logs.sincronizar();
        }
    }

    Component.onCompleted: logs.sincronizar()

    ListModel {
        id: modelo
    }

    visible: opacity > 0.01
    opacity: logs.abierto ? 1 : 0
    radius: Theme.radius
    color: Theme.glassDense
    border.width: 1
    border.color: Theme.edgeTop

    Behavior on opacity {
        NumberAnimation {
            duration: logs.abierto ? Theme.animIn / 2 : Theme.animOut / 2
            easing.type: logs.abierto ? Easing.OutQuad : Easing.InOutQuint
        }
    }

    // Lo de debajo no recibe clics mientras esto está delante.
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                objectName: "tituloLogs"
                Layout.fillWidth: true
                text: "Logs · " + (logs.datos ? logs.datos.contenedor : "")
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Chip {
                objectName: "seguirLogs"
                texto: "Seguir"
                activo: logs.seguir
                onActivado: {
                    logs.seguir = !logs.seguir;
                    if (logs.seguir)
                        lista.positionViewAtEnd();
                }
            }

            Chip {
                objectName: "cerrarLogs"
                glifo: ""
                implicitWidth: 28
                onActivado: logs.cerrar()
            }
        }

        Text {
            objectName: "estadoLogs"
            Layout.fillWidth: true
            text: logs.textoEstado()
            color: logs.datos && logs.datos.estado === "cortado" ? Theme.warn : Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        ListView {
            id: lista

            objectName: "listaLogs"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: modelo
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2

            // Subir a mano deja de seguir; volver abajo del todo, vuelve.
            onMovementEnded: logs.seguir = lista.atYEnd

            delegate: Text {
                required property string hora
                required property string texto
                required property bool nota

                width: lista.width
                text: (hora !== "" ? hora + "  " : "") + texto
                color: nota ? Theme.faint : Theme.text
                font.family: Theme.font
                font.pixelSize: 10
                font.italic: nota
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
