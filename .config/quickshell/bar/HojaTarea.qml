pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "shared"
import "shared/AgendaFormato.js" as Formato

// La hoja de una tarea del calendario de la isla: crear una (doble clic en un
// día) o editarla (pulsar su título en la lista del día). CalendarPanel la
// pone en el sitio de la lista mientras está abierta, y nunca hay dos.
//
//   Nueva tarea                              vie 30 oct  ✕
//   [ Título                                            ]
//   Todo el día  (●  )               De [09:00] a [10:00]
//   Prioridad  ● ● ◉ ● ●  Media                         󱚧
//   Categoría  (● General) (● Homelab) (● Otro proyecto)
//   [Eliminar] (por qué no se puede guardar)   [Cancelar] [Guardar]
//
// Las horas solo se ven, y solo cuentan, sin «Todo el día». La prioridad
// elegida, pulsada otra vez, se quita. La categoría es la sección de la tarea
// en el panel: un chip por cada una (con su color; si no caben en una línea,
// pasan a la siguiente), siempre con una elegida (al crear, la de siempre; al
// editar, la de la tarea, y si es una que no se ofrece, como En pausa,
// ninguna hasta que se pulse otra). Sin categorías que ofrecer (las entregas
// de Aules son de solo lectura) la fila no sale. «Eliminar» solo está al editar una
// tarea que se puede borrar (no las de Aules); la primera pulsación pide
// confirmación («¿Eliminar?»), la segunda emite eliminar, y la confirmación
// se retira sola a los 4 s o al tocar cualquier otra cosa.
//
// Solo pinta y valida: lo que se manda al panel lo decide CalendarPanel con
// lo que sale por guardar(). Intro guarda desde cualquier campo, Escape
// cancela. No deja guardar lo que el panel rechazaría (sin título, una hora
// que no es hh:mm, un fin que no va después del inicio) y dice por qué.
FocusScope {
    id: hoja

    // "nueva" o "editar".
    required property string modo
    // El día de la tarea, "2026-10-30".
    required property string dia
    // Con qué se abre: { texto, horaInicio y horaFin ("HH:MM", o "" las dos:
    // todo el día), prioridad (la
    // del panel, de "highest" a "lowest", o ""), claudeOff, seccion (el id de
    // la categoría) }.
    required property var inicial
    // Las cinco prioridades, de la más alta a la más baja: { valor, nombre,
    // etiqueta } (las de CalendarPanel).
    required property var prioridades
    // Las categorías que se ofrecen: { id, nombre, color ("#rrggbb" o "") },
    // en el orden del panel (Tareas.categorias). Vacía: sin la fila.
    property var categorias: []
    // Esperando al panel: no se toca nada.
    property bool ocupada: false
    // Lo que contestó el panel al no aceptarla, o "".
    property string error: ""
    // Hay panel al que mandarla.
    property bool conPanel: true
    // Se puede borrar (y se enseña «Eliminar»): editando, y no una de Aules.
    property bool borrable: false

    // valores: { texto, horaInicio, horaFin, prioridad, claudeOff, seccion }.
    signal guardar(var valores)
    // Confirmado «Eliminar».
    signal eliminar
    signal cancelar
    // Algo ha cambiado (para que se vaya el error del panel).
    signal tocada

    // Lo que se está editando. El texto y las horas están en sus campos.
    property bool todoElDia: true
    // Esperando la segunda pulsación de «Eliminar».
    property bool confirmando: false
    property string prioridad: ""
    property bool claudeOff: false
    // El id de la categoría elegida.
    property string seccion: ""
    // Se ha intentado guardar: desde entonces se dice también si falta el
    // título (antes no, que una hoja recién abierta no es un error).
    property bool intentado: false

    readonly property string texto: campoTitulo.text.replace(/\s+/g, " ").trim()
    readonly property string horaInicio: hoja.todoElDia ? "" : Formato.normalizarHora(campoInicio.text)
    readonly property string horaFin: hoja.todoElDia ? "" : Formato.normalizarHora(campoFin.text)
    readonly property string motivoHoras: Formato.motivoHoras(hoja.horaInicio, hoja.horaFin)
    readonly property bool inicioMal: !hoja.todoElDia && !/^([01]\d|2[0-3]):[0-5]\d$/.test(hoja.horaInicio)
    readonly property bool finMal: !hoja.todoElDia && !hoja.inicioMal && hoja.motivoHoras !== ""
    // Por qué no se puede guardar, o "".
    readonly property string motivo: hoja.texto === "" ? "Falta el título" : hoja.motivoHoras
    readonly property bool sePuede: hoja.motivo === "" && !hoja.ocupada && hoja.conPanel
    // Lo que se lee abajo, a la izquierda de los botones: lo que dijo el
    // panel, lo que está mal o que no hay panel.
    readonly property string aviso: hoja.error !== "" ? hoja.error : hoja.motivoHoras !== "" ? hoja.motivoHoras : hoja.intentado && hoja.texto === "" ? "Falta el título" : !hoja.conPanel && !hoja.ocupada ? "Sin conexión con el panel" : ""

    readonly property string nombrePrioridad: (hoja.prioridades.find(p => p.valor === hoja.prioridad) || {
            etiqueta: "Sin prioridad"
        }).etiqueta

    readonly property var diasSemana: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]

    implicitHeight: columna.implicitHeight

    Component.onCompleted: {
        const i = hoja.inicial || {};
        campoTitulo.text = String(i.texto || "");
        hoja.todoElDia = !i.horaInicio;
        campoInicio.text = i.horaInicio || "09:00";
        campoFin.text = i.horaFin || Formato.sumarMinutos(campoInicio.text, 60);
        hoja.prioridad = String(i.prioridad || "");
        hoja.claudeOff = i.claudeOff === true;
        hoja.seccion = String(i.seccion || "");
    }

    function enfocar() {
        campoTitulo.forceActiveFocus();
        campoTitulo.cursorPosition = campoTitulo.text.length;
    }

    function intentar() {
        hoja.intentado = true;
        if (!hoja.sePuede)
            return;
        const v = {
            texto: hoja.texto,
            horaInicio: hoja.horaInicio,
            horaFin: hoja.horaFin,
            prioridad: hoja.prioridad,
            claudeOff: hoja.claudeOff,
            seccion: hoja.seccion
        };
        // Lo que se manda, tal cual se ve («9» se queda en «09:00»).
        if (!hoja.todoElDia) {
            campoInicio.text = v.horaInicio;
            campoFin.text = v.horaFin;
        }
        hoja.guardar(v);
    }

    function diaLegible() {
        const f = Formato.fechaDe(hoja.dia);
        return f ? hoja.diasSemana[f.getDay()] + " " + Formato.diaCorto(hoja.dia) : "";
    }

    onTodoElDiaChanged: {
        hoja.confirmando = false;
        hoja.tocada();
    }
    onConfirmandoChanged: if (hoja.confirmando)
        confirmacion.restart()
    onPrioridadChanged: {
        hoja.confirmando = false;
        hoja.tocada();
    }
    onClaudeOffChanged: {
        hoja.confirmando = false;
        hoja.tocada();
    }
    onSeccionChanged: {
        hoja.confirmando = false;
        hoja.tocada();
    }

    Timer {
        id: confirmacion
        interval: 4000
        onTriggered: hoja.confirmando = false
    }

    function pedirEliminar() {
        if (!hoja.borrable || hoja.ocupada || !hoja.conPanel)
            return;
        if (!hoja.confirmando) {
            hoja.confirmando = true;
            return;
        }
        hoja.confirmando = false;
        hoja.eliminar();
    }

    // Intro guarda y Escape cancela, estén donde estén (los campos de texto
    // dejan pasar las dos teclas). Escape no llega así a la isla, que se
    // cerraría entera.
    Keys.onReturnPressed: event => {
        event.accepted = true;
        hoja.intentar();
    }
    Keys.onEnterPressed: event => {
        event.accepted = true;
        hoja.intentar();
    }
    Keys.onEscapePressed: event => {
        event.accepted = true;
        hoja.cancelar();
    }

    // Sale con el rebote de lo que aparece en la isla.
    opacity: 0
    scale: 0.96
    transformOrigin: Item.Top
    ParallelAnimation {
        running: true
        NumberAnimation {
            target: hoja
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: hoja
            property: "scale"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.9
        }
    }

    // --- Piezas ---------------------------------------------------------------

    // Un campo de texto con su lámina, como la de la isla.
    component Caja: Rectangle {
        id: caja

        property bool enfocada: false
        property bool mal: false

        radius: 8
        color: Qt.rgba(1, 1, 1, caja.enfocada ? 0.09 : 0.05)
        border.width: 1
        border.color: caja.mal ? Qt.rgba(Theme.prioMaxima.r, Theme.prioMaxima.g, Theme.prioMaxima.b, 0.7) : caja.enfocada ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule
        clip: true

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    // Un campo de hora, hh:mm. Al entrar se selecciona todo, para teclear
    // encima; al salir (o con Intro) se deja escrito como hh:mm si se
    // entiende. Las flechas arriba y abajo la mueven un cuarto de hora.
    component CampoHora: Caja {
        id: campoHora

        property alias text: entrada.text
        property alias entrada: entrada
        signal terminado

        implicitWidth: 50
        implicitHeight: 24
        enfocada: entrada.activeFocus

        TextInput {
            id: entrada

            anchors.fill: parent
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            maximumLength: 5
            validator: RegularExpressionValidator {
                regularExpression: /^\d{0,2}:?\d{0,2}$/
            }
            inputMethodHints: Qt.ImhPreferNumbers
            activeFocusOnTab: true
            readOnly: hoja.ocupada
            selectByMouse: true
            color: Theme.strong
            selectionColor: Qt.rgba(1, 1, 1, 0.3)
            selectedTextColor: Theme.strong
            font.family: Theme.font
            font.pixelSize: 11

            onActiveFocusChanged: if (entrada.activeFocus)
                entrada.selectAll()
            onTextChanged: hoja.tocada()
            onEditingFinished: {
                entrada.text = Formato.normalizarHora(entrada.text);
                campoHora.terminado();
            }
            Keys.onUpPressed: event => {
                event.accepted = true;
                const h = Formato.sumarMinutos(Formato.normalizarHora(entrada.text), 15);
                if (h !== "")
                    entrada.text = h;
            }
            Keys.onDownPressed: event => {
                event.accepted = true;
                const h = Formato.sumarMinutos(Formato.normalizarHora(entrada.text), -15);
                if (h !== "")
                    entrada.text = h;
            }
        }
    }

    // Un punto que se elige: una prioridad. Elegido lleva un aro.
    component Punto: Item {
        id: punto

        property color tinta: Theme.text
        property bool elegido: false
        property string nombre: ""
        signal pulsado

        implicitWidth: 20
        implicitHeight: 20

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 1.5
            border.color: Theme.strong
            visible: punto.elegido
        }

        Rectangle {
            anchors.centerIn: parent
            width: 12
            height: 12
            radius: 6
            color: punto.tinta
            scale: puntoHover.hovered && !punto.elegido ? 1.2 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.9
                }
            }
        }

        HoverHandler {
            id: puntoHover
            enabled: !hoja.ocupada
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: !hoja.ocupada
            onTapped: punto.pulsado()
        }
    }

    // Un chip de categoría: el punto con el color de la sección y su nombre.
    // Elegido lleva la lámina más clara y un aro.
    component ChipCategoria: Rectangle {
        id: chip

        property string nombre: ""
        property color tinta: Theme.faint
        property bool elegido: false
        // Lo más ancho que puede ser: el ancho de la fila (un nombre largo se
        // corta con «…» en vez de descuadrar la hoja).
        property real maximo: 200
        signal pulsado

        implicitWidth: Math.min(chip.maximo, chipFila.implicitWidth + 16)
        implicitHeight: 22
        radius: 11
        color: Qt.rgba(1, 1, 1, chip.elegido ? 0.16 : (chipHover.hovered ? 0.08 : 0))
        border.width: 1
        border.color: chip.elegido ? Qt.rgba(1, 1, 1, 0.4) : Theme.rule

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Row {
            id: chipFila

            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 5

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: chip.tinta
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, chip.maximo - 16 - 13)
                text: chip.nombre
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: chip.elegido || chipHover.hovered ? Theme.strong : Theme.text
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: chip.elegido
            }
        }

        HoverHandler {
            id: chipHover
            enabled: !hoja.ocupada
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: !hoja.ocupada
            onTapped: chip.pulsado()
        }
    }

    // Un botón de texto. El principal (Guardar) va en una lámina más clara.
    // Apagado (activo false) se ve tenue, pero se puede pulsar mientras sea
    // pulsable: Guardar sin título dice entonces que falta.
    component Boton: Rectangle {
        id: boton

        property string texto
        property bool principal: false
        // Pide confirmación: en el rojo de «máxima».
        property bool peligro: false
        property bool activo: true
        property bool pulsable: boton.activo
        signal pulsado

        implicitWidth: Math.max(boton.principal ? 76 : 68, etiquetaBoton.implicitWidth + 20)
        implicitHeight: 24
        radius: 8
        color: Qt.rgba(1, 1, 1, !boton.activo ? 0.04 : boton.principal ? (botonHover.hovered ? 0.24 : 0.16) : (botonHover.hovered ? 0.08 : 0))
        border.width: 1
        border.color: boton.peligro ? Theme.prioMaxima : boton.principal && boton.activo ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            id: etiquetaBoton

            anchors.centerIn: parent
            text: boton.texto
            color: !boton.activo ? Theme.faint : boton.peligro ? Theme.prioMaxima : boton.principal || botonHover.hovered ? Theme.strong : Theme.text
            font.family: Theme.font
            font.pixelSize: 11
            font.bold: boton.principal
        }

        HoverHandler {
            id: botonHover
            enabled: boton.pulsable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: boton.pulsable
            onTapped: boton.pulsado()
        }
    }

    // --- La hoja ---------------------------------------------------------------

    ColumnLayout {
        id: columna

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        // «Nueva tarea» o «Editar tarea», el día y la ✕.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                objectName: "tituloHoja"
                text: hoja.modo === "editar" ? "Editar tarea" : "Nueva tarea"
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                objectName: "diaHoja"
                text: hoja.diaLegible()
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
            }

            Text {
                objectName: "cerrarHoja"
                text: "󰅖"
                color: cerrarHover.hovered ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 13

                HoverHandler {
                    id: cerrarHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: hoja.cancelar()
                }
            }
        }

        // El título.
        Caja {
            Layout.fillWidth: true
            implicitHeight: 28
            enfocada: campoTitulo.activeFocus
            mal: hoja.intentado && hoja.texto === ""

            Text {
                anchors.fill: campoTitulo
                verticalAlignment: Text.AlignVCenter
                visible: campoTitulo.text === "" && campoTitulo.preeditText === ""
                text: "Título"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
            }

            TextInput {
                id: campoTitulo

                objectName: "campoTitulo"
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                // Lo mismo que acepta el panel: una línea de hasta 300.
                maximumLength: 300
                activeFocusOnTab: true
                readOnly: hoja.ocupada
                selectByMouse: true
                color: Theme.strong
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                onTextChanged: hoja.tocada()
            }
        }

        // Todo el día, o de una hora a otra.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 8

            Text {
                text: "Todo el día"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11

                TapHandler {
                    enabled: !hoja.ocupada
                    onTapped: hoja.todoElDia = !hoja.todoElDia
                }
            }

            // El interruptor.
            Rectangle {
                id: interruptor

                objectName: "todoElDia"
                readonly property bool activo: hoja.todoElDia

                implicitWidth: 30
                implicitHeight: 16
                radius: 8
                color: Qt.rgba(1, 1, 1, interruptor.activo ? 0.34 : (interruptorHover.hovered ? 0.12 : 0.08))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, interruptor.activo ? 0.4 : 0.16)

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                Rectangle {
                    y: 2
                    x: interruptor.activo ? interruptor.width - width - 2 : 2
                    width: 12
                    height: 12
                    radius: 6
                    color: interruptor.activo ? Theme.strong : Theme.muted

                    Behavior on x {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.9
                        }
                    }
                }

                HoverHandler {
                    id: interruptorHover
                    enabled: !hoja.ocupada
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: !hoja.ocupada
                    onTapped: hoja.todoElDia = !hoja.todoElDia
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // De … a …: solo sin «Todo el día».
            RowLayout {
                objectName: "horasHoja"
                spacing: 6
                visible: !hoja.todoElDia

                Text {
                    text: "De"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                CampoHora {
                    id: campoInicio

                    objectName: "horaInicio"
                    mal: hoja.inicioMal
                    // Si el fin se queda antes del nuevo inicio, pasa a una
                    // hora después (o a las 23:59).
                    onTerminado: {
                        const i = Formato.sumarMinutos(Formato.normalizarHora(campoInicio.text), 0);
                        const f = Formato.sumarMinutos(Formato.normalizarHora(campoFin.text), 0);
                        if (i !== "" && f !== "" && f <= i && Formato.sumarMinutos(i, 60) > i)
                            campoFin.text = Formato.sumarMinutos(i, 60);
                    }
                }

                Text {
                    text: "a"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                CampoHora {
                    id: campoFin

                    objectName: "horaFin"
                    mal: hoja.finMal
                }
            }
        }

        // La prioridad y el 🚫🤖.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Prioridad"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
            }

            Row {
                spacing: 2

                Repeater {
                    model: hoja.prioridades

                    Punto {
                        required property var modelData

                        objectName: "prioridadPunto"
                        tinta: Theme.colorPrioridad(modelData.nombre)
                        nombre: modelData.etiqueta
                        elegido: hoja.prioridad === modelData.valor
                        onPulsado: hoja.prioridad = hoja.prioridad === modelData.valor ? "" : modelData.valor
                    }
                }
            }

            Text {
                objectName: "prioridadHoja"
                text: hoja.nombrePrioridad
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
            }

            Item {
                Layout.fillWidth: true
            }

            // 🚫🤖 «Claude no la hace», el mismo de la lista.
            Rectangle {
                id: robotHoja

                objectName: "claudeOffHoja"
                readonly property bool activo: hoja.claudeOff

                implicitWidth: robotHojaFila.implicitWidth + 14
                implicitHeight: 22
                radius: 7
                color: Qt.rgba(1, 1, 1, robotHoja.activo ? 0.16 : (robotHojaHover.hovered ? 0.08 : 0))
                border.width: robotHoja.activo ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.28)

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Row {
                    id: robotHojaFila

                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "󱚧"
                        color: robotHoja.activo || robotHojaHover.hovered ? Theme.strong : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: robotHoja.activo
                        text: "Claude no"
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                HoverHandler {
                    id: robotHojaHover
                    enabled: !hoja.ocupada
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: !hoja.ocupada
                    onTapped: hoja.claudeOff = !hoja.claudeOff
                }
            }
        }

        // La categoría: la sección del panel, un chip por cada una.
        RowLayout {
            objectName: "categoriasHoja"
            Layout.fillWidth: true
            spacing: 6
            visible: hoja.categorias.length > 0

            Text {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 4
                text: "Categoría"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
            }

            Flow {
                id: flujoCategorias

                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: flujoCategorias.childrenRect.height
                spacing: 4

                Repeater {
                    model: hoja.categorias

                    ChipCategoria {
                        required property var modelData

                        objectName: "categoriaOpcion"
                        nombre: modelData.nombre
                        tinta: modelData.color !== "" ? modelData.color : Theme.faint
                        elegido: hoja.seccion === modelData.id
                        maximo: flujoCategorias.width
                        onPulsado: hoja.seccion = modelData.id
                    }
                }
            }
        }

        // Por qué no se puede guardar, y los botones. Con sitio para dos
        // líneas de aviso, para que la isla no cambie de alto mientras se
        // teclea una hora (lo que dice el panel puede llevar alguna más).
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.minimumHeight: 28
            spacing: 8

            Text {
                objectName: "avisoHoja"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.minimumWidth: 0
                text: hoja.aviso
                wrapMode: Text.WordWrap
                // Lo que dice el panel puede ser largo («La hora de inicio y
                // la de fin van juntas: …»): entero.
                maximumLineCount: 5
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: hoja.error !== "" || hoja.motivoHoras !== "" || hoja.intentado && hoja.texto === "" ? Theme.prioMaxima : Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
            }

            Boton {
                objectName: "eliminarHoja"
                visible: hoja.borrable
                texto: hoja.confirmando ? "¿Eliminar?" : "Eliminar"
                peligro: hoja.confirmando
                activo: hoja.conPanel && !hoja.ocupada
                onPulsado: hoja.pedirEliminar()
            }

            Boton {
                objectName: "cancelarHoja"
                texto: "Cancelar"
                onPulsado: hoja.cancelar()
            }

            Boton {
                objectName: "guardarHoja"
                texto: "Guardar"
                principal: true
                activo: hoja.sePuede
                pulsable: !hoja.ocupada
                onPulsado: hoja.intentar()
            }
        }
    }
}
