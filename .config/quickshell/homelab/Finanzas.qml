import QtQuick
import QtQuick.Layouts
import "shared"
import "FinanzasLogica.js" as Logica

// Finanzas en el cajón: arriba cuatro tarjetas (patrimonio, flujo del mes,
// nóminas y Trade Republic), después dos gráficos sencillos (ingresos y gastos
// de los últimos meses, gasto por categoría) y los movimientos recientes, con
// la categoría editable al tocar uno, el gasto en efectivo y «Cargar más».
// Importar extractos y nóminas y el PIN de Trade Republic se quedan en la web
// (el botón «Iniciar sesión en Trade Republic» abre la web). Los datos salen de
// api.finanzas, api.nominasFinanzas y api.traderepublic.
//
// «modo» lo da Contenido según el ancho del cajón: «compacto» (<600 px, una
// columna), «medio» (600–1000) y «amplio» (≥1000, dos columnas: resumen y
// gráficos a un lado, movimientos al otro).
//
// Los euros solo se enseñan con el cajón desplegado (decisión E11): «desplegado»
// es el de Contenido.qml (fuera y quieto), y sin él todo importe sale como
// «•••», también el que se escribe después de apuntar un gasto. Lo que sí sale
// siempre es el % de la meta, que no es una cantidad.
Item {
    id: finanzas

    required property var shell
    readonly property var api: finanzas.shell.api

    property string lineaConexion: ""
    // El cajón entero fuera y quieto (Contenido.desplegado).
    property bool desplegado: false
    property string modo: "compacto"
    readonly property bool amplio: finanzas.modo === "amplio"

    signal abrirWeb

    readonly property var datos: finanzas.api ? finanzas.api.finanzas : null
    readonly property var tr: finanzas.api ? finanzas.api.traderepublic : null
    readonly property bool conectado: finanzas.api !== null && finanzas.api.conexion === "conectado"
    // Hay datos que enseñar: el bloque está en el NUC y migrado.
    readonly property bool listo: finanzas.datos !== null && finanzas.datos.habilitado && finanzas.datos.listo
    // Iniciar sesión es de la web, y solo con el permiso del usuario.
    readonly property bool puedeLoginTR: finanzas.api !== null && finanzas.api.permisos !== null && finanzas.api.permisos.login_traderepublic === true

    // El formulario del gasto en efectivo.
    property int categoria: 0
    property string errorForm: ""
    // El movimiento con las categorías abiertas (0, ninguno) y su error.
    property int editando: 0
    property string errorCat: ""
    property bool verEfectivo: false

    readonly property var nom: finanzas.api ? finanzas.api.nominasFinanzas : null
    readonly property var cuentaTR: finanzas.listo ? Logica.cuentaTR(finanzas.datos.cuentas) : null
    readonly property color verde: Theme.ok

    // Se lee la primera vez que se mira y, después, al desplegar el cajón si lo
    // que hay es de hace más de un minuto.
    function ponerAlDia() {
        if (!finanzas.visible || !finanzas.conectado || !finanzas.api)
            return;
        if (finanzas.api.finanzasViejas())
            finanzas.api.cargarFinanzas();
        if (finanzas.tr === null || finanzas.desplegado)
            finanzas.api.cargarTradeRepublic();
        if (finanzas.api.nominasFinanzas === null || finanzas.desplegado)
            finanzas.api.cargarNominasFinanzas();
    }

    onVisibleChanged: finanzas.ponerAlDia()
    onDesplegadoChanged: if (finanzas.desplegado)
        finanzas.ponerAlDia()

    Connections {
        target: finanzas.api

        function onConexionChanged() {
            finanzas.ponerAlDia();
        }
    }

    function categorizar(id, cat) {
        finanzas.errorCat = "";
        finanzas.api.categorizarMovimiento(id, cat, (ok, error) => {
            if (ok)
                finanzas.editando = 0;
            else
                finanzas.errorCat = error;
        });
    }

    function euros(c) {
        return Logica.euros(c, finanzas.desplegado);
    }

    function apuntar() {
        finanzas.errorForm = "";
        const cents = Logica.centimos(importe.texto);
        if (cents === null) {
            finanzas.errorForm = "Escribe el importe gastado, como 12,50.";
            return;
        }
        if (concepto.texto.trim() === "") {
            finanzas.errorForm = "Escribe un concepto.";
            return;
        }
        if (finanzas.categoria === 0) {
            finanzas.errorForm = "Elige una categoría de gasto.";
            return;
        }
        finanzas.api.apuntarEfectivo(cents, concepto.texto.trim(), finanzas.categoria, "", (ok, error) => {
            if (ok) {
                importe.texto = "";
                concepto.texto = "";
                finanzas.categoria = 0;
            } else {
                finanzas.errorForm = error;
            }
        });
    }

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    // Una tarjeta de cristal con título, el dato grande y una línea pequeña.
    component Tarjeta: Rectangle {
        id: tarjeta

        property string titulo: ""
        property string valor: ""
        property string detalle: ""
        property color colorValor: Theme.strong
        property color colorDetalle: Theme.faint
        default property alias extra: contenidoExtra.data

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        implicitHeight: interior.implicitHeight + 20
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Theme.rule

        ColumnLayout {
            id: interior

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 3

            Etiqueta {
                text: tarjeta.titulo
            }

            Text {
                Layout.fillWidth: true
                text: tarjeta.valor
                color: tarjeta.colorValor
                font.family: Theme.font
                font.pixelSize: 17
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: tarjeta.detalle
                color: tarjeta.colorDetalle
                font.family: Theme.font
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                id: contenidoExtra

                Layout.fillWidth: true
                spacing: 4
            }
        }
    }

    // Una barra horizontal que crece con muelle.
    component BarraH: Rectangle {
        property real fraccion: 0
        property color relleno: Theme.ok

        implicitHeight: 5
        radius: 2.5
        color: Qt.rgba(1, 1, 1, 0.08)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.fraccion))
            height: parent.height
            radius: 2.5
            color: parent.relleno

            Behavior on width {
                NumberAnimation {
                    duration: Theme.animIn
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.overshootIn
                }
            }
        }
    }

    Flickable {
        id: desplazable

        objectName: "desplazableFinanzas"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: columna.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: columna

            width: desplazable.width
            spacing: 10
            opacity: finanzas.lineaConexion === "" ? 1 : 0.5

            RowLayout {
                Layout.fillWidth: true
                visible: finanzas.lineaConexion !== ""
                spacing: 8

                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Theme.muted
                }

                Text {
                    objectName: "lineaConexionFinanzas"
                    Layout.fillWidth: true
                    text: finanzas.lineaConexion
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                objectName: "finanzasCargando"
                Layout.fillWidth: true
                visible: finanzas.datos === null
                text: finanzas.lineaConexion === "" ? "Leyendo Finanzas…" : "Sin datos"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }

            Text {
                objectName: "errorFinanzas"
                Layout.fillWidth: true
                visible: finanzas.datos !== null && finanzas.datos.error !== ""
                text: finanzas.datos ? finanzas.datos.error : ""
                color: Theme.warn
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // El bloque apagado o sin migrar en el NUC.
            Text {
                objectName: "finanzasApagado"
                Layout.fillWidth: true
                visible: finanzas.datos !== null && !finanzas.listo && finanzas.datos.error === ""
                text: finanzas.datos === null ? "" : (!finanzas.datos.habilitado ? "Finanzas no está configurado en el NUC." : "Finanzas no está lista en el NUC" + (finanzas.datos.motivo ? ": " + finanzas.datos.motivo : "."))
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            // La sesión de Trade Republic caducada: el aviso lo ve cualquiera;
            // el botón, solo quien puede iniciarla (login_traderepublic).
            Rectangle {
                objectName: "avisoTradeRepublic"
                Layout.fillWidth: true
                visible: finanzas.listo && finanzas.tr !== null && finanzas.tr.configurado && finanzas.tr.caducada
                implicitHeight: avisoTR.implicitHeight + 20
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Theme.warn

                ColumnLayout {
                    id: avisoTR

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "La sesión de Trade Republic ha caducado: hasta que se inicie de nuevo, no entran sus movimientos."
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    Chip {
                        objectName: "iniciarTradeRepublic"
                        visible: finanzas.puedeLoginTR
                        texto: "Iniciar sesión en Trade Republic"
                        onActivado: finanzas.abrirWeb()
                    }
                }
            }

            GridLayout {
                id: rejilla

                Layout.fillWidth: true
                visible: finanzas.listo
                columns: finanzas.amplio ? 2 : 1
                columnSpacing: 16
                rowSpacing: 12

                // --- Izquierda: tarjetas y gráficos ---
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 1
                    spacing: 10

                    Etiqueta {
                        text: finanzas.listo && finanzas.datos.mes !== "" ? Logica.nombreMes(finanzas.datos.mes).toUpperCase() : "ESTE MES"
                    }

                    GridLayout {
                        objectName: "resumenFinanzas"
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        Tarjeta {
                            objectName: "tarjetaPatrimonio"
                            titulo: "PATRIMONIO"
                            valor: finanzas.listo ? finanzas.euros(finanzas.datos.patrimonio) : ""
                            colorValor: finanzas.verde
                            detalle: finanzas.listo ? Math.round(finanzas.datos.porcentaje) + " % de la meta" : ""

                            BarraH {
                                Layout.fillWidth: true
                                fraccion: finanzas.listo ? finanzas.datos.porcentaje / 100 : 0
                                relleno: finanzas.verde
                            }
                        }

                        Tarjeta {
                            objectName: "tarjetaFlujo"
                            readonly property int f: finanzas.listo ? Logica.flujo(finanzas.datos.ingresos, finanzas.datos.gastos.total) : 0
                            titulo: "FLUJO DEL MES"
                            valor: finanzas.listo ? finanzas.euros(f) : ""
                            colorValor: finanzas.desplegado && f < 0 ? Theme.warn : Theme.strong
                            detalle: finanzas.listo ? "Ingresos " + finanzas.euros(finanzas.datos.ingresos) + " · gastos " + finanzas.euros(finanzas.datos.gastos.total) : ""

                            Text {
                                objectName: "gastosMes"
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: finanzas.listo ? Logica.comparar(finanzas.datos.gastos) : ""
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }

                        Tarjeta {
                            objectName: "tarjetaNominas"
                            titulo: "NÓMINAS"
                            valor: finanzas.nom && finanzas.nom.ultima ? finanzas.euros(finanzas.nom.ultima.neto) : (finanzas.nom ? "Sin nóminas" : "…")
                            detalle: finanzas.nom && finanzas.nom.ultima ? "Neto de " + Logica.mesCorto(finanzas.nom.ultima.mes) + " · " + finanzas.nom.n + " en " + finanzas.nom.año : (finanzas.nom ? "Este año" : "")
                        }

                        Tarjeta {
                            objectName: "tarjetaTR"
                            readonly property bool caducada: finanzas.tr !== null && finanzas.tr.caducada
                            titulo: "TRADE REPUBLIC"
                            valor: finanzas.cuentaTR && finanzas.cuentaTR.saldo !== null ? finanzas.euros(finanzas.cuentaTR.saldo) : "—"
                            detalle: finanzas.tr === null ? "" : (!finanzas.tr.configurado ? "Sin configurar" : (caducada ? "Sesión caducada" : "Sesión activa" + (finanzas.tr.ultimoOk ? " · " + Logica.haceCuanto(Date.now() - finanzas.tr.ultimoOk.getTime()) : "")))
                            colorDetalle: caducada ? Theme.warn : Theme.faint

                            Chip {
                                visible: finanzas.tr !== null && finanzas.tr.configurado && finanzas.tr.caducada && finanzas.puedeLoginTR
                                texto: "Iniciar sesión"
                                tamano: 10
                                onActivado: finanzas.abrirWeb()
                            }
                        }
                    }

                    // Gráfico: ingresos y gastos de los últimos meses.
                    ColumnLayout {
                        objectName: "graficoMeses"
                        readonly property var serie: finanzas.listo ? Logica.serieMeses(finanzas.datos.meses, 6) : []
                        Layout.fillWidth: true
                        visible: serie.length > 1
                        spacing: 6

                        Etiqueta {
                            Layout.topMargin: 4
                            text: "INGRESOS Y GASTOS"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: parent.parent.serie

                                delegate: ColumnLayout {
                                    id: colMes

                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 3

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 70

                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            spacing: 3

                                            Rectangle {
                                                width: 8
                                                radius: 2
                                                anchors.bottom: parent.bottom
                                                height: Math.max(2, 70 * colMes.modelData.ingresos)
                                                color: finanzas.verde
                                                opacity: colMes.modelData.parcial ? 0.5 : 1

                                                Behavior on height {
                                                    NumberAnimation {
                                                        duration: Theme.animIn
                                                        easing.type: Easing.OutBack
                                                        easing.overshoot: Theme.overshootIn
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 8
                                                radius: 2
                                                anchors.bottom: parent.bottom
                                                height: Math.max(2, 70 * colMes.modelData.gastos)
                                                color: Qt.rgba(1, 1, 1, 0.55)
                                                opacity: colMes.modelData.parcial ? 0.5 : 1

                                                Behavior on height {
                                                    NumberAnimation {
                                                        duration: Theme.animIn
                                                        easing.type: Easing.OutBack
                                                        easing.overshoot: Theme.overshootIn
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: colMes.modelData.etiqueta
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 12

                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 2
                                    color: finanzas.verde
                                }
                                Text {
                                    text: "Ingresos"
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }
                            }

                            Row {
                                spacing: 5
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                }
                                Text {
                                    text: "Gastos"
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }

                    // Gráfico: gasto por categoría.
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: finanzas.listo && finanzas.datos.gastos.porCategoria.length > 0
                        spacing: 5

                        Etiqueta {
                            Layout.topMargin: 4
                            text: "GASTO POR CATEGORÍA"
                        }

                        Repeater {
                            model: finanzas.listo ? Logica.barrasCategorias(finanzas.datos.gastos.porCategoria, 6) : []

                            delegate: ColumnLayout {
                                id: cat

                                required property var modelData

                                objectName: "categoria-" + cat.modelData.id
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        Layout.fillWidth: true
                                        text: cat.modelData.nombre + " · " + cat.modelData.n
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: finanzas.euros(cat.modelData.total)
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                    }
                                }

                                BarraH {
                                    Layout.fillWidth: true
                                    fraccion: cat.modelData.fraccion
                                    relleno: finanzas.verde
                                }
                            }
                        }

                        Text {
                            objectName: "sinCategoria"
                            Layout.fillWidth: true
                            visible: finanzas.listo && finanzas.datos.sinCategoria > 0
                            text: finanzas.listo ? finanzas.datos.sinCategoria + " movimientos sin categoría: toca uno para clasificarlo." : ""
                            color: Theme.warn
                            font.family: Theme.font
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // --- Derecha: movimientos ---
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 1
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Etiqueta {
                            Layout.fillWidth: true
                            text: "MOVIMIENTOS RECIENTES"
                        }

                        Chip {
                            objectName: "alternarEfectivo"
                            texto: "Gasto en efectivo"
                            tamano: 10
                            activo: finanzas.verEfectivo
                            onActivado: finanzas.verEfectivo = !finanzas.verEfectivo
                        }
                    }

                    // --- Apuntar un gasto en efectivo (se despliega) ---
                    Item {
                        id: panelEfectivo

                        objectName: "formEfectivo"
                        Layout.fillWidth: true
                        Layout.preferredHeight: finanzas.verEfectivo ? formulario.implicitHeight : 0
                        clip: true
                        opacity: finanzas.verEfectivo ? 1 : 0
                        visible: Layout.preferredHeight > 0.5

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: finanzas.verEfectivo ? Theme.animIn : Theme.animOut
                                easing.type: finanzas.verEfectivo ? Easing.OutBack : Easing.InOutQuint
                                easing.overshoot: Theme.overshootIn
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        ColumnLayout {
                            id: formulario

                            width: parent.width
                            spacing: 6

                            Campo {
                                id: importe

                                objectName: "campoImporte"
                                Layout.fillWidth: true
                                pista: "Importe, como 12,50"
                                onAceptado: concepto.enfocar()
                            }

                            Campo {
                                id: concepto

                                objectName: "campoConcepto"
                                Layout.fillWidth: true
                                pista: "Concepto"
                                onAceptado: finanzas.apuntar()
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: finanzas.listo ? finanzas.datos.categorias : []

                                    delegate: Chip {
                                        id: ce

                                        required property var modelData

                                        objectName: "catEfectivo-" + ce.modelData.id
                                        texto: ce.modelData.nombre
                                        activo: finanzas.categoria === ce.modelData.id
                                        onActivado: finanzas.categoria = finanzas.categoria === ce.modelData.id ? 0 : ce.modelData.id
                                    }
                                }
                            }

                            Text {
                                objectName: "errorForm"
                                Layout.fillWidth: true
                                visible: finanzas.errorForm !== ""
                                text: finanzas.errorForm
                                color: Theme.warn
                                font.family: Theme.font
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }

                            Chip {
                                objectName: "apuntarEfectivo"
                                Layout.bottomMargin: 6
                                texto: finanzas.datos && finanzas.datos.ocupado ? "Apuntando…" : "Apuntar gasto"
                                encendido: finanzas.conectado && finanzas.desplegado && !(finanzas.datos && finanzas.datos.ocupado)
                                onActivado: finanzas.apuntar()
                            }
                        }
                    }

                    Text {
                        objectName: "sinMovimientos"
                        Layout.fillWidth: true
                        visible: finanzas.listo && finanzas.datos.movimientos.length === 0
                        text: "Ninguno este mes."
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Text {
                        objectName: "errorCategoria"
                        Layout.fillWidth: true
                        visible: finanzas.errorCat !== ""
                        text: finanzas.errorCat
                        color: Theme.warn
                        font.family: Theme.font
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: finanzas.listo ? finanzas.datos.movimientos : []

                        delegate: ColumnLayout {
                            id: mov

                            required property var modelData
                            readonly property bool editable: mov.modelData.importe < 0
                            readonly property bool abierta: finanzas.editando === mov.modelData.id

                            objectName: "movimiento-" + mov.modelData.id
                            Layout.fillWidth: true
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: filaMov.implicitHeight + 10
                                radius: 8
                                color: mov.abierta ? Qt.rgba(1, 1, 1, 0.08) : (sobreMov.hovered && mov.editable ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }

                                RowLayout {
                                    id: filaMov

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 6
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 42
                                        Layout.alignment: Qt.AlignTop
                                        text: Logica.diaCorto(mov.modelData.fecha)
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            text: mov.modelData.concepto
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            textFormat: Text.PlainText
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (mov.modelData.categoria !== "" ? mov.modelData.categoria : "Sin categoría") + (mov.editable ? "  ✎" : "")
                                            color: mov.modelData.categoria !== "" ? Theme.faint : Theme.warn
                                            font.family: Theme.font
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: finanzas.euros(mov.modelData.importe)
                                        color: finanzas.desplegado && mov.modelData.importe > 0 ? finanzas.verde : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                    }
                                }

                                HoverHandler {
                                    id: sobreMov
                                    cursorShape: mov.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                }

                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: if (mov.editable) {
                                        finanzas.errorCat = "";
                                        finanzas.editando = mov.abierta ? 0 : mov.modelData.id;
                                    }
                                }
                            }

                            // Las categorías, con muelle al abrir y al cerrar.
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: mov.abierta ? catsFlow.implicitHeight + 8 : 0
                                clip: true
                                opacity: mov.abierta ? 1 : 0
                                visible: Layout.preferredHeight > 0.5

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation {
                                        duration: mov.abierta ? Theme.animIn : Theme.animOut
                                        easing.type: mov.abierta ? Easing.OutBack : Easing.InOutQuint
                                        easing.overshoot: Theme.overshootIn
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }

                                Flow {
                                    id: catsFlow

                                    x: 6
                                    y: 4
                                    width: parent.width - 12
                                    spacing: 6

                                    Repeater {
                                        model: finanzas.listo ? finanzas.datos.categorias : []

                                        delegate: Chip {
                                            id: cm

                                            required property var modelData

                                            objectName: "catMov-" + mov.modelData.id + "-" + cm.modelData.id
                                            texto: cm.modelData.nombre
                                            tamano: 10
                                            activo: mov.modelData.categoriaId === cm.modelData.id
                                            encendido: finanzas.conectado
                                            onActivado: finanzas.categorizar(mov.modelData.id, cm.modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Chip {
                        objectName: "masFinanzas"
                        Layout.topMargin: 4
                        Layout.alignment: Qt.AlignHCenter
                        visible: finanzas.listo && finanzas.datos.mas
                        texto: finanzas.datos && finanzas.datos.cargandoMas ? "Cargando…" : "Cargar más"
                        encendido: finanzas.datos !== null && !finanzas.datos.cargandoMas && finanzas.conectado
                        onActivado: finanzas.api.masFinanzas()
                    }
                }
            }

            // Lo que se queda en la web.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: 1
                color: Theme.rule
            }

            Text {
                Layout.fillWidth: true
                text: "Importar extractos y nóminas, y el inicio de sesión de Trade Republic, se hacen en la web."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Chip {
                objectName: "finanzasWeb"
                Layout.bottomMargin: 8
                texto: "Abrir en la web"
                onActivado: finanzas.abrirWeb()
            }
        }
    }
}
