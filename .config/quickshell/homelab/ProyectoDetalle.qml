import QtQuick
import QtQuick.Layouts
import "shared"
import "ProyectosLogica.js" as Logica
import "TareasLogica.js" as Tareas

// Un proyecto abierto: lo que se edita de su nota (estado, prioridad, progreso
// y siguiente paso, como el cajón de proyecto de la web), sus subproyectos y
// las PR e issues abiertas de su repo, solo para leer (cada una se abre en el
// navegador). Cada cambio es un POST /api/proyectos que contesta con el
// proyecto como queda (api.editarProyecto); si la nota cambió por otro lado,
// el NUC no escribe nada, el proyecto se recarga y sale un aviso.
Flickable {
    id: detalle

    // El proyecto (de api.proyectos), o null; ctrl es Proyectos.qml.
    property var p: null
    required property var ctrl
    readonly property var api: detalle.ctrl.api

    readonly property string ruta: detalle.p ? detalle.p.ruta : ""
    readonly property var padre: detalle.p && detalle.p.padre ? Logica.buscar(detalle.ctrl.lista, detalle.p.padre) : null
    readonly property var subs: detalle.p ? Logica.subsDe(detalle.ctrl.lista, detalle.p.ruta) : []
    readonly property var rep: detalle.p ? Logica.repoDe(detalle.ctrl.lista, detalle.p) : ({
            repo: "",
            heredado: ""
        })
    readonly property var resumen: detalle.ctrl.resumenRepo(detalle.rep.repo)
    readonly property var datosRepo: detalle.rep.repo !== "" && detalle.api ? detalle.api.repos[detalle.rep.repo.toLowerCase()] || null : null
    readonly property bool ocupado: detalle.api ? detalle.api.proyectosOcupado : false

    property string pestana: "pulls"
    property bool editandoSiguiente: false
    // El progreso que se acaba de soltar, hasta que el NUC conteste.
    property int progresoPendiente: -1

    function cargarRepo(fresco) {
        if (detalle.visible && detalle.rep.repo !== "" && detalle.api)
            detalle.api.cargarRepo(detalle.rep.repo, fresco);
    }

    onRutaChanged: {
        detalle.editandoSiguiente = false;
        detalle.pestana = "pulls";
        detalle.progresoPendiente = -1;
        detalle.contentY = 0;
        detalle.cargarRepo(false);
    }
    onVisibleChanged: detalle.cargarRepo(false)

    function guardar(cambios, alAcabar) {
        detalle.api.editarProyecto(detalle.ruta, cambios, alAcabar);
    }

    function empezarSiguiente() {
        campoSiguiente.texto = detalle.p.siguientePanel ? detalle.p.siguiente.join("\n") : "";
        detalle.editandoSiguiente = true;
        campoSiguiente.enfocar();
    }

    function guardarSiguiente() {
        detalle.guardar({
            siguiente: campoSiguiente.texto
        }, ok => {
            if (ok)
                detalle.editandoSiguiente = false;
        });
    }

    function cancelarSiguiente() {
        detalle.editandoSiguiente = false;
        detalle.ctrl.forceActiveFocus();
    }

    clip: true
    contentWidth: width
    contentHeight: columna.implicitHeight + 12
    boundsBehavior: Flickable.StopAtBounds

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    // El progreso, de 5 en 5: se arrastra o se pulsa, y se guarda al soltar.
    component Deslizador: Item {
        id: desl

        property var valor: null
        property int arrastre: -1
        property int pendiente: -1
        property bool encendido: true
        readonly property real mostrado: desl.arrastre >= 0 ? desl.arrastre : (desl.pendiente >= 0 ? desl.pendiente : (desl.valor === null ? 0 : desl.valor))

        signal soltado(int v)

        implicitHeight: 24
        opacity: desl.encendido ? 1 : 0.5

        function aValor(x) {
            return Math.max(0, Math.min(100, Math.round(x / Math.max(1, desl.width) * 20) * 5));
        }

        Rectangle {
            id: pistaDesl

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.rule

            Rectangle {
                width: pistaDesl.width * desl.mostrado / 100
                height: parent.height
                radius: 2
                color: Theme.text
            }
        }

        Rectangle {
            visible: desl.valor !== null || desl.arrastre >= 0 || desl.pendiente >= 0
            x: pistaDesl.width * desl.mostrado / 100 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            color: Theme.strong
        }

        MouseArea {
            anchors.fill: parent
            enabled: desl.encendido
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: m => desl.arrastre = desl.aValor(m.x)
            onPositionChanged: m => {
                if (pressed)
                    desl.arrastre = desl.aValor(m.x);
            }
            onReleased: {
                const v = desl.arrastre;
                desl.arrastre = -1;
                if (v >= 0)
                    desl.soltado(v);
            }
            onCanceled: desl.arrastre = -1
        }
    }

    ColumnLayout {
        id: columna

        width: detalle.width
        spacing: 9

        // Volver: a la lista o, en un subproyecto, a su proyecto.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Chip {
                objectName: "volverProyectos"
                texto: "  Proyectos"
                onActivado: detalle.ctrl.volver()
            }

            Chip {
                objectName: "irAlPadre"
                visible: detalle.padre !== null
                texto: detalle.padre ? "  " + detalle.padre.titulo : ""
                onActivado: detalle.ctrl.abrir(detalle.padre.ruta)
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Text {
            objectName: "tituloProyecto"
            Layout.fillWidth: true
            text: detalle.p ? detalle.p.titulo : ""
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            // Mientras se escribe en la nota, «guardando…»; lo que se cambie
            // entretanto va en cola (api.editarProyecto).
            text: detalle.p ? (detalle.p.tipo === "subproyecto" ? "Subproyecto · " : "") + detalle.p.ruta + (detalle.ocupado ? " · guardando…" : (detalle.p.actualizado ? " · actualizado " + detalle.p.actualizado : "")) : ""
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WrapAnywhere
        }

        // --- Lo que se edita de la nota ---
        Etiqueta {
            Layout.topMargin: 4
            text: "ESTADO"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Logica.ESTADOS

                delegate: Chip {
                    required property string modelData

                    objectName: "estado-" + modelData
                    texto: modelData
                    activo: detalle.p !== null && detalle.p.estado === modelData
                    // Aunque ya lo tenga: si va otro en cola, este se queda el
                    // último. Lo que ya está igual no llega al NUC.
                    onActivado: detalle.guardar({
                        estado: modelData
                    })
                }
            }
        }

        Etiqueta {
            text: "PRIORIDAD"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Logica.PRIORIDADES

                delegate: Chip {
                    required property string modelData

                    objectName: "prioridadProyecto-" + modelData
                    texto: modelData
                    conPunto: true
                    punto: Theme.colorPrioridad(modelData)
                    activo: detalle.p !== null && detalle.p.prioridad === modelData
                    onActivado: detalle.guardar({
                        prioridad: modelData
                    })
                }
            }

            Chip {
                objectName: "prioridadProyecto-ninguna"
                texto: "Sin prioridad"
                activo: detalle.p !== null && detalle.p.prioridad === ""
                onActivado: detalle.guardar({
                    prioridad: ""
                })
            }
        }

        Etiqueta {
            text: "PROGRESO"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Deslizador {
                id: deslizador

                objectName: "progresoProyecto"
                Layout.fillWidth: true
                valor: detalle.p ? detalle.p.progreso : null
                pendiente: detalle.progresoPendiente
                onSoltado: v => {
                    if (detalle.p.progreso === v && detalle.progresoPendiente < 0)
                        return;
                    detalle.progresoPendiente = v;
                    // Si mientras tanto se ha soltado en otro sitio (va en
                    // cola), se sigue enseñando ese.
                    detalle.guardar({
                        progreso: v
                    }, () => {
                        if (detalle.progresoPendiente === v)
                            detalle.progresoPendiente = -1;
                    });
                }
            }

            Text {
                objectName: "textoProgreso"
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignRight
                text: deslizador.arrastre >= 0 || detalle.progresoPendiente >= 0 ? Math.round(deslizador.mostrado) + " %" : (detalle.p && detalle.p.progreso !== null ? detalle.p.progreso + " %" : "sin anotar")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6

            Etiqueta {
                Layout.fillWidth: true
                text: "SIGUIENTE PASO"
            }

            Chip {
                objectName: "editarSiguiente"
                visible: !detalle.editandoSiguiente
                texto: "Editar"
                glifo: ""
                onActivado: detalle.empezarSiguiente()
            }
        }

        Repeater {
            model: detalle.p && !detalle.editandoSiguiente ? detalle.p.siguiente : []

            delegate: Text {
                required property string modelData

                Layout.fillWidth: true
                text: "•  " + Logica.plano(modelData)
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        Text {
            Layout.fillWidth: true
            visible: detalle.p !== null && !detalle.editandoSiguiente && detalle.p.siguiente.length === 0
            text: "Sin siguiente paso anotado."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11
        }

        Text {
            Layout.fillWidth: true
            visible: detalle.p !== null && !detalle.editandoSiguiente && !detalle.p.siguientePanel && detalle.p.siguiente.length > 0
            text: "Sale de la sección «Siguiente paso» de la nota."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Campo {
            id: campoSiguiente

            objectName: "campoSiguiente"
            Layout.fillWidth: true
            visible: detalle.editandoSiguiente
            multilinea: true
            tamano: 11
            pista: detalle.p && !detalle.p.siguientePanel && detalle.p.siguiente.length ? Logica.plano(detalle.p.siguiente[0]) : "Un paso por línea; Ctrl+Intro guarda"
            onAceptado: detalle.guardarSiguiente()
            onCancelado: detalle.cancelarSiguiente()
        }

        Text {
            Layout.fillWidth: true
            visible: detalle.editandoSiguiente
            text: "Un paso por línea, hasta 5. Va al principio de «Siguiente paso» de la nota; lo que ya hay debajo no se toca."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            visible: detalle.editandoSiguiente
            spacing: 6

            Item {
                Layout.fillWidth: true
            }

            Chip {
                objectName: "cancelarSiguiente"
                texto: "Cancelar"
                onActivado: detalle.cancelarSiguiente()
            }

            Chip {
                objectName: "guardarSiguiente"
                texto: "Guardar en la nota"
                activo: true
                onActivado: detalle.guardarSiguiente()
            }
        }

        // --- Los subproyectos ---
        Etiqueta {
            Layout.topMargin: 4
            visible: detalle.subs.length > 0
            text: "SUBPROYECTOS · " + detalle.subs.length
        }

        Repeater {
            model: detalle.subs

            delegate: Rectangle {
                id: sub

                required property var modelData

                objectName: "subDetalle-" + sub.modelData.titulo
                Layout.fillWidth: true
                implicitHeight: lineasSub.implicitHeight + 12
                radius: 8
                color: sobreSub.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)

                HoverHandler {
                    id: sobreSub
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: detalle.ctrl.abrir(sub.modelData.ruta)
                }

                ColumnLayout {
                    id: lineasSub

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: sub.modelData.titulo
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            text: sub.modelData.estado + (sub.modelData.progreso !== null ? " · " + sub.modelData.progreso + " %" : "")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: sub.modelData.siguiente.length > 0 && sub.modelData.estado !== "hecho" && sub.modelData.estado !== "archivado"
                        text: sub.modelData.siguiente.length ? Logica.plano(sub.modelData.siguiente[0]) : ""
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // --- GitHub, solo leer ---
        Etiqueta {
            Layout.topMargin: 4
            text: "GITHUB"
        }

        Text {
            objectName: "repoProyecto"
            Layout.fillWidth: true
            text: detalle.rep.repo === "" ? "Sin repositorio enlazado (se enlaza en la web, o con «repo:» en la nota)." : detalle.rep.repo + (detalle.rep.heredado ? " · el de " + detalle.rep.heredado : "")
            color: detalle.rep.repo === "" ? Theme.faint : Theme.text
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: detalle.rep.repo !== "" && detalle.ctrl.github !== null && !detalle.ctrl.github.habilitado
            text: "GitHub sin conectar: falta GITHUB_TOKEN en el NUC."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: detalle.rep.repo !== "" && (detalle.ctrl.github === null || detalle.ctrl.github.habilitado)
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Chip {
                    objectName: "pestana-pulls"
                    texto: "PR" + (detalle.datosRepo && detalle.datosRepo.cuando ? " (" + detalle.datosRepo.pulls.length + ")" : (detalle.resumen ? " (" + detalle.resumen.prs + ")" : ""))
                    activo: detalle.pestana === "pulls"
                    onActivado: detalle.pestana = "pulls"
                }

                Chip {
                    objectName: "pestana-issues"
                    texto: "Issues" + (detalle.datosRepo && detalle.datosRepo.cuando ? " (" + detalle.datosRepo.issues.length + ")" : (detalle.resumen ? " (" + detalle.resumen.issues + ")" : ""))
                    activo: detalle.pestana === "issues"
                    onActivado: detalle.pestana = "issues"
                }

                Item {
                    Layout.fillWidth: true
                }

                Chip {
                    objectName: "releerRepo"
                    glifo: ""
                    implicitWidth: 28
                    encendido: !(detalle.datosRepo && detalle.datosRepo.cargando)
                    onActivado: detalle.cargarRepo(true)
                }

                Chip {
                    objectName: "abrirGithub"
                    texto: "GitHub"
                    glifo: ""
                    onActivado: detalle.ctrl.abrirEnlace(detalle.datosRepo && detalle.datosRepo.url ? detalle.datosRepo.url : (detalle.resumen && detalle.resumen.url ? detalle.resumen.url : "https://github.com/" + detalle.rep.repo))
                }
            }

            Text {
                Layout.fillWidth: true
                visible: detalle.datosRepo === null || (detalle.datosRepo.cargando && !detalle.datosRepo.cuando)
                text: "Leyendo GitHub…"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
            }

            Text {
                objectName: "errorRepo"
                Layout.fillWidth: true
                visible: detalle.datosRepo !== null && detalle.datosRepo.error !== ""
                text: detalle.datosRepo ? detalle.datosRepo.error : ""
                color: Theme.warn
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Text {
                objectName: "repoVacio"
                Layout.fillWidth: true
                readonly property var items: detalle.datosRepo ? (detalle.pestana === "pulls" ? detalle.datosRepo.pulls : detalle.datosRepo.issues) : []
                visible: detalle.datosRepo !== null && detalle.datosRepo.cuando !== null && detalle.datosRepo.error === "" && items.length === 0
                text: detalle.pestana === "pulls" ? "No hay pull requests abiertas." : "No hay issues abiertas."
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }

            Repeater {
                model: detalle.datosRepo ? (detalle.pestana === "pulls" ? detalle.datosRepo.pulls : detalle.datosRepo.issues) : []

                delegate: Rectangle {
                    id: item

                    required property var modelData
                    readonly property var it: item.modelData

                    objectName: "github-" + item.it.numero
                    Layout.fillWidth: true
                    implicitHeight: lineasItem.implicitHeight + 12
                    radius: 8
                    color: sobreItem.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)

                    HoverHandler {
                        id: sobreItem
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: if (item.it.url !== "")
                            detalle.ctrl.abrirEnlace(item.it.url)
                    }

                    ColumnLayout {
                        id: lineasItem

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "#" + item.it.numero + "  " + item.it.titulo
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: [item.it.borrador ? "borrador" : "", item.it.ramas, item.it.autor, Tareas.hace(item.it.actualizada), item.it.comentarios ? item.it.comentarios + " coment." : "", item.it.etiquetas.join(", ")].filter(x => x !== "").join(" · ")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
