import QtQuick
import QtQuick.Layouts
import "shared"
import "ServidorLogica.js" as Logica

// El servidor en el cajón, como la vista Servidor de la web: el consumo del
// NUC arriba y, debajo, cada stack con sus contenedores, en vivo (api.stacks,
// que llega por los eventos). Cada contenedor lleva los botones que tienen
// sentido en su estado (los mismos de la web) y sus logs; cada stack, levantar
// y parar todo y, en «⋯», actualizar las imágenes y bajarlo.
//
// Las acciones son las de E10: las que el NUC permite, con su confirmación
// (escribir el nombre) cuando la pide. Quien no tiene acciones de Docker (el
// usuario movil) lo ve todo pero sin botones: api.stacks ya llega sin acciones.
// Cómo acaba cada una llega después, por el evento «result», y sale como aviso
// abajo; mientras tanto, el contenedor dice en qué paso va.
//
// El consumo (/api/stats) solo se lee mientras esto se ve con el cajón
// abierto: api.verConsumo.
FocusScope {
    id: servidor

    required property var shell
    readonly property var api: servidor.shell.api

    // La línea de conexión de Contenido, si no está «conectado».
    property string lineaConexion: ""

    readonly property var stacks: servidor.api ? servidor.api.stacks : []
    readonly property var consumo: servidor.api ? servidor.api.consumo : null
    readonly property bool soloVer: servidor.api !== null && servidor.api.permisos !== null && !servidor.api.puedeDocker

    // Las acciones que esperan el 202 del NUC: { "contenedor:caddy": true }.
    property var enviando: ({})
    // El stack con el menú «⋯» abierto.
    property string menuDe: ""

    readonly property bool mirando: servidor.visible && servidor.shell.abierto

    onMirandoChanged: if (servidor.api)
        servidor.api.verConsumo = servidor.mirando
    Component.onCompleted: if (servidor.api)
        servidor.api.verConsumo = servidor.mirando
    Component.onDestruction: if (servidor.api)
        servidor.api.verConsumo = false

    // Lo de dentro se cierra al irse: los logs no se quedan leyendo.
    onVisibleChanged: {
        if (servidor.visible) {
            Qt.callLater(() => sumidero.forceActiveFocus());
            return;
        }
        servidor.menuDe = "";
        confirmar.cancelar();
        if (servidor.api && servidor.api.logs)
            servidor.api.cerrarLogs();
    }

    function marcar(clave, v) {
        const e = Object.assign({}, servidor.enviando);
        if (v)
            e[clave] = true;
        else
            delete e[clave];
        servidor.enviando = e;
    }

    // Un botón de acción: con palabra, primero la confirmación.
    function pedir(tipo, nombre, accion) {
        servidor.menuDe = "";
        const palabra = Logica.palabra(servidor.stacks, tipo, nombre, accion);
        if (palabra === "") {
            servidor.lanzar(tipo, nombre, accion, "");
            return;
        }
        confirmar.abrir({
            titulo: Logica.ETIQUETAS[accion] + " · " + nombre,
            texto: Logica.explicar(servidor.stacks, tipo, nombre, accion),
            palabra: palabra,
            boton: Logica.ETIQUETAS[accion],
            peligro: true,
            pendiente: {
                tipo: tipo,
                nombre: nombre,
                accion: accion
            }
        });
    }

    function lanzar(tipo, nombre, accion, escrito) {
        const clave = tipo + ":" + nombre;
        servidor.marcar(clave, true);
        servidor.api.accionDocker(tipo, nombre, accion, escrito, () => servidor.marcar(clave, false));
    }

    // Escape cierra lo que haya delante (los logs, el menú); si no hay nada,
    // sube hasta Borde.qml y cierra el cajón. La confirmación lo gasta ella.
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape || !servidor.shell.abierto)
            return;
        if (confirmar.abierto) {
            confirmar.cancelar();
            event.accepted = true;
        } else if (servidor.api && servidor.api.logs) {
            servidor.api.cerrarLogs();
            event.accepted = true;
        } else if (servidor.menuDe !== "") {
            servidor.menuDe = "";
            event.accepted = true;
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

    // El color del punto de un contenedor (ServidorLogica.vista).
    function colorPunto(punto) {
        switch (punto) {
        case "ok":
            return Theme.ok;
        case "aviso":
            return Theme.warn;
        case "mal":
            return Theme.danger;
        case "ocupado":
            return Theme.strong;
        default:
            return Theme.faint;
        }
    }

    // Un medidor del consumo: etiqueta, valor, una línea de más y la barra.
    component Medidor: ColumnLayout {
        id: medidor

        property string etiqueta: ""
        property string valor: ""
        property string sub: ""
        property real fraccion: 0
        property string nivel: Logica.nivelUso(medidor.fraccion)

        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: medidor.etiqueta
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                text: medidor.valor
                color: medidor.nivel === "mal" ? Theme.danger : (medidor.nivel === "aviso" ? Theme.warn : Theme.strong)
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        Rectangle {
            id: pista

            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Theme.rule

            Rectangle {
                width: pista.width * Math.max(0, Math.min(1, medidor.fraccion))
                height: parent.height
                radius: 2
                color: medidor.nivel === "mal" ? Theme.danger : (medidor.nivel === "aviso" ? Theme.warn : Theme.text)

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: medidor.sub
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9
            elide: Text.ElideRight
        }
    }

    // --- La interfaz ---

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            visible: servidor.lineaConexion !== ""
            spacing: 8

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.muted
            }

            Text {
                objectName: "lineaConexionServidor"
                Layout.fillWidth: true
                text: servidor.lineaConexion
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Text {
            objectName: "soloVer"
            Layout.fillWidth: true
            visible: servidor.soloVer
            text: "Solo para ver: con el usuario " + (servidor.api ? servidor.api.usuario : "") + " no hay acciones de Docker."
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Text {
            objectName: "errorDocker"
            Layout.fillWidth: true
            visible: servidor.api !== null && servidor.api.dockerError !== ""
            text: servidor.api ? "Sin datos nuevos de Docker: " + servidor.api.dockerError : ""
            color: Theme.warn
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Flickable {
            id: desplazable

            objectName: "desplazableServidor"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 14
                // Con la conexión caída, atenuado: no está al día.
                opacity: servidor.lineaConexion === "" ? 1 : 0.5

                // --- El consumo ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Etiqueta {
                        text: "CONSUMO"
                    }

                    Text {
                        objectName: "consumoEsperando"
                        visible: servidor.consumo === null
                        text: servidor.lineaConexion === "" ? "Midiendo…" : "Sin datos"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    GridLayout {
                        objectName: "medidores"
                        Layout.fillWidth: true
                        visible: servidor.consumo !== null
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 8

                        Medidor {
                            objectName: "medidorCpu"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            etiqueta: "CPU"
                            valor: servidor.consumo ? Logica.pct(servidor.consumo.host.cpu) : ""
                            fraccion: servidor.consumo ? servidor.consumo.host.cpu / 100 : 0
                            sub: servidor.consumo ? "carga " + servidor.consumo.host.carga.toFixed(2).replace(".", ",") : ""
                        }

                        Medidor {
                            objectName: "medidorRam"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            readonly property var h: servidor.consumo ? servidor.consumo.host : null
                            etiqueta: "RAM"
                            valor: h ? Logica.bytes(h.memUsada) : ""
                            fraccion: h && h.memTotal ? h.memUsada / h.memTotal : 0
                            sub: h && h.memTotal ? Logica.pct(h.memUsada / h.memTotal * 100) + " de " + Logica.bytes(h.memTotal) : ""
                        }

                        Repeater {
                            model: servidor.consumo ? servidor.consumo.host.discos : []

                            delegate: Medidor {
                                required property var modelData

                                objectName: "medidorDisco"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                etiqueta: modelData.ruta
                                valor: modelData.montado ? Logica.bytes(modelData.usado) : "sin montar"
                                fraccion: modelData.montado && modelData.total ? modelData.usado / modelData.total : 0
                                nivel: modelData.montado ? Logica.nivelUso(fraccion) : "aviso"
                                sub: modelData.montado ? (modelData.total ? Logica.pct(modelData.usado / modelData.total * 100) + " de " + Logica.bytes(modelData.total) : "") : "el disco no está montado"
                            }
                        }
                    }
                }

                Text {
                    objectName: "servidorSinDatos"
                    Layout.fillWidth: true
                    visible: servidor.stacks.length === 0
                    text: servidor.lineaConexion === "" ? "Esperando el estado de Docker…" : "Sin datos de Docker."
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                // --- Los stacks ---
                Repeater {
                    model: servidor.stacks

                    delegate: ColumnLayout {
                        id: bloque

                        required property var modelData
                        readonly property var st: bloque.modelData
                        readonly property var botones: Logica.botonesStack(bloque.st)
                        readonly property var menu: Logica.menuStack(bloque.st)
                        readonly property bool enviandoStack: servidor.enviando["stack:" + bloque.st.nombre] === true

                        objectName: "stack-" + bloque.st.nombre
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: bloque.st.nombre !== "" ? bloque.st.nombre : "sin stack"
                                color: Theme.strong
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.italic: bloque.st.nombre === ""
                            }

                            Text {
                                visible: bloque.st.protegido || !bloque.st.gestionado
                                text: bloque.st.protegido ? " protegido" : "solo lectura"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 9
                            }

                            Text {
                                text: Logica.enMarcha(bloque.st) + "/" + bloque.st.contenedores.length + (bloque.st.ocupado ? " · " + bloque.st.ocupado + "…" : "")
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: bloque.botones

                                delegate: Chip {
                                    required property var modelData

                                    objectName: "accionStack-" + bloque.st.nombre + "-" + modelData.accion
                                    texto: modelData.etiqueta
                                    tamano: 10
                                    implicitHeight: 22
                                    activo: modelData.principal
                                    conPunto: modelData.peligro
                                    punto: Theme.prioMaxima
                                    encendido: !bloque.enviandoStack
                                    onActivado: servidor.pedir("stack", bloque.st.nombre, modelData.accion)
                                }
                            }

                            Chip {
                                objectName: "menuStack-" + bloque.st.nombre
                                visible: bloque.st.gestionado && bloque.menu.length > 0
                                glifo: ""
                                tamano: 10
                                implicitHeight: 22
                                implicitWidth: 26
                                activo: servidor.menuDe === bloque.st.nombre
                                onActivado: servidor.menuDe = servidor.menuDe === bloque.st.nombre ? "" : bloque.st.nombre
                            }
                        }

                        // El menú «⋯»: lo que no se pulsa a diario. Se despliega
                        // como Plegable, pero dentro de un layout manda la
                        // altura implícita, así que es la que se anima.
                        Item {
                            id: menuCaja

                            // Los sueltos se llaman "", como el menú cerrado.
                            readonly property bool abierto: bloque.st.gestionado && servidor.menuDe === bloque.st.nombre

                            Layout.fillWidth: true
                            implicitHeight: menuCaja.abierto ? flujo.implicitHeight : 0
                            clip: true
                            visible: menuCaja.implicitHeight > 0.5

                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: menuCaja.abierto ? Theme.animIn : Theme.animOut
                                    easing.type: menuCaja.abierto ? Easing.OutBack : Easing.InOutQuint
                                    easing.overshoot: Theme.overshootIn
                                }
                            }

                            Flow {
                                id: flujo

                                width: parent.width
                                spacing: 6
                                topPadding: 2
                                bottomPadding: 4
                                layoutDirection: Qt.RightToLeft

                                Repeater {
                                    model: bloque.menu

                                    delegate: Chip {
                                        required property var modelData

                                        objectName: "accionStack-" + bloque.st.nombre + "-" + modelData.accion
                                        texto: modelData.etiqueta
                                        tamano: 10
                                        implicitHeight: 22
                                        conPunto: modelData.peligro
                                        punto: Theme.prioMaxima
                                        encendido: !bloque.enviandoStack
                                        onActivado: servidor.pedir("stack", bloque.st.nombre, modelData.accion)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: bloque.st.contenedores.length === 0
                            text: "Sin contenedores (el stack está bajado)."
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Repeater {
                            model: bloque.st.contenedores

                            delegate: Rectangle {
                                id: tarjeta

                                required property var modelData
                                readonly property var c: tarjeta.modelData
                                readonly property var v: Logica.vista(tarjeta.c)
                                readonly property var uso: servidor.consumo ? servidor.consumo.contenedores[tarjeta.c.nombre] || null : null
                                readonly property bool enviandoYo: servidor.enviando["contenedor:" + tarjeta.c.nombre] === true || bloque.enviandoStack

                                objectName: "contenedor-" + tarjeta.c.nombre
                                Layout.fillWidth: true
                                implicitHeight: filas.implicitHeight + 16
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: Theme.rule

                                ColumnLayout {
                                    id: filas

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 7

                                        Rectangle {
                                            objectName: "puntoContenedor"
                                            implicitWidth: 7
                                            implicitHeight: 7
                                            radius: 3.5
                                            color: servidor.colorPunto(tarjeta.v.punto)

                                            // Cada «state» nuevo vuelve a crear la
                                            // tarjeta, así que al acabar la acción
                                            // el punto sale entero.
                                            SequentialAnimation on opacity {
                                                running: tarjeta.v.punto === "ocupado"
                                                loops: Animation.Infinite

                                                NumberAnimation {
                                                    to: 0.25
                                                    duration: 600
                                                    easing.type: Easing.InOutQuint
                                                }

                                                NumberAnimation {
                                                    to: 1
                                                    duration: 600
                                                    easing.type: Easing.InOutQuint
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 40
                                            text: tarjeta.c.servicio + (tarjeta.c.servicio !== tarjeta.c.nombre ? "  " + tarjeta.c.nombre : "")
                                            color: Theme.strong
                                            font.family: Theme.font
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Repeater {
                                            model: Logica.botones(tarjeta.c)

                                            delegate: Chip {
                                                required property var modelData

                                                objectName: "accion-" + tarjeta.c.nombre + "-" + modelData.accion
                                                texto: modelData.etiqueta
                                                tamano: 10
                                                implicitHeight: 22
                                                activo: modelData.principal
                                                conPunto: modelData.peligro
                                                punto: Theme.prioMaxima
                                                encendido: !tarjeta.enviandoYo
                                                onActivado: servidor.pedir("contenedor", tarjeta.c.nombre, modelData.accion)
                                            }
                                        }

                                        Chip {
                                            objectName: "logs-" + tarjeta.c.nombre
                                            texto: "Logs"
                                            tamano: 10
                                            implicitHeight: 22
                                            onActivado: {
                                                servidor.menuDe = "";
                                                servidor.api.abrirLogs(tarjeta.c.nombre);
                                            }
                                        }
                                    }

                                    Text {
                                        objectName: "estadoContenedor"
                                        Layout.fillWidth: true
                                        text: tarjeta.v.texto + (tarjeta.uso ? "  ·  CPU " + Logica.pct(tarjeta.uso.cpu) + " · RAM " + Logica.bytes(tarjeta.uso.mem) : "")
                                        color: tarjeta.v.punto === "mal" ? Theme.danger : (tarjeta.v.punto === "aviso" ? Theme.warn : Theme.muted)
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // Ver el compose y lo de los contenedores sueltos: en la web.
                Item {
                    objectName: "servidorEnLaWeb"
                    Layout.fillWidth: true
                    implicitHeight: textoWeb.implicitHeight + 6

                    Text {
                        id: textoWeb

                        y: 6
                        width: parent.width
                        text: "Ver el compose de cada stack: en la web"
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
                        onTapped: servidor.abrirWeb()
                    }
                }
            }
        }
    }

    signal abrirWeb

    Logs {
        objectName: "logsServidor"
        anchors.fill: parent
        api: servidor.api
        onCerrar: servidor.api.cerrarLogs()
    }

    Confirmar {
        id: confirmar

        objectName: "confirmarServidor"
        anchors.fill: parent
        onAceptado: escrito => {
            const q = confirmar.pendiente;
            if (q)
                servidor.lanzar(q.tipo, q.nombre, q.accion, escrito);
            Qt.callLater(() => sumidero.forceActiveFocus());
        }
        onCancelado: Qt.callLater(() => sumidero.forceActiveFocus())
    }
}
