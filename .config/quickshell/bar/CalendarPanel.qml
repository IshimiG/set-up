pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "shared"
import "shared/AgendaFormato.js" as Formato

// El calendario, que es lo que el reloj enseña al crecer.
//
// Antes esto era un tooltip de waybar: un bloque de texto monoespaciado con los
// colores metidos a mano en etiquetas de Pango. Se veía como un tooltip y no
// como parte del escritorio, y encima estaba ilegible, porque la cadena de temas
// heredada de Omarchy dejaba el fondo de los tooltips en blanco.
//
// Aquí la rejilla la da MonthGrid de QtQuick.Controls.Basic, que aporta el
// modelo de días —qué día cae en qué casilla, qué días son del mes de al lado—
// y deja el aspecto entero por pintar, que es justo lo que hacía falta.
//
// Con la agenda del panel del homelab (shell.agenda: las tareas con fecha de
// 00 Inicio y las entregas de Aules, lo mismo que va a Google Calendar), cada
// día con algo lleva puntos de colores, y debajo de la rejilla está la lista
// de hoy o del día que se pulse. Sin agenda, la rejilla sola.
//
// Dos gestos más, además de la rueda:
//   - El mes y el año se eligen con las flechas de la cabecera o con dos
//     desplegables (un cuadro de meses y otro de años), que se cierran al
//     pulsar fuera de ellos.
//   - Una tarea de la lista del día se arrastra a otro día de la rejilla y al
//     soltarla cambia su fecha (shell.tareas, bar/Tareas.qml, que escribe en
//     el panel del NUC). Si se arrastra sobre las flechas de la cabecera, el
//     mes pasa solo, para llevarla a otra semana o a otro mes. Si el POST
//     falla, la tarea vuelve a su día y se avisa.
Item {
    id: root

    required property var shell

    // 320 y no 300: la cabecera con flechas, mes, año y «hoy» no cabe en 300 con
    // meses largos («Septiembre»). La isla toma este ancho sola (panelW).
    implicitWidth: 320
    implicitHeight: content.implicitHeight + Theme.pad * 2

    // Qué mes se está mirando, como desplazamiento en meses respecto a hoy. La
    // rueda del ratón lo mueve, igual que hacía el módulo de waybar.
    property int monthOffset: 0

    readonly property var loc: Qt.locale("es_ES")

    readonly property date shown: {
        const d = new Date(root.shell.now);
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }

    readonly property bool onToday: root.monthOffset === 0

    // Ir a un mes y un año concretos (mes de 0 a 11).
    function irA(anio, mes) {
        const n = root.shell.now;
        root.monthOffset = (anio - n.getFullYear()) * 12 + (mes - n.getMonth());
    }

    function mover(meses) {
        root.monthOffset += meses;
    }

    function mayus(t) {
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    // --- Los desplegables de mes y año -----------------------------------------
    // "" cerrado, "mes" o "anio". La curva de abrir (rebote) y la de cerrar (sin
    // rebote, como el resto de la isla) se fijan antes de cambiar el estado.
    property string selector: ""
    // Primer año de la página de años que se enseña.
    property int anioBase: root.shown.getFullYear() - 4

    function abrirSelector(cual) {
        if (root.selector === cual) {
            root.cerrarSelector();
            return;
        }
        root.anioBase = root.shown.getFullYear() - 4;
        root.selector = cual;
    }

    function cerrarSelector() {
        root.selector = "";
    }

    // --- Arrastrar tareas -----------------------------------------------------
    // El cliente del panel (bar/Tareas.qml); null en las pruebas.
    readonly property var tareas: root.shell.tareas ?? null
    readonly property bool puedeMover: root.tareas !== null && root.tareas.puedeMover
    // La tarea que se lleva en la mano (un evento de la agenda), o null.
    property var arrastrada: null
    // Lo que se dice tras soltar: «Movida al 24 oct» o por qué no pudo ser.
    property string aviso: ""

    function avisar(texto) {
        root.aviso = texto;
        avisoReloj.restart();
    }

    function empezarArrastre(evento) {
        root.arrastrada = evento;
        ghost.titulo = evento.titulo;
        ghost.punto = root.colorTipo(Formato.tipo(evento, root.hoy));
        ghost.Drag.active = true;
    }

    function seguirArrastre(escena) {
        const q = root.mapFromItem(null, escena.x, escena.y);
        ghost.x = q.x - ghost.width / 2;
        ghost.y = q.y - ghost.height / 2;
    }

    // Suelta: el DropArea que haya debajo recibe onDropped (soltarEn) antes de
    // que esto siga; si no había ninguno, no pasa nada y la tarea se queda.
    function terminarArrastre() {
        if (ghost.Drag.active)
            ghost.Drag.drop();
        root.arrastrada = null;
    }

    function cancelarArrastre() {
        if (ghost.Drag.active)
            ghost.Drag.cancel();
        root.arrastrada = null;
    }

    function soltarEn(dia) {
        const t = root.arrastrada;
        if (!t || !root.tareas || dia === t.dia)
            return;
        root.tareas.mover(t.id, dia, ok => {
            root.avisar(ok ? "Movida al " + Formato.diaCorto(dia) : (root.tareas.error || "No se pudo mover la tarea"));
        });
    }

    // --- La agenda ----------------------------------------------------------
    // La lee bar/Agenda.qml de un fichero que deja el cajón del homelab; el
    // formato está en shared/AgendaFormato.js. null sin ella.
    readonly property var agenda: root.shell.agenda ?? null

    readonly property string hoy: Formato.claveDe(root.shell.now)

    // El día pulsado ("2026-10-23"), o "" para hoy.
    property string elegido: ""

    readonly property string diaVisto: root.elegido !== "" ? root.elegido : root.hoy

    // Lo de ese día, ordenado; el de hoy lleva delante lo vencido que sigue
    // sin hacer.
    readonly property var lista: Formato.delDia(root.agenda, root.diaVisto, root.hoy)

    // Las filas que caben; el resto se cuenta.
    readonly property int maxFilas: 6

    // Al cerrar la isla se vuelve al mes de hoy: si no, abrir el calendario
    // después de haber estado mirando marzo lo abre otra vez en marzo, que nunca
    // es lo que se quiere. Lo mismo con el día pulsado.
    Connections {
        target: root.shell
        function onModeChanged() {
            if (root.shell.mode !== "calendar") {
                root.monthOffset = 0;
                root.elegido = "";
                root.cerrarSelector();
                root.cancelarArrastre();
            } else if (root.tareas) {
                // Se lee al abrir (y solo si lo que hay es viejo), no se sondea.
                root.tareas.refrescar(false);
            }
        }
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // El número de semana ISO, que es el que daba waybar con %V. Se calcula a
    // mano porque Qt no tiene marcador de formato para él: un "ww" en la cadena
    // de formato sale tal cual, literalmente "ww".
    //
    // La regla ISO es que la semana la decide su jueves. Así que se salta al
    // jueves de la semana de la fecha dada, se hace lo mismo con el 4 de enero
    // —que por definición cae siempre en la semana 1— y se cuentan las semanas
    // entre los dos.
    function semanaISO(fecha) {
        const jueves = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate());
        jueves.setDate(jueves.getDate() + 3 - ((jueves.getDay() + 6) % 7));
        const primero = new Date(jueves.getFullYear(), 0, 4);
        primero.setDate(primero.getDate() + 3 - ((primero.getDay() + 6) % 7));
        return 1 + Math.round((jueves - primero) / (7 * 24 * 3600 * 1000));
    }

    // Pulsar un día enseña lo suyo; pulsar otra vez el mismo, o hoy, vuelve a
    // hoy.
    function elegir(dia) {
        root.elegido = dia === root.hoy || dia === root.elegido ? "" : dia;
    }

    function volverAHoy() {
        root.monthOffset = 0;
        root.elegido = "";
        root.cerrarSelector();
    }

    // El día a `n` días de hoy, como clave.
    function desdeHoy(n) {
        const d = new Date(root.shell.now);
        d.setDate(d.getDate() + n);
        return Formato.claveDe(d);
    }

    // «Hoy», «Mañana», «Ayer» o «Jueves 22 de octubre» (con el año si no es
    // este).
    function tituloDia(dia) {
        if (dia === root.hoy)
            return "Hoy";
        if (dia === root.desdeHoy(1))
            return "Mañana";
        if (dia === root.desdeHoy(-1))
            return "Ayer";
        const f = Formato.fechaDe(dia);
        if (!f)
            return "";
        const t = f.toLocaleDateString(root.loc, f.getFullYear() === root.shell.now.getFullYear() ? "dddd d 'de' MMMM" : "dddd d 'de' MMMM 'de' yyyy");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    // El color de un punto o de una fila: lo vencido en el rojo de «máxima»,
    // como en el cajón; lo hecho, apagado; el resto, el de su prioridad.
    function colorTipo(tipo) {
        if (tipo === "vencida")
            return Theme.prioMaxima;
        if (tipo === "hecha")
            return Theme.faint;
        return Theme.colorPrioridad(tipo);
    }

    // Lo que va a la derecha de una fila: cuándo venció si es de otro día, la
    // hora si la tiene, y si no, su área o su sección («Clase» en las entregas
    // de Aules).
    function etiqueta(e) {
        if (e.deAntes)
            return "venció " + Formato.diaCorto(e.dia);
        if (Formato.tipo(e, root.hoy) === "vencida")
            return "vencida";
        if (!e.todoElDia && e.hora !== "")
            return e.hora;
        return e.area !== "" ? e.area : e.seccion;
    }

    // Un botón de texto de la cabecera (el mes o el año) con su flecha de
    // desplegable.
    component Chip: Rectangle {
        id: chip

        property string texto
        property bool abierto: false
        signal pulsado

        implicitWidth: etiquetaChip.implicitWidth + 16
        implicitHeight: 24
        radius: 8
        color: Qt.rgba(1, 1, 1, chip.abierto ? 0.14 : (chipHover.hovered ? 0.08 : 0))
        border.width: chip.abierto ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.2)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            id: etiquetaChip

            anchors.centerIn: parent
            text: chip.texto + "  " + (chip.abierto ? "󰅃" : "󰅀")
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        HoverHandler {
            id: chipHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: chip.pulsado()
        }
    }

    // Una flecha de mes: pulsada cambia de mes; con una tarea encima, lo
    // cambia sola cada medio segundo.
    component Flecha: Rectangle {
        id: flecha

        property string texto
        property int paso: 1
        // Pulsada (las de paso 0 solo avisan; las de paso ±1 además cambian
        // de mes).
        signal pulsada

        implicitWidth: 24
        implicitHeight: 24
        radius: 8
        color: Qt.rgba(1, 1, 1, flecha.encima ? 0.18 : (flechaHover.hovered ? 0.08 : 0))
        readonly property bool encima: flechaDrop.containsDrag

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            anchors.centerIn: parent
            text: flecha.texto
            color: flecha.encima || flechaHover.hovered ? Theme.strong : Theme.muted
            font.family: Theme.font
            font.pixelSize: 14
        }

        HoverHandler {
            id: flechaHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                if (flecha.paso !== 0)
                    root.mover(flecha.paso);
                flecha.pulsada();
            }
        }

        DropArea {
            id: flechaDrop

            anchors.fill: parent
            keys: ["tarea"]
            enabled: root.arrastrada !== null && flecha.paso !== 0
            onContainsDragChanged: {
                if (flechaDrop.containsDrag)
                    cadencia.restart();
                else
                    cadencia.stop();
            }
        }

        Timer {
            id: cadencia

            interval: 550
            repeat: true
            onTriggered: root.mover(flecha.paso)
        }
    }

    // La rueda mueve el mes. Va en un WheelHandler y no en un MouseArea para no
    // quitarles los clics a los días, que con la agenda eligen qué día se ve.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.monthOffset += event.angleDelta.y > 0 ? -1 : 1;
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: 8

        // Cabecera: flechas, el mes y el año que se están mirando (cada uno abre
        // su desplegable) y, a la derecha, volver a hoy. Las flechas aceptan
        // también una tarea arrastrada: con ella encima, el mes pasa solo.
        RowLayout {
            id: cabecera

            Layout.fillWidth: true
            spacing: 4

            Flecha {
                objectName: "mesAnterior"
                texto: "󰅁"
                paso: -1
            }

            Chip {
                objectName: "chipMes"
                texto: root.mayus(root.loc.monthName(root.shown.getMonth(), Locale.LongFormat))
                abierto: root.selector === "mes"
                onPulsado: root.abrirSelector("mes")
            }

            Chip {
                objectName: "chipAnio"
                texto: String(root.shown.getFullYear())
                abierto: root.selector === "anio"
                onPulsado: root.abrirSelector("anio")
            }

            Flecha {
                objectName: "mesSiguiente"
                texto: "󰅂"
                paso: 1
            }

            Item {
                Layout.fillWidth: true
            }

            // Volver a hoy. Sólo aparece cuando se ha movido de mes o se ha
            // pulsado otro día, porque si no, pulsarlo no haría nada.
            Text {
                objectName: "botonHoy"
                visible: !root.onToday || root.elegido !== ""
                text: "󰄉"
                color: todayHover.hovered ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11

                HoverHandler {
                    id: todayHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.volverAHoy()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.shell.now.toLocaleDateString(root.loc, "dddd d 'de' MMMM") + "  ·  semana " + root.semanaISO(root.shell.now)
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 1
            color: Theme.rule
        }

        // Las iniciales de los días. La semana empieza en lunes porque lo dice
        // la configuración regional española, no porque se fije a mano.
        DayOfWeekRow {
            Layout.fillWidth: true
            locale: root.loc

            delegate: Text {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
            }
        }

        MonthGrid {
            id: grid

            Layout.fillWidth: true
            locale: root.loc
            month: root.shown.getMonth()
            year: root.shown.getFullYear()
            spacing: 2

            delegate: Item {
                id: cell

                required property var model

                objectName: "dia-" + cell.clave
                implicitWidth: 34
                implicitHeight: 28

                readonly property bool esHoy: root.sameDay(cell.model.date, root.shell.now)
                // Los días que MonthGrid pone para cuadrar la rejilla pero
                // pertenecen al mes de al lado.
                readonly property bool esDeFuera: cell.model.month !== grid.month
                readonly property string clave: Formato.claveDe(cell.model.date)
                // Lo que tiene el día en la agenda: un punto por cosa, tres
                // como mucho, en el orden de la lista.
                readonly property var puntos: Formato.puntos(root.agenda, cell.clave, root.hoy, 3)
                readonly property bool esElegido: root.elegido !== "" && cell.clave === root.elegido

                // El día pulsado, y el que está bajo el ratón, llevan una
                // lámina más tenue que la de hoy.
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 24
                    radius: 8
                    visible: !cell.esHoy && (cell.esElegido || hover.hovered)
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, cell.esElegido ? 0.10 : 0.05)
                    border.width: cell.esElegido ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                }

                // El día sobre el que está la tarea que se arrastra: la lámina
                // crece con rebote al entrar y se encoge sin rebote al salir.
                Rectangle {
                    id: objetivo

                    anchors.centerIn: parent
                    width: 30
                    height: 26
                    radius: 9
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.5)
                    opacity: 0
                    scale: 0.6
                    visible: opacity > 0

                    states: State {
                        name: "sobre"
                        when: dropDia.containsDrag
                        PropertyChanges {
                            objetivo.opacity: 1
                            objetivo.scale: 1.0
                        }
                    }

                    transitions: [
                        Transition {
                            to: "sobre"
                            NumberAnimation {
                                properties: "opacity,scale"
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.9
                            }
                        },
                        Transition {
                            from: "sobre"
                            NumberAnimation {
                                properties: "opacity,scale"
                                duration: 220
                                easing.type: Easing.InOutQuint
                            }
                        }
                    ]
                }

                // Hoy va marcado con una lámina de cristal, la misma que resalta
                // la fila del menú de sesión, en vez de con un color de marca.
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 24
                    radius: 8
                    visible: cell.esHoy
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.24)
                }

                Text {
                    anchors.centerIn: parent
                    // Con agenda, sube un poco para dejar sitio a los puntos;
                    // en todos los días, para que la fila no baile.
                    anchors.verticalCenterOffset: root.agenda !== null ? -2 : 0
                    text: cell.model.day
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: cell.esHoy
                    color: cell.esHoy ? Theme.strong : (cell.esDeFuera ? Qt.rgba(1, 1, 1, 0.18) : Theme.text)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    spacing: 2
                    opacity: cell.esDeFuera ? 0.45 : 1

                    Repeater {
                        model: cell.puntos

                        Rectangle {
                            required property string modelData

                            objectName: "punto"
                            width: 4
                            height: 4
                            radius: 2
                            color: root.colorTipo(modelData)
                        }
                    }
                }

                // Sin agenda los días no hacen nada al pulsarlos.
                HoverHandler {
                    id: hover
                    enabled: root.agenda !== null
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: root.agenda !== null
                    onTapped: root.elegir(cell.clave)
                }

                DropArea {
                    id: dropDia

                    anchors.fill: parent
                    keys: ["tarea"]
                    enabled: root.arrastrada !== null
                    onDropped: drop => {
                        drop.accept();
                        root.soltarEn(cell.clave);
                    }
                }
            }
        }

        // --- Lo del día -----------------------------------------------------
        ColumnLayout {
            objectName: "agendaDia"
            Layout.fillWidth: true
            visible: root.agenda !== null
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    objectName: "tituloDia"
                    text: root.tituloDia(root.diaVisto)
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                // Lo que pasó al soltar una tarea.
                Text {
                    objectName: "avisoMover"
                    Layout.maximumWidth: 170
                    elide: Text.ElideRight
                    visible: root.aviso !== ""
                    text: root.aviso
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                // El cajón la dejó sin conexión con el panel: puede no estar al
                // día.
                Text {
                    objectName: "sinConexion"
                    visible: root.aviso === "" && root.agenda !== null && !root.agenda.conectado
                    text: "sin conexión con el panel"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            // Las filas, con sitio para tres aunque haya menos: así pulsar un
            // día u otro casi nunca cambia el alto de la isla.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: 3 * 16 + 2 * 4
                spacing: 4

                Repeater {
                    model: root.lista.slice(0, root.maxFilas)

                    RowLayout {
                        id: fila

                        required property var modelData

                        readonly property string tipo: Formato.tipo(fila.modelData, root.hoy)

                        objectName: "filaAgenda"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        spacing: 8

                        readonly property bool movible: root.puedeMover && fila.modelData.id !== ""
                        readonly property bool enMano: root.arrastrada !== null && root.arrastrada.id === fila.modelData.id

                        opacity: fila.enMano ? 0.35 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                            }
                        }

                        // Arrastrar la fila lleva la tarea a otro día; la fila no
                        // se mueve (target null), lo que viaja es el fantasma.
                        HoverHandler {
                            enabled: fila.movible
                            cursorShape: dragFila.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }

                        DragHandler {
                            id: dragFila

                            enabled: fila.movible
                            target: null
                            onActiveChanged: {
                                if (dragFila.active)
                                    root.empezarArrastre(fila.modelData);
                                else
                                    root.terminarArrastre();
                            }
                            onCentroidChanged: if (dragFila.active)
                                root.seguirArrastre(dragFila.centroid.scenePosition)
                        }

                        Component.onDestruction: if (dragFila.active)
                            root.cancelarArrastre()

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: root.colorTipo(fila.tipo)
                        }

                        Text {
                            objectName: "tituloFila"
                            Layout.fillWidth: true
                            text: fila.modelData.titulo
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: fila.modelData.hecha ? Theme.faint : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.strikeout: fila.modelData.hecha
                        }

                        Text {
                            objectName: "etiquetaFila"
                            Layout.maximumWidth: 110
                            text: root.etiqueta(fila.modelData)
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: fila.tipo === "vencida" ? Theme.prioMaxima : Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }
                }

                Text {
                    objectName: "masFilas"
                    visible: root.lista.length > root.maxFilas
                    text: "y " + (root.lista.length - root.maxFilas) + " más"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                Text {
                    objectName: "diaVacio"
                    visible: root.lista.length === 0
                    text: root.diaVisto === root.hoy ? "Nada para hoy" : "Nada para este día"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }

    Timer {
        id: avisoReloj
        interval: 3500
        onTriggered: root.aviso = ""
    }

    // --- Los desplegables de mes y año -----------------------------------------
    // Pulsar fuera de ellos (pero dentro del calendario) los cierra; pulsar
    // fuera de la isla la cierra entera, como siempre.
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: content.y + cabecera.y + cabecera.height
        z: 4
        enabled: root.selector !== ""
        onPressed: root.cerrarSelector()
    }

    Rectangle {
        id: popup

        objectName: "selector"
        z: 5
        x: Theme.pad
        y: content.y + cabecera.y + cabecera.height + 6
        width: root.width - Theme.pad * 2
        implicitHeight: popupContenido.implicitHeight + 16
        height: implicitHeight
        radius: 12
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        opacity: 0
        scale: 0.9
        transformOrigin: Item.Top
        visible: opacity > 0

        states: State {
            name: "abierto"
            when: root.selector !== ""
            PropertyChanges {
                popup.opacity: 1
                popup.scale: 1.0
            }
        }

        // Abre con rebote, cierra sin él (el vocabulario de la isla).
        transitions: [
            Transition {
                to: "abierto"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.9
                }
            },
            Transition {
                from: "abierto"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 200
                    easing.type: Easing.InOutQuint
                }
            }
        ]

        // Se come los clics para que no lleguen a los días de debajo.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: popupContenido

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6

            // Para los años: paginar de doce en doce.
            RowLayout {
                Layout.fillWidth: true
                visible: root.selector === "anio"
                spacing: 4

                Flecha {
                    texto: "󰅁"
                    paso: 0
                    onPulsada: root.anioBase -= 12
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.anioBase + " – " + (root.anioBase + 11)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Flecha {
                    texto: "󰅂"
                    paso: 0
                    onPulsada: root.anioBase += 12
                }
            }

            GridLayout {
                columns: 4
                rowSpacing: 4
                columnSpacing: 4
                Layout.fillWidth: true

                Repeater {
                    model: 12

                    Rectangle {
                        id: opcion

                        required property int index

                        readonly property int valor: root.selector === "mes" ? opcion.index : root.anioBase + opcion.index
                        readonly property bool actual: root.selector === "mes" ? opcion.valor === root.shown.getMonth() : opcion.valor === root.shown.getFullYear()
                        readonly property bool deHoy: root.selector === "mes" ? (root.shown.getFullYear() === root.shell.now.getFullYear() && opcion.valor === root.shell.now.getMonth()) : opcion.valor === root.shell.now.getFullYear()

                        objectName: "opcionSelector"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 30
                        radius: 8
                        color: Qt.rgba(1, 1, 1, opcion.actual ? 0.16 : (opcionHover.hovered ? 0.08 : 0))
                        border.width: opcion.actual ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.28)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.selector === "mes" ? root.mayus(root.loc.monthName(opcion.valor, Locale.ShortFormat)).replace(".", "") : String(opcion.valor)
                            color: opcion.actual ? Theme.strong : (opcion.deHoy ? Theme.text : Theme.muted)
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: opcion.actual || opcion.deHoy
                        }

                        HoverHandler {
                            id: opcionHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                if (root.selector === "mes")
                                    root.irA(root.shown.getFullYear(), opcion.valor);
                                else
                                    root.irA(opcion.valor, root.shown.getMonth());
                                root.cerrarSelector();
                            }
                        }
                    }
                }
            }
        }
    }

    // --- La tarea que se lleva en la mano ---------------------------------------
    // Un fantasma de cristal que sigue al puntero; al soltarlo, el DropArea de
    // la casilla de debajo recibe el drop. Sin soltar sobre un día, se funde.
    Rectangle {
        id: ghost

        property string titulo: ""
        property color punto: Theme.text

        objectName: "fantasma"
        z: 20
        width: Math.min(190, fantasmaTexto.implicitWidth + 32)
        height: 24
        radius: 9
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.3)
        opacity: 0
        scale: 0.8
        visible: opacity > 0

        Drag.keys: ["tarea"]
        Drag.hotSpot.x: ghost.width / 2
        Drag.hotSpot.y: ghost.height / 2

        states: State {
            name: "llevado"
            when: root.arrastrada !== null
            PropertyChanges {
                ghost.opacity: 0.96
                ghost.scale: 1.0
            }
        }

        transitions: [
            Transition {
                to: "llevado"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.9
                }
            },
            Transition {
                from: "llevado"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 200
                    easing.type: Easing.InOutQuint
                }
            }
        ]

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: ghost.punto
        }

        Text {
            id: fantasmaTexto

            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: ghost.titulo
            elide: Text.ElideRight
            textFormat: Text.PlainText
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
