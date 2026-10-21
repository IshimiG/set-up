import QtQuick
import QtQuick.Layouts
import "shared"
import "TareasLogica.js" as Logica

// Lo que se despliega bajo una tarea: sus detalles (las líneas sangradas de la
// tarea en 00 Inicio.md, que se editan todas juntas), sus subtareas (con su
// casilla, editables una a una, con «añadir» y quitar) y los dos botones que
// no caben en la fila: editar y fijar en «Ahora».
//
// Cada cambio es una escritura sobre la tarea entera (ctrl.guardar), que
// contesta con la lista nueva; la lista se repinta y esto se vuelve a
// construir, así que aquí no hay que arreglar nada a mano al acabar.
ColumnLayout {
    id: detalle

    required property var t
    required property var ctrl

    // Qué se está editando, para avisar a Tareas: mientras haya algo abierto,
    // un cambio que llegue de fuera no repinta la lista (api.editandoTarea).
    property bool editandoDetalles: false
    property int editandoSub: -1
    property bool anadiendoSub: false
    readonly property bool editando: detalle.editandoDetalles || detalle.editandoSub >= 0 || detalle.anadiendoSub

    onEditandoChanged: detalle.ctrl.editor(detalle.editando ? 1 : -1)
    Component.onDestruction: if (detalle.editando)
        detalle.ctrl.editor(-1)

    spacing: 8

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    function guardarDetalles() {
        const lineas = campoDetalles.texto.split("\n").map(l => l.trim()).filter(l => l !== "");
        detalle.editandoDetalles = false;
        if (JSON.stringify(lineas) !== JSON.stringify(detalle.t.detalles))
            detalle.ctrl.guardar(detalle.t, {
                detalles: lineas
            });
    }

    function guardarSubtareas(lista) {
        detalle.ctrl.guardar(detalle.t, {
            subtareas: lista.map(x => ({
                        texto: x.texto,
                        hecha: x.hecha
                    }))
        });
    }

    Item {
        implicitHeight: 4
    }

    Etiqueta {
        text: "DETALLES"
    }

    // Verlos, o escribirlos.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: detalle.editandoDetalles ? [] : detalle.t.detalles

            delegate: Text {
                required property string modelData

                Layout.fillWidth: true
                text: Logica.detalleHtml(modelData)
                textFormat: Text.StyledText
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        Text {
            objectName: "detallesVacio"
            Layout.fillWidth: true
            visible: !detalle.editandoDetalles && detalle.t.detalles.length === 0
            text: "Sin detalles"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11
        }

        Campo {
            id: campoDetalles

            objectName: "campoDetalles"
            Layout.fillWidth: true
            visible: detalle.editandoDetalles
            multilinea: true
            pista: "Una línea por detalle; Ctrl+Intro guarda"
            tamano: 11
            onAceptado: detalle.guardarDetalles()
            onCancelado: detalle.editandoDetalles = false
        }

        Chip {
            objectName: "editarDetalles"
            visible: !detalle.editandoDetalles
            texto: detalle.t.detalles.length ? "Editar detalles" : "Escribir detalles"
            glifo: ""
            onActivado: {
                campoDetalles.texto = detalle.t.detalles.join("\n");
                detalle.editandoDetalles = true;
                campoDetalles.enfocar();
            }
        }
    }

    Etiqueta {
        text: {
            const n = detalle.t.subtareas.filter(x => x.hecha).length;
            return "SUBTAREAS" + (detalle.t.subtareas.length ? " · " + n + "/" + detalle.t.subtareas.length : "");
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5

        Repeater {
            model: detalle.t.subtareas

            delegate: RowLayout {
                id: sub

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: 8

                Casilla {
                    objectName: "casillaSub"
                    lado: 15
                    marcada: sub.modelData.hecha
                    onActivado: detalle.guardarSubtareas(detalle.t.subtareas.map((x, i) => i === sub.index ? {
                                texto: x.texto,
                                hecha: !x.hecha
                            } : x))
                }

                // El texto de la subtarea; un clic lo edita. El clic lo recoge el
                // item de alrededor: un TapHandler dentro de un Text no recibe.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: textoSub.implicitHeight
                    visible: detalle.editandoSub !== sub.index

                    Text {
                        id: textoSub

                        objectName: "textoSub"
                        width: parent.width
                        text: sub.modelData.texto
                        color: sub.modelData.hecha ? Theme.muted : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.strikeout: sub.modelData.hecha
                        wrapMode: Text.WordWrap
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            campoSub.texto = sub.modelData.texto;
                            detalle.editandoSub = sub.index;
                            campoSub.enfocar();
                        }
                    }
                }

                Campo {
                    id: campoSub

                    objectName: "campoSub"
                    Layout.fillWidth: true
                    visible: detalle.editandoSub === sub.index
                    tamano: 11
                    onAceptado: {
                        const v = campoSub.texto.trim();
                        detalle.editandoSub = -1;
                        // Vacía, se quita; igual que estaba, no se escribe nada.
                        if (v === "")
                            detalle.guardarSubtareas(detalle.t.subtareas.filter((x, i) => i !== sub.index));
                        else if (v !== sub.modelData.texto)
                            detalle.guardarSubtareas(detalle.t.subtareas.map((x, i) => i === sub.index ? {
                                        texto: v,
                                        hecha: x.hecha
                                    } : x));
                    }
                    onCancelado: detalle.editandoSub = -1
                }

                Item {
                    objectName: "quitarSub"
                    implicitWidth: 18
                    implicitHeight: 18

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: quitarSobre.hovered ? Theme.strong : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    HoverHandler {
                        id: quitarSobre
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: detalle.guardarSubtareas(detalle.t.subtareas.filter((x, i) => i !== sub.index))
                    }
                }
            }
        }

        Campo {
            id: campoNueva

            objectName: "campoSubNueva"
            Layout.fillWidth: true
            visible: detalle.anadiendoSub
            tamano: 11
            pista: "Nueva subtarea"
            onAceptado: {
                const v = campoNueva.texto.trim();
                detalle.anadiendoSub = false;
                campoNueva.texto = "";
                if (v !== "")
                    detalle.guardarSubtareas(detalle.t.subtareas.concat([
                        {
                            texto: v,
                            hecha: false
                        }
                    ]));
            }
            onCancelado: {
                detalle.anadiendoSub = false;
                campoNueva.texto = "";
            }
        }

        Chip {
            objectName: "anadirSub"
            visible: !detalle.anadiendoSub
            texto: "Añadir subtarea"
            glifo: ""
            onActivado: {
                detalle.anadiendoSub = true;
                campoNueva.enfocar();
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Chip {
            objectName: "editarTarea"
            texto: "Editar"
            glifo: ""
            onActivado: detalle.ctrl.empezarEdicion(detalle.t)
        }

        Chip {
            objectName: "fijarTarea"
            texto: detalle.t.fijada ? "Quitar de «Ahora»" : "Fijar en «Ahora»"
            glifo: ""
            activo: detalle.t.fijada
            onActivado: detalle.ctrl.fijar(detalle.t)
        }

        Item {
            Layout.fillWidth: true
        }
    }

    // La línea de abajo: lo que no se ve en la fila.
    Text {
        Layout.fillWidth: true
        objectName: "pieDetalle"
        text: Logica.pieDetalle(detalle.t)
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }

    Item {
        implicitHeight: 4
    }
}
