import QtQuick
import QtQuick.Layouts
import Quickshell
import "shared"

// Lo de dentro del cajón.
//
// La tira de secciones de la izquierda es la de la web (su menú plegado), y cada
// sección sin datos todavía dice en qué fase del plan llega. Los datos salen de
// Api.qml (shell.api), ya normalizados: aquí no se conoce el JSON de la API, sólo
// se pinta. Las reglas (la prioridad que sube con la fecha, qué se puede
// escribir) siguen en el NUC.
Item {
    id: contenido

    required property var shell
    // El cajón entero fuera y quieto. Los euros de Finanzas sólo se enseñan así
    // (decisión E11): con el cajón escondido o a medio sacar, nunca.
    property bool desplegado: false

    property string seccion: "inicio"

    // La API del panel (Api.qml, creada en shell.qml).
    readonly property var api: contenido.shell.api

    readonly property bool conectado: contenido.api ? contenido.api.conexion === "conectado" : false

    // El color del punto del asa: el nivel de las alertas sin ver. Sin conexión
    // no se sabe nada, y se apaga (el gris tenue de siempre, Theme.faint).
    readonly property color colorEstado: {
        switch (contenido.api ? contenido.api.nivelAlertas : "desconocido") {
        case "ok":
            return Theme.ok;
        case "warn":
            return Theme.warn;
        case "error":
            return Theme.danger;
        default:
            return Theme.faint;
        }
    }

    // «web» es la ruta de la misma sección en la web del panel.
    readonly property var secciones: [
        {
            id: "inicio",
            icono: "",
            nombre: "Inicio",
            fase: 2,
            web: "#/"
        },
        {
            id: "tareas",
            icono: "",
            nombre: "Tareas",
            fase: 3,
            web: "#/"
        },
        {
            id: "clase",
            icono: "",
            nombre: "Clase",
            fase: 3,
            web: "#/"
        },
        {
            id: "proyectos",
            icono: "",
            nombre: "Proyectos",
            fase: 4,
            web: "#/proyectos"
        },
        {
            id: "servidor",
            icono: "",
            nombre: "Servidor",
            fase: 4,
            web: "#/servidor"
        },
        {
            id: "revisiones",
            icono: "",
            nombre: "Revisiones",
            fase: 5,
            web: "#/revisiones"
        },
        {
            id: "finanzas",
            icono: "",
            nombre: "Finanzas",
            fase: 5,
            web: "#/finanzas"
        }
    ]

    readonly property var actual: contenido.secciones.find(s => s.id === contenido.seccion) || contenido.secciones[0]

    // Los colores de prioridad son los de la web (Theme.qml), para que una
    // tarea se vea igual en los dos sitios.
    function colorPrioridad(p) {
        switch (p) {
        case "maxima":
            return Theme.prioMaxima;
        case "alta":
            return Theme.prioAlta;
        case "media":
            return Theme.prioMedia;
        case "baja":
            return Theme.prioBaja;
        case "pausa":
            return Theme.prioPausa;
        default:
            return Theme.prioMinima;
        }
    }

    // La semana ISO, la misma que usan las revisiones del vault.
    function semana(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dia = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dia);
        const inicio = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - inicio) / 86400000 + 1) / 7);
    }

    // La fecha y la semana: las del NUC si vienen y, si no, las locales.
    function hoy() {
        const d = new Date();
        const ini = contenido.api ? contenido.api.inicio : null;
        const fecha = ini && ini.hoy ? ini.hoy : Qt.locale("es_ES").toString(d, "dddd d 'de' MMMM");
        let sem = ini && ini.semana ? String(ini.semana) : String(contenido.semana(d));
        if (sem.toLowerCase().indexOf("semana") < 0)
            sem = "semana " + sem;
        return fecha + " · " + sem;
    }

    // «hace 5 min», «hace 2 h», «hace 3 días».
    function hace(fecha) {
        if (!fecha)
            return "";
        const s = Math.max(0, (Date.now() - fecha.getTime()) / 1000);
        if (s < 60)
            return "hace un momento";
        if (s < 3600)
            return "hace " + Math.floor(s / 60) + " min";
        if (s < 86400)
            return "hace " + Math.floor(s / 3600) + " h";
        const d = Math.floor(s / 86400);
        return "hace " + d + (d === 1 ? " día" : " días");
    }

    function sinVer() {
        const l = contenido.api ? contenido.api.alertas : null;
        return l ? l.filter(a => !a.vista).length : 0;
    }

    // El servidor en una línea.
    function textoServidor() {
        const sv = contenido.api ? contenido.api.servidor : null;
        if (!sv)
            return "Servidor sin datos";
        let t = sv.problemas > 0 ? sv.enMarcha + " de " + sv.total + " en marcha · " + sv.problemas + : sv.enMarcha + " de " + sv.total + " contenedores en marcha";
        const n = contenido.sinVer();
        return t + " · " + (n === 0 ? "sin alertas" : (n === 1 ? "1 alerta sin ver" : n + " alertas sin ver"));
    }

    // La línea de cada estado de conexión que no es «conectado».
    function textoConexion() {
        switch (contenido.api ? contenido.api.conexion : "") {
        case "conectando":
            return "Conectando con el NUC…";
        case "sin-conexion":
            return "Sin conexión con el NUC";
        case "sin-credenciales":
            return "Falta la contraseña del panel en el llavero";
        case "no-autorizado":
            return "El NUC no acepta la contraseña de este equipo";
        default:
            return "";
        }
    }

    function detalleConexion() {
        switch (contenido.api ? contenido.api.conexion : "") {
        case "sin-conexion":
            return "Reintenta solo, cada vez con más espera.";
        case "sin-credenciales":
            return 'secret-tool store --label="Panel del homelab" servicio homelab-panel usuario <equipo>';
        default:
            return "";
        }
    }

    function estadoCabecera() {
        const c = contenido.api ? contenido.api.conexion : "";
        const u = contenido.api && contenido.api.usuario ? " · " + contenido.api.usuario : "";
        return (c || "sin API") + u;
    }

    // Lo que el cajón aún no tiene, en la web, que ya pide la contraseña en el
    // navegador.
    function abrirEnLaWeb() {
        Quickshell.execDetached(["xdg-open", contenido.api.urlWeb(contenido.actual.web)]);
        if (!contenido.shell.fijado)
            contenido.shell.abierto = false;
    }

    // --- Piezas -------------------------------------------------------------

    // Un botón de icono de la cabecera: el glifo atenuado y, al pasar el ratón,
    // la lámina blanca de siempre debajo.
    component Icono: Rectangle {
        id: icono

        property string glifo: ""
        property bool activo: false
        signal activado

        implicitWidth: 28
        implicitHeight: 28
        radius: 8
        color: icono.activo ? Qt.rgba(1, 1, 1, 0.14) : (sobreIcono.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        border.width: icono.activo ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.22)

        Text {
            anchors.centerIn: parent
            text: icono.glifo
            color: icono.activo || sobreIcono.hovered ? Theme.strong : Theme.muted
            font.family: Theme.font
            font.pixelSize: 13
        }

        HoverHandler {
            id: sobreIcono
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: icono.activado()
        }
    }

    // El título pequeño de cada bloque, en mayúsculas y atenuado.
    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // --- La tira de secciones ---
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 6

            Repeater {
                model: contenido.secciones

                delegate: Rectangle {
                    id: boton

                    required property var modelData
                    readonly property bool elegida: contenido.seccion === boton.modelData.id

                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 10
                    color: boton.elegida ? Qt.rgba(1, 1, 1, 0.14) : (sobreBoton.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                    border.width: boton.elegida ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.22)

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: boton.modelData.icono
                        color: boton.elegida ? Theme.strong : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    HoverHandler {
                        id: sobreBoton
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: contenido.seccion = boton.modelData.id
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.rule
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // --- La cabecera ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: contenido.actual.nombre
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    Text {
                        text: contenido.estadoCabecera()
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Icono {
                    glifo: ""
                    onActivado: contenido.abrirEnLaWeb()
                }

                Icono {
                    glifo: ""
                    activo: contenido.shell.fijado
                    onActivado: contenido.shell.fijado = !contenido.shell.fijado
                }

                Icono {
                    glifo: ""
                    onActivado: contenido.shell.abierto = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: contenido.seccion === "inicio" ? inicio : pronto
            }
        }
    }

    // --- Inicio ---
    Component {
        id: inicio

        Flickable {
            id: desplazable

            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 18

                // Con la conexión caída, una línea clara; lo que ya hubiera se
                // sigue viendo pero atenuado, para que se note que no está al día.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !contenido.conectado
                    spacing: 5

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Theme.muted
                        }

                        Text {
                            objectName: "lineaConexion"
                            Layout.fillWidth: true
                            text: contenido.textoConexion()
                            color: Theme.strong
                            font.family: Theme.font
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    Text {
                        objectName: "detalleConexion"
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: contenido.detalleConexion()
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                        wrapMode: Text.WrapAnywhere
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 18
                    opacity: contenido.conectado ? 1 : 0.4

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Etiqueta {
                            text: "DÓNDE ESTÁS"
                        }

                        Text {
                            text: contenido.hoy()
                            color: Theme.strong
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: contenido.colorEstado
                            }

                            Text {
                                objectName: "lineaServidor"
                                Layout.fillWidth: true
                                text: contenido.textoServidor()
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Sólo el porcentaje, como el mosaico de la web (F12), y
                        // nada si no hay meta.
                        RowLayout {
                            readonly property var meta: contenido.api && contenido.api.inicio ? contenido.api.inicio.metaPorcentaje : null

                            Layout.fillWidth: true
                            visible: meta !== null && meta !== undefined
                            spacing: 10

                            Text {
                                text: "Meta"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }

                            Rectangle {
                                id: barraMeta

                                Layout.fillWidth: true
                                implicitHeight: 4
                                radius: 2
                                color: Theme.rule

                                Rectangle {
                                    width: barraMeta.width * Math.max(0, Math.min(100, parent.parent.meta || 0)) / 100
                                    height: parent.height
                                    radius: 2
                                    color: Theme.text
                                }
                            }

                            Text {
                                text: parent.meta + " %"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }
                    }

                    // Las alertas abiertas, en vivo.
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: contenido.api && contenido.api.alertas && contenido.api.alertas.length > 0
                        spacing: 8

                        Etiqueta {
                            text: "ALERTAS"
                        }

                        Repeater {
                            model: contenido.api ? contenido.api.alertas : []

                            delegate: Rectangle {
                                id: fila

                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 12
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: Theme.rule
                                opacity: fila.modelData.vista ? 0.55 : 1

                                Rectangle {
                                    id: nivel

                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: parent.height - 22
                                    radius: 1.5
                                    color: fila.modelData.nivel === "error" ? Theme.danger : Theme.warn
                                }

                                ColumnLayout {
                                    anchors.left: nivel.right
                                    anchors.leftMargin: 10
                                    anchors.right: vista.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: fila.modelData.titulo
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (fila.modelData.nivel === "error" ? "error" : "aviso") + " · " + contenido.hace(fila.modelData.desde)
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    id: vista

                                    objectName: "botonVista"
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !fila.modelData.vista
                                    implicitWidth: 46
                                    implicitHeight: 24
                                    radius: 8
                                    color: sobreVista.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.22)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Vista"
                                        color: Theme.strong
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                    }

                                    HoverHandler {
                                        id: sobreVista
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: contenido.api.marcarVista(fila.modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: contenido.api && contenido.api.inicio
                        spacing: 8

                        Etiqueta {
                            text: "AHORA"
                        }

                        Text {
                            visible: contenido.api && contenido.api.inicio && contenido.api.inicio.tareas.length === 0
                            text: "Nada para hoy"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 12
                        }

                        Repeater {
                            model: contenido.api && contenido.api.inicio ? contenido.api.inicio.tareas : []

                            delegate: Rectangle {
                                id: tarjeta

                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 56
                                radius: 12
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: Theme.rule

                                // La barra de la prioridad, a la izquierda, como en la web.
                                Rectangle {
                                    id: barra

                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: parent.height - 22
                                    radius: 1.5
                                    color: contenido.colorPrioridad(tarjeta.modelData.prioridad)
                                }

                                ColumnLayout {
                                    anchors.left: barra.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        text: tarjeta.modelData.texto
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        spacing: 6

                                        // El cuadrado del proyecto, con su color, o sólo
                                        // el borde si no tiene (como en la web).
                                        Rectangle {
                                            implicitWidth: 8
                                            implicitHeight: 8
                                            radius: 2
                                            color: tarjeta.modelData.color || "transparent"
                                            border.width: tarjeta.modelData.color ? 0 : 1
                                            border.color: Theme.muted
                                        }

                                        Text {
                                            text: tarjeta.modelData.seccion
                                            color: Theme.muted
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                        }

                                        // Las vencidas, en el rojo de «máxima»: es lo que pide atención.
                                        Text {
                                            Layout.fillWidth: true
                                            text: "· " + tarjeta.modelData.cuando
                                            color: tarjeta.modelData.vencida ? Theme.prioMaxima : Theme.muted
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Lo que todavía no está ---
    Component {
        id: pronto

        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: contenido.actual.icono
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 28
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Llega en la fase " + contenido.actual.fase + " del plan"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Mientras tanto, en la web"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.underline: sobreWeb.hovered

                    HoverHandler {
                        id: sobreWeb
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: contenido.abrirEnLaWeb()
                    }
                }
            }
        }
    }
}
