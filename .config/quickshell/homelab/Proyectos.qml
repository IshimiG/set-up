import QtQuick
import QtQuick.Layouts
import "shared"
import "ProyectosLogica.js" as Logica

// Los proyectos de las notas en el cajón, como Proyectos en la web: agrupados
// por estado, cada uno con su prioridad, su progreso, su primer siguiente paso,
// las PR e issues abiertas de su repo (de GitHub, a través del NUC) y sus
// subproyectos dentro. Un clic abre el proyecto (ProyectoDetalle), donde se
// editan el estado, la prioridad, el progreso y el siguiente paso, y se ven
// las PR e issues abiertas.
//
// Los proyectos llegan con Inicio (api.proyectos); GitHub, al entrar aquí, si
// lo que hay tiene más de un minuto.
FocusScope {
    id: proyectos

    required property var shell
    readonly property var api: proyectos.shell.api

    property string lineaConexion: ""

    signal abrirWeb
    signal abrirEnlace(string url)

    readonly property var lista: proyectos.api ? proyectos.api.proyectos : null
    readonly property var github: proyectos.api ? proyectos.api.github : null
    readonly property var grupos: Logica.grupos(proyectos.lista)
    // El proyecto abierto (su ruta), o "" para ver la lista.
    property string abierto: ""
    readonly property var elegido: proyectos.abierto !== "" ? Logica.buscar(proyectos.lista, proyectos.abierto) : null

    function abrir(ruta) {
        proyectos.abierto = ruta;
        sumidero.forceActiveFocus();
    }

    function volver() {
        proyectos.abierto = "";
        sumidero.forceActiveFocus();
    }

    // El resumen de GitHub de un repo, o null.
    function resumenRepo(repo) {
        const g = proyectos.github;
        return g && g.repos && repo ? g.repos[repo.toLowerCase()] || null : null;
    }

    function ponerAlDia() {
        if (proyectos.api && proyectos.visible && proyectos.shell.abierto)
            proyectos.api.cargarGithub();
    }

    onVisibleChanged: {
        proyectos.ponerAlDia();
        if (proyectos.visible)
            Qt.callLater(() => sumidero.forceActiveFocus());
    }

    Connections {
        target: proyectos.shell

        function onAbiertoChanged() {
            proyectos.ponerAlDia();
        }
    }

    // Escape, con un proyecto abierto, vuelve a la lista; si no, sube y
    // cierra el cajón. Un campo que se está escribiendo lo gasta él.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && proyectos.shell.abierto && proyectos.abierto !== "") {
            event.accepted = true;
            proyectos.volver();
        }
    }

    Item {
        id: sumidero
        focus: true
    }

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    // Las PR y las issues abiertas de un repo, en pequeño.
    component Insignias: Row {
        id: insignias

        property var resumen: null

        spacing: 8
        visible: insignias.resumen !== null && (insignias.resumen.prs > 0 || insignias.resumen.issues > 0)

        Text {
            visible: insignias.resumen !== null && insignias.resumen.prs > 0
            text: " " + (insignias.resumen ? insignias.resumen.prs : 0)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 10
        }

        Text {
            visible: insignias.resumen !== null && insignias.resumen.issues > 0
            text: " " + (insignias.resumen ? insignias.resumen.issues : 0)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 10
        }
    }

    // Un proyecto en la lista.
    component Tarjeta: Rectangle {
        id: tarjeta

        required property var p
        readonly property var subs: Logica.subsDe(proyectos.lista, tarjeta.p.ruta)
        readonly property var siguiente: tarjeta.p.siguiente.length ? Logica.plano(tarjeta.p.siguiente[0]) : ""

        implicitHeight: pila.implicitHeight + 20
        radius: 12
        color: sobreTarjeta.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Theme.rule

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        HoverHandler {
            id: sobreTarjeta
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: proyectos.abrir(tarjeta.p.ruta)
        }

        ColumnLayout {
            id: pila

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            anchors.leftMargin: 12
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // La prioridad, con los colores de la web; sin prioridad, solo
                // el aro.
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: tarjeta.p.prioridad !== "" ? Theme.colorPrioridad(tarjeta.p.prioridad) : "transparent"
                    border.width: tarjeta.p.prioridad !== "" ? 0 : 1
                    border.color: Theme.muted
                }

                Text {
                    Layout.fillWidth: true
                    text: tarjeta.p.titulo
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Insignias {
                    resumen: proyectos.resumenRepo(tarjeta.p.repo)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: tarjeta.p.progreso !== null
                spacing: 8

                Rectangle {
                    id: pista

                    Layout.fillWidth: true
                    implicitHeight: 3
                    radius: 1.5
                    color: Theme.rule

                    Rectangle {
                        width: pista.width * (tarjeta.p.progreso || 0) / 100
                        height: parent.height
                        radius: 1.5
                        color: Theme.text
                    }
                }

                Text {
                    text: tarjeta.p.progreso + " %"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            Text {
                Layout.fillWidth: true
                text: tarjeta.siguiente !== "" ? tarjeta.siguiente : "Sin siguiente paso anotado."
                color: tarjeta.siguiente !== "" ? Theme.text : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            // Los subproyectos: cada uno abre el suyo.
            Repeater {
                model: tarjeta.subs

                delegate: Rectangle {
                    id: sub

                    required property var modelData

                    objectName: "sub-" + sub.modelData.titulo
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 6
                    color: sobreSub.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                    HoverHandler {
                        id: sobreSub
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: proyectos.abrir(sub.modelData.ruta)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 6

                        Text {
                            text: "↳"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Text {
                            Layout.fillWidth: true
                            text: sub.modelData.titulo
                            color: sub.modelData.estado === "hecho" || sub.modelData.estado === "archivado" ? Theme.muted : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.strikeout: sub.modelData.estado === "hecho"
                            elide: Text.ElideRight
                        }

                        Text {
                            text: sub.modelData.estado + (sub.modelData.progreso !== null ? " · " + sub.modelData.progreso + " %" : "")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    // --- La interfaz ---

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            visible: proyectos.lineaConexion !== ""
            spacing: 8

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.muted
            }

            Text {
                objectName: "lineaConexionProyectos"
                Layout.fillWidth: true
                text: proyectos.lineaConexion
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Text {
            objectName: "proyectosSinDatos"
            Layout.fillWidth: true
            visible: proyectos.lista === null && proyectos.lineaConexion === ""
            text: "Cargando los proyectos…"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
        }

        // --- La lista ---
        Flickable {
            id: desplazable

            objectName: "desplazableProyectos"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: proyectos.lista !== null && proyectos.elegido === null
            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 8
                opacity: proyectos.lineaConexion === "" ? 1 : 0.5

                Text {
                    visible: proyectos.lista !== null && proyectos.lista.length === 0
                    text: "No hay proyectos en tus notas."
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Repeater {
                    model: proyectos.grupos

                    delegate: ColumnLayout {
                        id: grupo

                        required property var modelData

                        objectName: "grupoProyectos-" + grupo.modelData.clave
                        Layout.fillWidth: true
                        spacing: 6

                        Etiqueta {
                            Layout.topMargin: 4
                            text: grupo.modelData.titulo.toUpperCase() + " · " + grupo.modelData.proyectos.length
                        }

                        Repeater {
                            model: grupo.modelData.proyectos

                            delegate: Tarjeta {
                                required property var modelData

                                objectName: "proyecto-" + modelData.titulo
                                Layout.fillWidth: true
                                p: modelData
                            }
                        }
                    }
                }

                // Por qué no salen las PR e issues.
                Text {
                    objectName: "estadoGithub"
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        const g = proyectos.github;
                        if (!g)
                            return "";
                        if (!g.habilitado)
                            return "GitHub sin conectar: falta GITHUB_TOKEN en el NUC.";
                        return g.error;
                    }
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Item {
                    objectName: "proyectosEnLaWeb"
                    Layout.fillWidth: true
                    implicitHeight: textoWeb.implicitHeight + 6

                    Text {
                        id: textoWeb

                        y: 6
                        width: parent.width
                        text: "Los repos sin proyecto, fusionar, cerrar y comentar: en la web"
                        color: sobreWeb.hovered ? Theme.text : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.underline: sobreWeb.hovered
                        wrapMode: Text.WordWrap
                    }

                    HoverHandler {
                        id: sobreWeb
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: proyectos.abrirWeb()
                    }
                }
            }
        }

        // --- Un proyecto ---
        ProyectoDetalle {
            objectName: "detalleProyecto"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: proyectos.elegido !== null
            p: proyectos.elegido
            ctrl: proyectos
        }

        // Sin datos, que lo de arriba no se estire.
        Item {
            Layout.fillHeight: true
            visible: !desplazable.visible && proyectos.elegido === null
        }
    }
}
