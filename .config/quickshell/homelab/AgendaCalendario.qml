// El calendario del cajón: un mes en cuadrícula, con las tareas abiertas que
// tienen fecha, para verlas y también para moverlas. (Agenda.qml no es esto:
// es lo que deja el cajón en un fichero para el calendario de la barra.)
//   - Arrastrar una tarea (por su asa) a un día le pone esa fecha; a la
//     etiqueta de semana de la izquierda («S44»), la pasa a esa semana
//     conservando el día de la semana. Sirve el asa de la lista de Tareas y la
//     de las tareas del día elegido, aquí debajo.
//   - Mes y año: flechas, el desplegable del título (mes y año) y la rueda del
//     ratón sobre la cuadrícula.
//   - Clic fuera del desplegable lo cierra.

import QtQuick
import QtQuick.Layouts
import "TareasLogica.js" as Logica
import "shared"

// Lo que sobrevive a repintar (qué mes se mira, qué día está elegido) vive en
// Tareas.qml (ctrl), que puede tener dos calendarios (compacto y amplio).
Item {
    id: cal

    required property var ctrl
    // "compacto" | "medio" | "amplio", de Contenido vía Tareas.
    property string modo: "compacto"
    // Los días con tareas: { "2026-10-30": [entrada] }.
    readonly property var dias: Logica.porDia(cal.ctrl.todas)
    readonly property var celdas: Logica.cuadricula(cal.ctrl.calAnio, cal.ctrl.calMes)
    readonly property real lado: Math.max(1, Math.floor((cal.width - 26) / 7))
    readonly property var delDia: cal.dias[cal.ctrl.calDia] || []
    property bool selector: false
    // Año que se mira en el desplegable, sin tocar el calendario hasta elegir mes.
    property int anioSelector: cal.ctrl.calAnio
    // El rebote al cambiar de mes.
    property real desfase: 0
    property real giroRueda: 0
    property int indiceMes: cal.ctrl.calAnio * 12 + cal.ctrl.calMes
    property int previoMes: cal.indiceMes

    function nombreMes() {
        const n = Logica.MESES_LARGOS[cal.ctrl.calMes - 1];
        return n.charAt(0).toUpperCase() + n.slice(1) + " " + cal.ctrl.calAnio;
    }

    function abrirSelector() {
        cal.anioSelector = cal.ctrl.calAnio;
        const p = cal.mapToItem(cal.ctrl, 8, 34);
        tarjetaSel.x = Math.max(0, Math.min(cal.ctrl.width - tarjetaSel.width, p.x));
        tarjetaSel.y = p.y;
        cal.selector = true;
    }

    implicitHeight: pila.implicitHeight
    onIndiceMesChanged: {
        const dir = cal.indiceMes > cal.previoMes ? 1 : -1;
        cal.previoMes = cal.indiceMes;
        resorte.stop();
        resorte.from = dir * 30;
        resorte.start();
    }

    NumberAnimation {
        id: resorte

        target: cal
        property: "desfase"
        to: 0
        duration: Theme.animIn
        easing.type: Easing.OutBack
        easing.overshoot: Theme.overshootIn
    }

    ColumnLayout {
        id: pila

        width: parent.width
        spacing: 6

        // Cabecera: flechas, título con desplegable, hoy.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Chip {
                objectName: "mesAnterior"
                glifo: ""
                implicitWidth: 30
                onActivado: cal.ctrl.cambiarMes(-1)
            }

            Chip {
                objectName: "tituloMes"
                Layout.fillWidth: true
                texto: cal.nombreMes() + "  "
                activo: cal.selector
                onActivado: cal.selector ? cal.selector = false : cal.abrirSelector()
            }

            Chip {
                objectName: "mesSiguiente"
                glifo: ""
                implicitWidth: 30
                onActivado: cal.ctrl.cambiarMes(1)
            }

            Chip {
                objectName: "mesHoy"
                texto: "Hoy"
                onActivado: cal.ctrl.irAHoy()
            }

        }

        // La cuadrícula: la rueda cambia de mes.
        Item {
            id: zona

            Layout.fillWidth: true
            implicitHeight: 16 + rejilla.implicitHeight + 4
            clip: true

            // Solo la rueda: el clic sigue siendo de las celdas de debajo.
            MouseArea {
                objectName: "ruedaMes"
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                z: 5
                onWheel: wheel => {
                    cal.giroRueda += wheel.angleDelta.y;
                    if (Math.abs(cal.giroRueda) >= 120) {
                        cal.ctrl.cambiarMes(cal.giroRueda > 0 ? -1 : 1);
                        cal.giroRueda = 0;
                    }
                }
            }

            // Los días de la semana.
            Row {
                x: 26
                spacing: 0

                Repeater {
                    model: Logica.DIAS_CORTOS

                    delegate: Text {
                        required property string modelData

                        width: cal.lado
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                    }

                }

            }

            Column {
                id: rejilla

                y: 16
                spacing: 0

                Repeater {
                    // Cada fila: la etiqueta de semana y sus siete días.
                    model: 6

                    delegate: Row {
                        id: filaSemana

                        required property int index
                        readonly property string lunes: cal.celdas[index * 7].fecha
                        readonly property bool aqui: semana.containsDrag

                        Item {
                            width: 26
                            height: cal.lado

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 7
                                color: semana.containsDrag ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
                                scale: semana.containsDrag ? 1.12 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "S" + Logica.semanaIso(filaSemana.lunes)
                                    color: semana.containsDrag ? Theme.strong : Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: semana.containsDrag ? Theme.animIn : Theme.animOut
                                        easing.type: semana.containsDrag ? Easing.OutBack : Easing.InBack
                                        easing.overshoot: Theme.overshootIn
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }

                                }

                            }

                            DropArea {
                                id: semana

                                objectName: "semana-" + filaSemana.lunes
                                anchors.fill: parent
                                keys: ["tarea"]
                                onDropped: (drop) => {
                                    const t = cal.ctrl.arrastrada;
                                    if (t)
                                        cal.ctrl.soltarSobre({
                                        "fecha": Logica.mismoDiaEnSemana(t.vence || cal.ctrl.hoy, filaSemana.lunes)
                                    });

                                }
                            }

                        }

                        Repeater {
                            model: 7

                            delegate: Item {
                                id: celda

                                required property int index
                                readonly property var c: cal.celdas[filaSemana.index * 7 + index]
                                readonly property var tareasDia: cal.dias[c.fecha] || []
                                readonly property bool hoy: c.fecha === cal.ctrl.hoy
                                readonly property bool elegido: c.fecha === cal.ctrl.calDia

                                objectName: "dia-" + c.fecha
                                width: cal.lado
                                height: cal.lado

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 8
                                    color: celda.elegido ? Qt.rgba(1, 1, 1, 0.16) : (dia.containsDrag ? Qt.rgba(1, 1, 1, 0.24) : (sobre.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, celda.c.delMes ? 0.04 : 0.015)))
                                    border.width: celda.hoy || dia.containsDrag ? 1 : 0
                                    border.color: dia.containsDrag ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.4)
                                    scale: dia.containsDrag ? 1.14 : 1
                                    z: dia.containsDrag ? 2 : 0

                                    Text {
                                        x: 5
                                        y: 3
                                        text: celda.c.dia
                                        color: celda.hoy ? Theme.strong : (celda.c.delMes ? Theme.text : Theme.faint)
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                        font.bold: celda.hoy
                                    }

                                    // Hasta tres puntos con el color de la prioridad, y la cuenta si hay más.
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 5
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 5
                                        spacing: 3

                                        Repeater {
                                            model: celda.tareasDia.slice(0, 3)

                                            delegate: Rectangle {
                                                required property var modelData

                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: Theme.colorPrioridad(modelData.pausa ? "pausa" : modelData.efectiva)
                                            }

                                        }

                                        Text {
                                            visible: celda.tareasDia.length > 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "+" + (celda.tareasDia.length - 3)
                                            color: Theme.muted
                                            font.family: Theme.font
                                            font.pixelSize: 8
                                        }

                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: dia.containsDrag ? Theme.animIn : Theme.animOut
                                            easing.type: dia.containsDrag ? Easing.OutBack : Easing.InBack
                                            easing.overshoot: Theme.overshootIn
                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 140
                                        }

                                    }

                                }

                                HoverHandler {
                                    id: sobre

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: cal.ctrl.calDia = celda.c.fecha
                                }

                                DropArea {
                                    id: dia

                                    anchors.fill: parent
                                    keys: ["tarea"]
                                    onDropped: (drop) => {
                                        return cal.ctrl.soltarSobre({
                                            "fecha": celda.c.fecha
                                        });
                                    }
                                }

                            }

                        }

                    }

                }

                transform: Translate {
                    x: cal.desfase
                }

            }

        }

        // Las tareas del día elegido, arrastrables a otro día.
        Text {
            Layout.fillWidth: true
            objectName: "tituloDia"
            text: cal.ctrl.calDia === "" ? "" : Logica.fechaCorta(cal.ctrl.calDia) + (cal.delDia.length ? "" : " · nada con fecha")
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
            font.letterSpacing: 1.2
        }

        Repeater {
            model: cal.delDia.slice(0, 6)

            delegate: Rectangle {
                id: item

                required property var modelData

                objectName: "tareaDelDia"
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 6

                    AsaArrastre {
                        t: item.modelData
                        ctrl: cal.ctrl
                    }

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: Theme.colorPrioridad(item.modelData.pausa ? "pausa" : item.modelData.efectiva)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: item.modelData.plano
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                }

            }

        }

        Text {
            visible: cal.delDia.length > 6
            text: "y " + (cal.delDia.length - 6) + " más"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10
        }

    }

    // --- El desplegable de mes y año, fuera del calendario para que quede por
    // encima de todo; el velo de detrás lo cierra con un clic fuera. ---
    Item {
        id: velo

        parent: cal.ctrl
        anchors.fill: parent
        z: 59
        visible: cal.selector

        MouseArea {
            anchors.fill: parent
            onClicked: cal.selector = false
        }

    }

    Rectangle {
        id: tarjetaSel

        objectName: "selectorMes"
        parent: cal.ctrl
        z: 60
        width: 264
        height: cuerpoSel.implicitHeight + 24
        radius: 14
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        transformOrigin: Item.TopLeft
        visible: opacity > 0.01
        opacity: cal.selector ? 1 : 0
        scale: cal.selector ? 1 : 0.7

        // Lo que no es un botón se come el clic, para que no llegue al velo.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: cuerpoSel

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Chip {
                    objectName: "anioAnterior"
                    glifo: ""
                    implicitWidth: 30
                    onActivado: cal.anioSelector--
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: cal.anioSelector
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                }

                Chip {
                    objectName: "anioSiguiente"
                    glifo: ""
                    implicitWidth: 30
                    onActivado: cal.anioSelector++
                }

            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Logica.MESES_LARGOS

                    delegate: Chip {
                        required property int index
                        required property string modelData

                        objectName: "elegirMes-" + (index + 1)
                        width: Math.floor((cuerpoSel.width - 12) / 3)
                        texto: modelData.substring(0, 3)
                        activo: cal.anioSelector === cal.ctrl.calAnio && index + 1 === cal.ctrl.calMes
                        onActivado: {
                            cal.ctrl.irAMes(cal.anioSelector, index + 1);
                            cal.selector = false;
                        }
                    }

                }

            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: cal.selector ? Theme.animIn : Theme.animOut
                easing.type: cal.selector ? Easing.OutBack : Easing.InBack
                easing.overshoot: cal.selector ? Theme.overshootIn : Theme.overshootOut
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }

        }

    }

}
