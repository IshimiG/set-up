// Una petición del móvil que espera respuesta (aviso «confirmar_envio»): una
// tarjeta de cristal denso con «Enviar» y «No enviar». Contesta con
// api.responderAvisoMovil, que hace POST /api/avisos/movil/{id}/respuesta. Entra
// con rebote desde arriba y sale con carrerilla; un clic fuera la aparta (sigue
// pendiente en el NUC y vuelve al abrir el cajón otra vez).

import QtQuick
import QtQuick.Layouts
import "shared"

// Se coloca encima de lo que haya: el padre es quien la ancla (Tareas.qml la
// pone arriba del bloque; Contenido.qml podría ponerla en todo el cajón).
Item {
    id: aviso

    property var api: null
    // El primer aviso que pide confirmar y no se ha apartado.
    readonly property var pendientes: aviso.api && aviso.api.confirmaciones ? aviso.api.confirmaciones : []
    property var apartados: ({
    })
    readonly property var actual: aviso.pendientes.find((a) => {
        return !aviso.apartados[a.id];
    }) || null
    property bool enviando: false

    function apartar() {
        if (!aviso.actual)
            return ;

        const a = Object.assign({
        }, aviso.apartados);
        a[aviso.actual.id] = true;
        aviso.apartados = a;
    }

    function responder(envio) {
        if (!aviso.actual || aviso.enviando)
            return ;

        aviso.enviando = true;
        aviso.api.responderAvisoMovil(aviso.actual.id, envio, (ok) => {
            return aviso.enviando = false;
        });
    }

    implicitHeight: tarjeta.height
    // Un aviso nuevo se enseña aunque se hubiera apartado otro.
    onActualChanged: {
        if (aviso.actual) {
            aviso.enviando = false;
        }
    }

    // El velo: clic fuera aparta la tarjeta.
    Item {
        id: velo

        parent: aviso.parent
        anchors.fill: parent
        z: 69
        visible: aviso.actual !== null

        MouseArea {
            anchors.fill: parent
            onClicked: aviso.apartar()
        }

    }

    Rectangle {
        id: tarjeta

        objectName: "avisoMovil"
        parent: aviso.parent
        z: 70
        x: aviso.x
        y: aviso.y + (aviso.actual ? 0 : -height - 16)
        width: aviso.width
        height: cuerpo.implicitHeight + 28
        radius: 14
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.28)
        opacity: aviso.actual ? 1 : 0
        visible: opacity > 0.01

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: cuerpo

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: ""
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Text {
                    Layout.fillWidth: true
                    objectName: "tituloAvisoMovil"
                    text: aviso.actual && aviso.actual.titulo !== "" ? aviso.actual.titulo : "El móvil pide confirmar un envío"
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    visible: aviso.pendientes.length > 1
                    text: "+" + (aviso.pendientes.length - 1)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }

            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: aviso.actual ? aviso.actual.detalle : ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Chip {
                    objectName: "avisoEnviar"
                    Layout.fillWidth: true
                    texto: "Enviar"
                    glifo: ""
                    activo: true
                    encendido: !aviso.enviando
                    onActivado: aviso.responder(true)
                }

                Chip {
                    objectName: "avisoNoEnviar"
                    Layout.fillWidth: true
                    texto: "No enviar"
                    glifo: ""
                    encendido: !aviso.enviando
                    onActivado: aviso.responder(false)
                }

            }

        }

        Behavior on y {
            NumberAnimation {
                duration: aviso.actual ? Theme.animIn : Theme.animOut
                easing.type: aviso.actual ? Easing.OutBack : Easing.InBack
                easing.overshoot: aviso.actual ? Theme.overshootIn : Theme.overshootOut
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

}
