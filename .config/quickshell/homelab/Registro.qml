import QtQuick
import QtQuick.Layouts
import "shared"
import "RegistroLogica.js" as Logica

// El Registro del NUC en el cajón, como la hoja «Registro» de la web: lo que
// ha pasado en el servidor (contenedores, paquetes, sistema, discos y lo que
// se ha hecho desde el panel), de lo más nuevo a lo más viejo, partido por
// días y con sus filtros. Un clic en una línea con detalle lo despliega (se
// pide al NUC entonces: la lista no lo trae). Las líneas nuevas llegan solas
// por los eventos (api.registro); «Cargar más» trae las de antes. «Detalles»
// de una alerta (en Inicio) trae aquí su línea: enfocar().
Item {
    id: registro

    required property var shell
    readonly property var api: registro.shell.api

    property string lineaConexion: ""

    readonly property var datos: registro.api ? registro.api.registro : null
    readonly property var filas: Logica.conDias(registro.datos ? registro.datos.entradas : [])

    // Las líneas desplegadas ({ id: true }) y sus detalles ({ id: { cargando,
    // texto, error } }), que se piden una vez.
    property var abiertas: ({})
    property var detalles: ({})

    // La línea que se busca (el id que trae una alerta), o 0; la que se ha
    // encontrado y se resalta; y las páginas que se han pedido buscándola.
    property int foco: 0
    property int resaltada: 0
    property int paginasFoco: 0
    // Como mucho, las páginas que se piden para buscar una línea.
    readonly property int maxPaginasFoco: 20

    // Como la web (openJournal y focusEntry): sin filtro, y con páginas más
    // viejas hasta que sale. Entonces se despliega, se resalta y se lleva a
    // la vista.
    function enfocar(id) {
        if (!registro.api || !(id > 0))
            return;
        registro.foco = id;
        registro.resaltada = 0;
        registro.paginasFoco = 0;
        registro.abiertas = ({});
        registro.api.cargarRegistro("");
    }

    onDatosChanged: Qt.callLater(registro.seguirFoco)

    function seguirFoco() {
        const d = registro.datos;
        if (registro.foco === 0 || !d || d.cargando || d.filtro !== "")
            return;
        const e = d.error === "" ? d.entradas.find(x => x.id === registro.foco) : null;
        if (e) {
            registro.foco = 0;
            registro.resaltada = e.id;
            if (e.conDetalle && !registro.abiertas[e.id])
                registro.alternar(e);
            llevar.intentos = 0;
            llevar.restart();
            return;
        }
        if (d.error === "" && d.mas && registro.paginasFoco < registro.maxPaginasFoco) {
            registro.paginasFoco++;
            registro.api.masRegistro();
            return;
        }
        registro.foco = 0;
        if (d.error === "")
            registro.api.aviso("Esa línea ya no está en el Registro", true);
    }

    // La fila resaltada, a un tercio de la altura de la lista. Espera a que
    // la lista se haya colocado (la fila aparece un poco después).
    Timer {
        id: llevar

        property int intentos: 0

        interval: 40
        onTriggered: {
            let fila = null;
            for (const c of columna.children)
                if (c.objectName === "entrada-" + registro.resaltada)
                    fila = c;
            if (!fila || fila.height <= 0) {
                if (++llevar.intentos < 25)
                    llevar.restart();
                return;
            }
            const y = fila.y - desplazable.height / 3;
            desplazable.contentY = Math.max(0, Math.min(Math.max(0, desplazable.contentHeight - desplazable.height), y));
        }
    }

    // Se lee la primera vez que se mira; después llega solo.
    function ponerAlDia() {
        if (registro.visible && registro.api && registro.api.registro === null && registro.api.conexion === "conectado")
            registro.api.cargarRegistro("");
    }

    onVisibleChanged: registro.ponerAlDia()

    Connections {
        target: registro.api

        function onConexionChanged() {
            registro.ponerAlDia();
        }
    }

    function filtrar(valor) {
        registro.foco = 0;
        registro.resaltada = 0;
        registro.abiertas = ({});
        registro.api.cargarRegistro(valor);
    }

    function alternar(e) {
        const a = Object.assign({}, registro.abiertas);
        if (a[e.id]) {
            delete a[e.id];
            registro.abiertas = a;
            return;
        }
        a[e.id] = true;
        registro.abiertas = a;
        const d = registro.detalles[e.id];
        if (d && !d.error)
            return;
        registro.ponerDetalle(e.id, {
            cargando: true,
            texto: "",
            error: ""
        });
        registro.api.detalleRegistro(e.id, (texto, error) => registro.ponerDetalle(e.id, {
                cargando: false,
                texto: texto,
                error: error
            }));
    }

    function ponerDetalle(id, v) {
        const d = Object.assign({}, registro.detalles);
        d[id] = v;
        registro.detalles = d;
    }

    function colorNivel(n) {
        return n === "error" ? Theme.danger : (n === "warn" ? Theme.warn : Theme.faint);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            visible: registro.lineaConexion !== ""
            spacing: 8

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.muted
            }

            Text {
                objectName: "lineaConexionRegistro"
                Layout.fillWidth: true
                text: registro.lineaConexion
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        // Los filtros de la web.
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Logica.FILTROS

                delegate: Chip {
                    required property var modelData

                    objectName: "filtroRegistro-" + (modelData[0] || "todo")
                    texto: modelData[1]
                    activo: (registro.datos ? registro.datos.filtro : "") === modelData[0]
                    encendido: registro.api !== null && registro.api.conexion === "conectado"
                    onActivado: registro.filtrar(modelData[0])
                }
            }
        }

        Flickable {
            id: desplazable

            objectName: "desplazableRegistro"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 2
                opacity: registro.lineaConexion === "" ? 1 : 0.5

                Text {
                    objectName: "registroCargando"
                    Layout.fillWidth: true
                    visible: registro.datos === null || (registro.datos.cargando && registro.datos.entradas.length === 0)
                    text: registro.lineaConexion === "" ? "Leyendo el registro…" : "Sin datos"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    objectName: "errorRegistro"
                    Layout.fillWidth: true
                    visible: registro.datos !== null && registro.datos.error !== ""
                    text: registro.datos ? registro.datos.error : ""
                    color: Theme.warn
                    font.family: Theme.font
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    objectName: "registroVacio"
                    Layout.fillWidth: true
                    visible: registro.datos !== null && !registro.datos.cargando && registro.datos.error === "" && registro.datos.entradas.length === 0
                    text: registro.datos && registro.datos.filtro !== "" ? "Nada con este filtro." : "Nada registrado todavía."
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Repeater {
                    model: registro.filas

                    delegate: Item {
                        id: fila

                        required property var modelData
                        readonly property var e: fila.modelData.e
                        readonly property bool esDia: fila.modelData.tipo === "dia"
                        readonly property bool abierta: !fila.esDia && registro.abiertas[fila.e.id] === true
                        // La que ha traído «Detalles» de una alerta.
                        readonly property bool resaltada: !fila.esDia && registro.resaltada === fila.e.id
                        readonly property var detalle: fila.abierta ? registro.detalles[fila.e.id] || null : null

                        objectName: fila.esDia ? "diaRegistro" : "entrada-" + fila.e.id
                        Layout.fillWidth: true
                        implicitHeight: fila.esDia ? dia.implicitHeight + 12 : marco.implicitHeight

                        Text {
                            id: dia

                            visible: fila.esDia
                            y: 8
                            text: fila.modelData.texto
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Rectangle {
                            id: marco

                            visible: !fila.esDia
                            width: parent.width
                            implicitHeight: pila.implicitHeight + 10
                            radius: 8
                            color: fila.abierta || fila.resaltada ? Qt.rgba(1, 1, 1, 0.07) : (sobre.hovered && !fila.esDia && fila.e.conDetalle ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                            border.width: fila.resaltada ? 1 : 0
                            border.color: Qt.rgba(1, 1, 1, 0.22)

                            HoverHandler {
                                id: sobre
                                cursorShape: !fila.esDia && fila.e.conDetalle ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: if (!fila.esDia && fila.e.conDetalle)
                                    registro.alternar(fila.e)
                            }

                            ColumnLayout {
                                id: pila

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 5
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: fila.esDia ? "" : Logica.hora(fila.e.hora)
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.topMargin: 4
                                        implicitWidth: 6
                                        implicitHeight: 6
                                        radius: 3
                                        color: fila.esDia ? "transparent" : registro.colorNivel(fila.e.nivel)
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        implicitWidth: etiquetaFuente.implicitWidth + 10
                                        implicitHeight: etiquetaFuente.implicitHeight + 2
                                        radius: 4
                                        color: Qt.rgba(1, 1, 1, 0.07)

                                        Text {
                                            id: etiquetaFuente

                                            anchors.centerIn: parent
                                            text: fila.esDia ? "" : Logica.fuente(fila.e.fuente)
                                            color: Theme.muted
                                            font.family: Theme.font
                                            font.pixelSize: 9
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: fila.esDia ? "" : fila.e.titulo
                                        color: fila.esDia || fila.e.nivel === "info" ? Theme.text : Theme.strong
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        visible: !fila.esDia && fila.e.conDetalle
                                        text: fila.abierta ? "" : ""
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 8
                                    }
                                }

                                // El detalle, tal cual lo guarda el NUC.
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: 2
                                    visible: fila.abierta
                                    implicitHeight: textoDetalle.implicitHeight + 14
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.35)

                                    Text {
                                        id: textoDetalle

                                        objectName: "detalleRegistro"
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        text: {
                                            const d = fila.detalle;
                                            if (!d || d.cargando)
                                                return "Cargando…";
                                            if (d.error)
                                                return d.error;
                                            return d.texto || "(sin detalle)";
                                        }
                                        color: fila.detalle && fila.detalle.error ? Theme.warn : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        wrapMode: Text.WrapAnywhere
                                        textFormat: Text.PlainText
                                    }
                                }
                            }
                        }
                    }
                }

                Chip {
                    objectName: "masRegistro"
                    Layout.topMargin: 8
                    Layout.alignment: Qt.AlignHCenter
                    visible: registro.datos !== null && registro.datos.mas
                    texto: registro.datos && registro.datos.cargando ? "Cargando…" : "Cargar más"
                    encendido: registro.datos !== null && !registro.datos.cargando
                    onActivado: registro.api.masRegistro()
                }

                // Lo que el NUC no puede ver (permisos que le faltan).
                Text {
                    objectName: "notasRegistro"
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    visible: text !== ""
                    text: registro.datos ? registro.datos.notas.join(" ") : ""
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
