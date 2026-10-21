import QtQuick
import QtQuick.Layouts
import "shared"
import "FinanzasLogica.js" as Logica

// Finanzas en el cajón, la parte de mirar y de apuntar un gasto en efectivo:
// el resumen del mes, los movimientos (con «Cargar más») y el aviso de que la
// sesión de Trade Republic ha caducado. Importar extractos y nóminas y
// iniciar sesión en Trade Republic se quedan en la web (botón «Abrir en la
// web»). Las cuentas y los importes salen de api.finanzas.
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

    // Se lee la primera vez que se mira y, después, al desplegar el cajón si lo
    // que hay es de hace más de un minuto.
    function ponerAlDia() {
        if (!finanzas.visible || !finanzas.conectado || !finanzas.api)
            return;
        if (finanzas.api.finanzasViejas())
            finanzas.api.cargarFinanzas();
        if (finanzas.tr === null || finanzas.desplegado)
            finanzas.api.cargarTradeRepublic();
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

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

        Flickable {
            id: desplazable

            objectName: "desplazableFinanzas"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 10
                opacity: finanzas.lineaConexion === "" ? 1 : 0.5

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

                // La sesión de Trade Republic. El aviso lo ve cualquiera; el
                // botón, solo quien puede iniciarla (login_traderepublic).
                Rectangle {
                    objectName: "avisoTradeRepublic"
                    Layout.fillWidth: true
                    visible: finanzas.listo && finanzas.tr !== null && finanzas.tr.configurado && finanzas.tr.caducada
                    implicitHeight: avisoTR.implicitHeight + 20
                    radius: 8
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
                            texto: "Iniciar sesión en la web"
                            onActivado: finanzas.abrirWeb()
                        }
                    }
                }

                // --- El resumen del mes ---
                ColumnLayout {
                    objectName: "resumenFinanzas"
                    Layout.fillWidth: true
                    visible: finanzas.listo
                    spacing: 6

                    Etiqueta {
                        text: finanzas.listo ? finanzas.datos.mes !== "" ? Logica.nombreMes(finanzas.datos.mes).toUpperCase() : "ESTE MES" : ""
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: "Gastos"
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }

                        Text {
                            objectName: "gastosMes"
                            text: finanzas.listo ? finanzas.euros(finanzas.datos.gastos.total) : ""
                            color: Theme.strong
                            font.family: Theme.font
                            font.pixelSize: 16
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: finanzas.listo ? Logica.comparar(finanzas.datos.gastos) : ""
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: "Ingresos"
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }

                        Text {
                            objectName: "ingresosMes"
                            text: finanzas.listo ? finanzas.euros(finanzas.datos.ingresos) : ""
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: finanzas.listo ? "Ahorro · " + Math.round(finanzas.datos.porcentaje) + " % de la meta" : ""
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }

                        Text {
                            objectName: "patrimonio"
                            text: finanzas.listo ? finanzas.euros(finanzas.datos.patrimonio) : ""
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: finanzas.listo ? parent.width * Math.max(0, Math.min(100, finanzas.datos.porcentaje)) / 100 : 0
                            height: parent.height
                            radius: 2
                            color: Theme.ok
                        }
                    }

                    Repeater {
                        model: finanzas.listo ? finanzas.datos.gastos.porCategoria.slice(0, 5) : []

                        delegate: RowLayout {
                            id: cat

                            required property var modelData

                            objectName: "categoria-" + cat.modelData.id
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
                    }

                    Text {
                        objectName: "sinCategoria"
                        Layout.fillWidth: true
                        visible: finanzas.listo && finanzas.datos.sinCategoria > 0
                        text: finanzas.listo ? finanzas.datos.sinCategoria + " movimientos sin categoría (se clasifican en la web)." : ""
                        color: Theme.warn
                        font.family: Theme.font
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }

                // --- Apuntar un gasto en efectivo ---
                ColumnLayout {
                    objectName: "formEfectivo"
                    Layout.fillWidth: true
                    visible: finanzas.listo
                    spacing: 6

                    Etiqueta {
                        Layout.topMargin: 6
                        text: "GASTO EN EFECTIVO"
                    }

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
                        texto: finanzas.datos && finanzas.datos.ocupado ? "Apuntando…" : "Apuntar gasto"
                        encendido: finanzas.conectado && finanzas.desplegado && !(finanzas.datos && finanzas.datos.ocupado)
                        onActivado: finanzas.apuntar()
                    }
                }

                // --- Los movimientos ---
                Etiqueta {
                    Layout.topMargin: 6
                    visible: finanzas.listo
                    text: "MOVIMIENTOS"
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

                Repeater {
                    model: finanzas.listo ? finanzas.datos.movimientos : []

                    delegate: RowLayout {
                        id: mov

                        required property var modelData

                        objectName: "movimiento-" + mov.modelData.id
                        Layout.fillWidth: true
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
                                text: mov.modelData.categoria !== "" ? mov.modelData.categoria : "Sin categoría"
                                color: mov.modelData.categoria !== "" ? Theme.faint : Theme.warn
                                font.family: Theme.font
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: finanzas.euros(mov.modelData.importe)
                            color: finanzas.desplegado && mov.modelData.importe > 0 ? Theme.ok : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
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
}
