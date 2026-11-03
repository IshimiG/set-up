pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "shared"
import "MarkdownLogica.js" as Logica

// Los bloques de una nota (MarkdownLogica.bloques), uno debajo de otro, como
// el cuerpo de la página de nota de la web. Lo pinta Notas.qml. Las citas, los
// avisos de Obsidian y las listas llevan otros bloques dentro, que se pintan
// con este mismo fichero a través de un Loader (un tipo de QML no puede
// contenerse a sí mismo). Nada de aquí interpreta el texto de la nota: llega
// ya escapado (NotaTexto) o va tal cual, como texto plano (el código).
Column {
    id: raiz

    required property var bloques
    // Notas.qml: enlace(href) y desplegado.
    required property var ctrl
    // Las listas que hay por encima: el punto cambia con cada nivel. (Lo hondo
    // que puede ir una nota ya lo corta MarkdownLogica.)
    property int listas: 0
    // Dentro de una cita, el texto va atenuado (como en la web).
    property bool tenue: false

    spacing: 10

    readonly property url este: Qt.resolvedUrl("NotaBloques.qml")

    // Los bloques de dentro de una cita, un aviso o un elemento de lista.
    function cargarDentro(cargador, bloques, tenue, listas) {
        if (bloques && bloques.length)
            cargador.setSource(raiz.este, {
                bloques: bloques,
                ctrl: raiz.ctrl,
                listas: listas,
                tenue: tenue
            });
    }

    // El glifo de un aviso de Obsidian por su tipo (> [!tipo]); los colores,
    // los de siempre (sin color: es un recuadro, no una alerta).
    function glifoAviso(clase) {
        switch (clase) {
        case "tip":
        case "hint":
        case "important":
            return "";
        case "success":
        case "check":
        case "done":
            return "";
        case "question":
        case "help":
        case "faq":
            return "";
        case "warning":
        case "caution":
        case "attention":
            return "";
        case "failure":
        case "fail":
        case "missing":
        case "danger":
        case "error":
        case "bug":
            return "";
        case "example":
            return "";
        case "quote":
        case "cite":
            return "";
        case "todo":
            return "";
        default:
            return "";
        }
    }

    Repeater {
        model: raiz.bloques

        delegate: Loader {
            id: bloque

            required property var modelData
            required property int index
            readonly property var b: bloque.modelData

            width: raiz.width
            sourceComponent: {
                switch (bloque.b.tipo) {
                case "cabecera":
                    return cabecera;
                case "codigo":
                    return codigo;
                case "raya":
                    return raya;
                case "cita":
                    return cita;
                case "aviso":
                    return aviso;
                case "tabla":
                    return tabla;
                case "lista":
                    return lista;
                default:
                    return parrafo;
                }
            }

            Component {
                id: parrafo

                NotaTexto {
                    objectName: "parrafoNota"
                    ctrl: raiz.ctrl
                    trozo: bloque.b.texto
                    color: raiz.tenue ? Theme.muted : Theme.text
                }
            }

            // Las cabeceras, de más a menos: la 1 y la 2 grandes, la 3 en
            // negrita y de ahí abajo, como el texto pero en negrita.
            Component {
                id: cabecera

                NotaTexto {
                    objectName: "cabeceraNota"
                    ctrl: raiz.ctrl
                    trozo: bloque.b.texto
                    clave: bloque.b.clave
                    topPadding: bloque.index > 0 ? 8 : 0
                    color: bloque.b.nivel <= 3 ? Theme.strong : Theme.text
                    font.pixelSize: bloque.b.nivel === 1 ? 17 : (bloque.b.nivel === 2 ? 15 : (bloque.b.nivel === 3 ? 13 : 12))
                    font.bold: bloque.b.nivel >= 3
                }
            }

            // El código, tal cual (texto plano), partido donde haga falta: el
            // cajón es estrecho.
            Component {
                id: codigo

                Rectangle {
                    objectName: "codigoNota"
                    implicitHeight: textoCodigo.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        id: textoCodigo

                        x: 10
                        y: 8
                        width: parent.width - 20
                        text: raiz.ctrl.desplegado ? bloque.b.codigo.texto : bloque.b.codigo.oculto
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }

            Component {
                id: raya

                Item {
                    implicitHeight: 9

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.rule
                    }
                }
            }

            Component {
                id: cita

                Item {
                    objectName: "citaNota"
                    implicitHeight: dentroCita.implicitHeight

                    Rectangle {
                        width: 2
                        height: parent.height
                        radius: 1
                        color: Theme.rule
                    }

                    Loader {
                        id: dentroCita

                        x: 14
                        width: parent.width - 14
                        Component.onCompleted: raiz.cargarDentro(dentroCita, bloque.b.bloques, true, raiz.listas)
                    }
                }
            }

            Component {
                id: aviso

                Rectangle {
                    objectName: "avisoNota"
                    implicitHeight: pilaAviso.implicitHeight + 20
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Theme.rule

                    // La barra de la izquierda, como la de las alertas.
                    Rectangle {
                        x: 9
                        y: 10
                        width: 3
                        height: parent.height - 20
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.3)
                    }

                    Column {
                        id: pilaAviso

                        x: 22
                        y: 10
                        width: parent.width - 34
                        spacing: 6

                        Row {
                            width: pilaAviso.width
                            spacing: 7

                            Text {
                                id: glifo

                                y: 1
                                text: raiz.glifoAviso(bloque.b.clase)
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }

                            NotaTexto {
                                objectName: "tituloAvisoNota"
                                width: pilaAviso.width - glifo.width - 7
                                ctrl: raiz.ctrl
                                trozo: bloque.b.titulo
                                color: Theme.strong
                                font.bold: true
                            }
                        }

                        Loader {
                            id: dentroAviso

                            width: pilaAviso.width
                            visible: bloque.b.bloques.length > 0
                            Component.onCompleted: raiz.cargarDentro(dentroAviso, bloque.b.bloques, false, raiz.listas)
                        }
                    }
                }
            }

            // Las tablas, con el ancho repartido entre las columnas como en un
            // navegador (MarkdownLogica.anchosColumnas): lo que no cabe se
            // parte. Si son tantas que ni así caben, la tabla se desliza de lado,
            // sola (y la rueda sigue moviendo la página).
            Component {
                id: tabla

                Flickable {
                    id: caja

                    objectName: "tablaNota"
                    // La letra es de ancho fijo: lo que ocupa cada columna sin partir
                    // sale de sus caracteres.
                    readonly property var anchos: Logica.anchosColumnas(bloque.b.largos.map(n => Math.ceil(n * medida.averageCharacterWidth) + 19), caja.width, 72)
                    readonly property var celdas: {
                        const l = bloque.b.cabeza.map((t, c) => ({
                                    t: t,
                                    c: c,
                                    cabeza: true
                                }));
                        for (const f of bloque.b.filas)
                            f.forEach((t, c) => l.push({
                                    t: t,
                                    c: c,
                                    cabeza: false
                                }));
                        return l;
                    }

                    implicitHeight: rejilla.implicitHeight
                    contentWidth: rejilla.width
                    contentHeight: rejilla.implicitHeight
                    interactive: rejilla.implicitWidth > caja.width + 1
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    FontMetrics {
                        id: medida

                        font.family: Theme.font
                        font.pixelSize: 11
                        font.bold: true
                    }

                    GridLayout {
                        id: rejilla

                        width: rejilla.implicitWidth
                        columns: bloque.b.columnas
                        rowSpacing: 0
                        columnSpacing: 0

                        Repeater {
                            model: caja.celdas

                            delegate: Rectangle {
                                id: celda

                                required property var modelData

                                objectName: celda.modelData.cabeza ? "cabezaTablaNota" : "celdaNota"
                                Layout.fillHeight: true
                                Layout.preferredWidth: caja.anchos[celda.modelData.c] || 0
                                implicitHeight: textoCelda.implicitHeight + 12
                                color: celda.modelData.cabeza ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                                NotaTexto {
                                    id: textoCelda

                                    x: 9
                                    y: 6
                                    width: celda.width - 18
                                    ctrl: raiz.ctrl
                                    trozo: celda.modelData.t
                                    color: celda.modelData.cabeza ? Theme.muted : (raiz.tenue ? Theme.muted : Theme.text)
                                    font.pixelSize: 11
                                    font.bold: celda.modelData.cabeza
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: Theme.rule
                                }
                            }
                        }
                    }
                }
            }

            // Las listas: el punto (o el número, o la casilla de una tarea,
            // que aquí sólo se mira) y, debajo de cada elemento, lo que lleve
            // sangrado.
            Component {
                id: lista

                Column {
                    id: columnaLista

                    objectName: "listaNota"
                    spacing: 5

                    Repeater {
                        model: bloque.b.items

                        delegate: Item {
                            id: elemento

                            required property var modelData
                            readonly property bool tarea: elemento.modelData.tarea !== null
                            readonly property bool hecha: elemento.modelData.tarea === true

                            objectName: "elementoNota"
                            width: columnaLista.width
                            implicitHeight: Math.max(16, pilaElemento.implicitHeight)

                            Text {
                                visible: !elemento.tarea
                                width: 16
                                horizontalAlignment: Text.AlignRight
                                text: bloque.b.ordenada ? elemento.modelData.marca : (raiz.listas % 2 ? "◦" : "•")
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: bloque.b.ordenada ? 11 : 12
                                lineHeight: 1.2
                            }

                            Rectangle {
                                objectName: "casillaNota"
                                visible: elemento.tarea
                                x: 2
                                y: 2
                                width: 13
                                height: 13
                                radius: 4
                                color: "transparent"
                                border.width: 1.5
                                border.color: elemento.hecha ? Theme.text : Theme.faint

                                Text {
                                    anchors.centerIn: parent
                                    visible: elemento.hecha
                                    text: "✓"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }
                            }

                            Column {
                                id: pilaElemento

                                x: 22
                                width: parent.width - 22
                                spacing: 5

                                NotaTexto {
                                    width: pilaElemento.width
                                    ctrl: raiz.ctrl
                                    trozo: elemento.modelData.texto
                                    color: elemento.hecha || raiz.tenue ? Theme.muted : Theme.text
                                }

                                Loader {
                                    id: dentroElemento

                                    width: pilaElemento.width
                                    visible: elemento.modelData.bloques.length > 0
                                    Component.onCompleted: raiz.cargarDentro(dentroElemento, elemento.modelData.bloques, raiz.tenue, raiz.listas + 1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
