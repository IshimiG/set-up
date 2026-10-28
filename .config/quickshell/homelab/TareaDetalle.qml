// Lo que se despliega bajo una tarea: sus detalles (las líneas sangradas de la
// tarea en 00 Inicio.md, que se editan todas juntas), sus subtareas (con su
// casilla, editables una a una, con «añadir» y quitar) y los dos botones que
// no caben en la fila: editar y fijar en «Ahora».

import QtQuick
import QtQuick.Layouts
import "TareasLogica.js" as Logica
import "shared"

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
    // Cambiar la fecha, la prioridad o el proyecto sin arrastrar: cada botón
    // abre su fila de opciones, y elegir una escribe la tarea (la lista se
    // repinta con la respuesta y esto se vuelve a construir).
    property string panel: ""

    function guardarDetalles() {
        const lineas = campoDetalles.texto.split("\n").map((l) => {
            return l.trim();
        }).filter((l) => {
            return l !== "";
        });
        detalle.editandoDetalles = false;
        if (JSON.stringify(lineas) !== JSON.stringify(detalle.t.detalles))
            detalle.ctrl.guardar(detalle.t, {
            "detalles": lineas
        });

    }

    function guardarSubtareas(lista) {
        detalle.ctrl.guardar(detalle.t, {
            "subtareas": lista.map((x) => {
                return ({
                    "texto": x.texto,
                    "hecha": x.hecha
                });
            })
        });
    }

    function alternarPanel(nombre) {
        detalle.panel = detalle.panel === nombre ? "" : nombre;
    }

    function cambiar(cambio) {
        detalle.ctrl.cambiar(detalle.t, cambio);
    }

    onEditandoChanged: detalle.ctrl.editor(detalle.editando ? 1 : -1)
    Component.onDestruction: {
        if (detalle.editando)
            detalle.ctrl.editor(-1);

    }
    spacing: 8

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
            const n = detalle.t.subtareas.filter((x) => {
                return x.hecha;
            }).length;
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
                    onActivado: detalle.guardarSubtareas(detalle.t.subtareas.map((x, i) => {
                        return i === sub.index ? {
                            "texto": x.texto,
                            "hecha": !x.hecha
                        } : x;
                    }))
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
                            detalle.guardarSubtareas(detalle.t.subtareas.filter((x, i) => {
                            return i !== sub.index;
                        }));
                        else if (v !== sub.modelData.texto)
                            detalle.guardarSubtareas(detalle.t.subtareas.map((x, i) => {
                            return i === sub.index ? {
                                "texto": v,
                                "hecha": x.hecha
                            } : x;
                        }));
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
                        onTapped: detalle.guardarSubtareas(detalle.t.subtareas.filter((x, i) => {
                            return i !== sub.index;
                        }))
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
                    detalle.guardarSubtareas(detalle.t.subtareas.concat([{
                    "texto": v,
                    "hecha": false
                }]));

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

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Chip {
            objectName: "panelFecha"
            texto: detalle.t.vence ? Logica.fechaCorta(detalle.t.vence) : "Fecha"
            glifo: "\uf073"
            activo: detalle.panel === "fecha"
            onActivado: detalle.alternarPanel("fecha")
        }

        Chip {
            objectName: "panelPrioridad"
            texto: detalle.t.prioridad ? Logica.NOMBRES[detalle.t.prioridad] : "Prioridad"
            conPunto: true
            punto: Theme.colorPrioridad(detalle.t.prioridad)
            activo: detalle.panel === "prioridad"
            onActivado: detalle.alternarPanel("prioridad")
        }

        Chip {
            objectName: "panelProyecto"
            texto: detalle.t.seccionTitulo || "Proyecto"
            glifo: "\uf07b"
            activo: detalle.panel === "proyecto"
            onActivado: detalle.alternarPanel("proyecto")
        }

        Item {
            Layout.fillWidth: true
        }

    }

    Item {
        Layout.fillWidth: true
        implicitHeight: pleg.height
        visible: pleg.abierto || pleg.moviendo

        Plegable {
            id: pleg

            width: parent.width
            abierto: detalle.panel !== ""

            Flow {
                width: parent.width
                spacing: 6
                topPadding: 2
                bottomPadding: 2

                // La fecha: pasos de un día desde la que tiene (o hoy), atajos y quitarla.
                Repeater {
                    model: detalle.panel === "fecha" ? [["-1 d", -1], ["+1 d", 1], ["Hoy", 0], ["Mañana", 1], ["+1 sem", 7]] : []

                    delegate: Chip {
                        required property var modelData
                        required property int index

                        objectName: "fecha-" + index
                        texto: modelData[0]
                        onActivado: {
                            // Los dos primeros son pasos desde la fecha actual; el resto, desde hoy.
                            const base = index < 2 ? (detalle.t.vence || detalle.ctrl.hoy) : detalle.ctrl.hoy;
                            detalle.cambiar({
                                "fecha": Logica.fechaMasDias(base, modelData[1])
                            });
                        }
                    }

                }

                Chip {
                    visible: detalle.panel === "fecha"
                    objectName: "fecha-sin"
                    texto: "Sin fecha"
                    activo: !detalle.t.vence
                    onActivado: detalle.cambiar({
                        "fecha": ""
                    })
                }

                Repeater {
                    model: detalle.panel === "prioridad" ? Logica.NIVELES : []

                    delegate: Chip {
                        required property string modelData

                        objectName: "prio-" + modelData
                        texto: Logica.NOMBRES[modelData]
                        conPunto: true
                        punto: Theme.colorPrioridad(modelData)
                        activo: detalle.t.prioridad === modelData
                        onActivado: detalle.cambiar({
                            "prioridad": modelData
                        })
                    }

                }

                Chip {
                    visible: detalle.panel === "prioridad"
                    objectName: "prio-ninguna"
                    texto: "Sin prioridad"
                    activo: !detalle.t.prioridad
                    onActivado: detalle.cambiar({
                        "prioridad": ""
                    })
                }

                Repeater {
                    model: detalle.panel === "proyecto" ? detalle.ctrl.secciones : []

                    delegate: Chip {
                        required property var modelData

                        objectName: "proy-" + modelData.id
                        texto: modelData.titulo
                        conPunto: true
                        puntoRadio: 2
                        punto: modelData.pausa ? Theme.prioPausa : (modelData.color !== "" ? modelData.color : Theme.muted)
                        activo: detalle.t.seccionId === modelData.id
                        onActivado: detalle.cambiar({
                            "seccion": modelData.id
                        })
                    }

                }

            }

        }

    }

    // El interruptor «Claude no la hace»: fija claude_off en el NUC, y Claude
    // deja esa tarea en paz al repartir trabajo.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            id: interruptor

            objectName: "claudeOff"
            implicitWidth: 36
            implicitHeight: 20
            radius: 10
            color: detalle.t.claudeOff ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: detalle.t.claudeOff ? Qt.rgba(1, 1, 1, 0.5) : Theme.rule
            opacity: detalle.ctrl.api.tareasOcupado ? 0.5 : 1

            Rectangle {
                width: 14
                height: 14
                radius: 7
                y: 3
                x: detalle.t.claudeOff ? parent.width - width - 3 : 3
                color: detalle.t.claudeOff ? Theme.strong : Theme.muted

                Behavior on x {
                    NumberAnimation {
                        duration: detalle.t.claudeOff ? Theme.animIn : Theme.animOut
                        easing.type: detalle.t.claudeOff ? Easing.OutBack : Easing.InBack
                        easing.overshoot: Theme.overshootIn
                    }

                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: {
                    if (!detalle.ctrl.api.tareasOcupado)
                        detalle.ctrl.guardar(detalle.t, {
                            "claudeOff": !detalle.t.claudeOff
                        });

                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        Text {
            Layout.fillWidth: true
            text: "Claude no la hace"
            color: detalle.t.claudeOff ? Theme.strong : Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
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

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

}
