import QtQuick
import QtQuick.Layouts
import Quickshell
import "shared"

// El desplegable de la wifi, que sale del bloque de la derecha igual que el
// calendario o las notificaciones salen de la isla.
//
// Arriba la radio y la red a la que se está conectado; debajo las demás, de más
// a menos señal. Pulsar una red guardada o abierta conecta sin más. Si la red
// pide datos, la lista se recoge y en su sitio aparece el formulario: sólo la
// contraseña en una WPA de casa, usuario y contraseña en una de empresa
// (WIFI_EDU, eduroam). El panel cambia de tamaño con la misma animación con la
// que se abrió, como el menú de sesión al pasar a la confirmación.
//
// Los datos y las acciones son de Wifi.qml; esto sólo pinta y recoge clics.
Item {
    id: root

    required property var shell
    required property var wifi
    property bool abierto: false

    implicitWidth: 340
    implicitHeight: columna.implicitHeight + Theme.pad * 2

    readonly property int filaH: 38
    // A partir de aquí la lista hace scroll, en vez de llevar el panel más
    // allá del borde de la pantalla en un sitio con muchas redes.
    readonly property int filasMax: 7

    // Lo más alto que puede llegar a medir: cabecera, red actual, siete filas,
    // un error y el pie. Lo usa la máscara de entrada del bloque, que no puede
    // ir siguiendo al panel mientras éste cambia de tamaño (ver SideBlock.qml).
    readonly property int alturaMax: 540

    readonly property string glifoWifi: String.fromCodePoint(0xF05A9)
    readonly property string glifoCandado: String.fromCodePoint(0xF033E)
    readonly property string glifoEscanear: String.fromCodePoint(0xF0450)
    readonly property string glifoVer: String.fromCodePoint(0xF0208)
    readonly property string glifoOcultar: String.fromCodePoint(0xF0209)

    // --- El formulario -------------------------------------------------------
    // La red para la que se piden datos, o null si se está viendo la lista.
    property var elegida: null
    readonly property bool pideUsuario: root.elegida !== null && root.elegida.tipo === "8021x"
    // El método sólo se elige al dar de alta una red de empresa nueva. Al
    // cambiar los datos de una que ya estaba guardada, wifi.sh conserva el que
    // tenía.
    property string metodo: "PEAP"
    property bool verClave: false

    // La red guardada que espera confirmación para olvidarse. Olvidar una red
    // de empresa borra su configuración entera, así que no va a un solo clic.
    property string olvidando: ""

    function elegir(red) {
        root.elegida = red;
        root.metodo = "PEAP";
        root.verClave = false;
        campoUsuario.texto = "";
        campoClave.texto = "";
        root.wifi.error = "";
        Qt.callLater(() => (root.pideUsuario ? campoUsuario : campoClave).entrada.forceActiveFocus());
    }

    function cerrarFormulario() {
        root.elegida = null;
        campoUsuario.texto = "";
        campoClave.texto = "";
        root.verClave = false;
        // El campo que tenía el foco se acaba de esconder; sin esto el foco se
        // queda en nada y Escape deja de cerrar el panel.
        root.forceActiveFocus();
    }

    function pulsar(red) {
        if (root.wifi.trabajando !== "")
            return;
        root.olvidando = "";
        if (red.guardada || red.tipo === "open")
            root.wifi.conectar(red.ruta);
        else
            root.elegir(red);
    }

    function enviar() {
        if (root.wifi.trabajando !== "" || root.elegida === null)
            return;
        const usuario = campoUsuario.texto.trim();
        const clave = campoClave.texto;
        if (root.pideUsuario && usuario === "") {
            campoUsuario.entrada.forceActiveFocus();
            return;
        }
        if (clave === "") {
            campoClave.entrada.forceActiveFocus();
            return;
        }
        if (root.pideUsuario) {
            // Antes de que salga la ventana de polkit, el panel se cierra: con
            // él abierto, el focus grab de Hyprland devuelve el teclado a la
            // barra y no habría forma de escribir la contraseña de
            // administrador. El resultado llega como notificación (Wifi.qml).
            const red = root.elegida;
            root.shell.close();
            root.wifi.conectarEmpresa(red.ruta, red.nombre, root.metodo, usuario, clave);
        } else {
            root.wifi.conectarConClave(root.elegida.ruta, root.elegida.nombre, clave);
        }
    }

    // Si conecta, el formulario se va solo. Si no, se queda con lo escrito y el
    // motivo debajo, para poder corregir sin volver a empezar.
    Connections {
        target: root.wifi
        function onTerminado(ok, sobre) {
            if (ok && root.elegida !== null && sobre === root.elegida.ruta)
                root.cerrarFormulario();
        }
    }

    // Al cerrar el desplegable no queda nada a medias: ni el formulario, ni la
    // contraseña escrita en memoria, ni una confirmación pendiente.
    onAbiertoChanged: {
        if (!root.abierto) {
            root.cerrarFormulario();
            root.olvidando = "";
        }
    }

    // Las teclas que le ofrece el bloque. Escape primero recoge el formulario;
    // sólo con la lista a la vista cierra el desplegable.
    function handleKey(event) {
        if (event.key === Qt.Key_Escape && root.elegida !== null) {
            root.cerrarFormulario();
            return true;
        }
        return false;
    }

    // --- Piezas ------------------------------------------------------------

    // Un texto que se pulsa: las acciones pequeñas de cada fila y el pie.
    component Accion: Text {
        id: accion

        signal pulsado
        property color tinte: Theme.faint

        color: zona.containsMouse ? Theme.strong : accion.tinte
        font.family: Theme.font
        font.pixelSize: 11

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        MouseArea {
            id: zona
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: accion.pulsado()
        }
    }

    // Un campo de texto con el mismo cristal que todo lo demás: otra lámina
    // blanca casi transparente, que se aclara un poco al tener el foco.
    component Campo: Rectangle {
        id: campo

        property alias texto: entrada.text
        property alias entrada: entrada
        property string pista: ""
        property bool secreto: false
        property bool ver: false
        // A dónde lleva el tabulador.
        property Item siguiente: null
        signal aceptado
        signal alternarVer

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 9
        color: Qt.rgba(1, 1, 1, entrada.activeFocus ? 0.09 : 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, entrada.activeFocus ? 0.32 : 0.12)

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        TextInput {
            id: entrada

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: campo.secreto ? 34 : 12
            color: Theme.strong
            selectionColor: Qt.rgba(1, 1, 1, 0.25)
            selectedTextColor: Theme.strong
            font.family: Theme.font
            font.pixelSize: 13
            echoMode: campo.secreto && !campo.ver ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            selectByMouse: true
            clip: true
            KeyNavigation.tab: campo.siguiente
            onAccepted: campo.aceptado()
        }

        Text {
            anchors.fill: entrada
            verticalAlignment: Text.AlignVCenter
            visible: entrada.text === ""
            text: campo.pista
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            visible: campo.secreto
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: campo.ver ? String.fromCodePoint(0xF0209) : String.fromCodePoint(0xF0208)
            color: ojo.containsMouse ? Theme.strong : Theme.faint
            font.family: Theme.font
            font.pixelSize: 14

            MouseArea {
                id: ojo
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: campo.alternarVer()
            }
        }
    }

    // Un botón del formulario. El principal lleva la lámina un poco más
    // marcada; el otro es sólo texto.
    component Boton: Rectangle {
        id: boton

        property string texto: ""
        property bool principal: false
        property bool activo: true
        signal pulsado

        implicitWidth: etiqueta.implicitWidth + 28
        implicitHeight: 32
        radius: 9
        opacity: boton.activo ? 1 : 0.5
        color: Qt.rgba(1, 1, 1, boton.principal ? (zona.containsMouse ? 0.22 : 0.14) : (zona.containsMouse ? 0.08 : 0))
        border.width: boton.principal ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.28)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            id: etiqueta
            anchors.centerIn: parent
            text: boton.texto
            color: boton.principal ? Theme.strong : Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }

        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: boton.activo ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (boton.activo)
                boton.pulsado()
        }
    }

    // --- El panel ------------------------------------------------------------
    ColumnLayout {
        id: columna

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: 10

        // --- Cabecera: la radio ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.glifoWifi
                color: root.wifi.encendida ? Theme.accent : Theme.faint
                font.family: Theme.font
                font.pixelSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: "Wi-Fi"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 13
            }

            // Volver a buscar. Gira mientras iwd está escaneando, sea por este
            // botón o porque iwd ha decidido hacerlo solo.
            Text {
                id: escanear

                visible: root.wifi.encendida
                text: root.glifoEscanear
                color: sobreEscanear.containsMouse ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 14

                RotationAnimation on rotation {
                    running: root.wifi.escaneando && root.abierto
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                    // Al parar no se queda torcido a medio giro.
                    onRunningChanged: if (!running)
                        escanear.rotation = 0
                }

                MouseArea {
                    id: sobreEscanear
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wifi.escanear()
                }
            }

            // El interruptor de la radio: una lámina blanca con el botón negro
            // cuando está encendida, apenas un filo cuando no.
            Item {
                implicitWidth: 34
                implicitHeight: 18
                opacity: root.wifi.trabajando === "radio" ? 0.5 : 1

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.wifi.encendida ? Qt.rgba(1, 1, 1, 0.82) : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, root.wifi.encendida ? 0 : 0.25)

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.wifi.encendida ? parent.width - width - 3 : 3
                    color: root.wifi.encendida ? "#000000" : Theme.text

                    Behavior on x {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.wifi.trabajando === "")
                        root.wifi.alternarRadio()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        // --- La red a la que se está conectado ---
        // La misma lámina que resalta la fila activa del menú de sesión, aquí
        // fija: es la red que está en uso.
        Rectangle {
            Layout.fillWidth: true
            visible: root.wifi.conectada && root.elegida === null
            implicitHeight: 52
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text {
                    text: root.wifi.conectada ? root.wifi.glifoDe(root.wifi.actual.senal) : ""
                    color: Theme.ok
                    font.family: Theme.font
                    font.pixelSize: 16
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.wifi.conectada ? root.wifi.actual.nombre : ""
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.wifi.conectada)
                                return "";
                            // La señal ya la dice el glifo; aquí va lo que no
                            // se ve de otra forma.
                            const partes = [];
                            if (root.wifi.frecuencia > 0)
                                partes.push((root.wifi.frecuencia / 1000).toFixed(1).replace(".", ",") + " GHz");
                            if (root.wifi.ip !== "")
                                partes.push(root.wifi.ip);
                            return partes.join(" · ");
                        }
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Accion {
                    text: root.wifi.trabajando === "desconectar" ? "desconectando…" : "desconectar"
                    onPulsado: if (root.wifi.trabajando === "")
                        root.wifi.desconectar()
                }
            }
        }

        // --- La lista ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.elegida === null
            spacing: 6

            Text {
                visible: root.wifi.encendida && lista.count > 0
                text: root.wifi.conectada ? "Otras redes" : "Redes"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
            }

            // Lo que se enseña cuando no hay lista que enseñar.
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                visible: !root.wifi.encendida || lista.count === 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: {
                    if (!root.wifi.listo)
                        return "…";
                    if (!root.wifi.hay)
                        return "No hay tarjeta wifi";
                    if (!root.wifi.encendida)
                        return "La wifi está apagada";
                    return root.wifi.escaneando ? "Buscando redes…" : "No hay más redes a la vista";
                }
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
            }

            ListView {
                id: lista

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(lista.count, root.filasMax) * root.filaH
                visible: root.wifi.encendida && lista.count > 0
                model: root.wifi.otras
                clip: true
                interactive: lista.count > root.filasMax
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: fila

                    required property string ruta
                    required property string nombre
                    required property string tipo
                    required property bool guardada
                    required property int senal

                    width: ListView.view.width
                    height: root.filaH

                    // El hover es de la fila entera, no del MouseArea que la
                    // cubre: «editar» y «olvidar» llevan su propio MouseArea
                    // encima, que le quita el hover a su hermano. La fila
                    // creía que el ratón se había ido, escondía las acciones,
                    // lo recuperaba y las volvía a sacar, y así cada
                    // fotograma. Un HoverHandler en la fila sigue viendo el
                    // ratón aunque esté sobre una de sus hijas.
                    readonly property bool encima: hoverFila.hovered
                    readonly property bool conectando: root.wifi.trabajando === fila.ruta

                    HoverHandler {
                        id: hoverFila
                    }

                    onEncimaChanged: if (!fila.encima && root.olvidando === fila.ruta)
                        root.olvidando = ""

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.rgba(1, 1, 1, fila.encima ? 0.10 : 0)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, fila.encima ? 0.18 : 0)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    MouseArea {
                        id: sobreFila
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pulsar({
                            ruta: fila.ruta,
                            nombre: fila.nombre,
                            tipo: fila.tipo,
                            guardada: fila.guardada
                        })
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: root.wifi.glifoDe(fila.senal)
                            color: fila.encima ? Theme.strong : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 16

                            // Mientras conecta, el glifo late.
                            SequentialAnimation on opacity {
                                running: fila.conectando
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation {
                                    to: 0.3
                                    duration: 450
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 450
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: fila.nombre
                            color: fila.encima ? Theme.strong : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        // A la derecha: en reposo, si está guardada o lleva
                        // contraseña; con el ratón encima, lo que se puede
                        // hacer con ella.
                        Text {
                            visible: fila.conectando
                            text: "conectando…"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Text {
                            visible: !fila.conectando && !fila.encima && fila.guardada
                            text: "guardada"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Accion {
                            visible: !fila.conectando && fila.encima && fila.guardada && fila.tipo === "8021x"
                            text: "editar"
                            onPulsado: root.elegir({
                                ruta: fila.ruta,
                                nombre: fila.nombre,
                                tipo: fila.tipo,
                                guardada: true
                            })
                        }

                        Accion {
                            visible: !fila.conectando && fila.encima && fila.guardada
                            text: root.olvidando === fila.ruta ? "¿olvidar?" : "olvidar"
                            tinte: root.olvidando === fila.ruta ? Theme.danger : Theme.faint
                            onPulsado: {
                                if (root.olvidando === fila.ruta) {
                                    root.olvidando = "";
                                    root.wifi.olvidar(fila.ruta);
                                } else {
                                    root.olvidando = fila.ruta;
                                }
                            }
                        }

                        Text {
                            visible: !fila.conectando && !fila.guardada && fila.tipo !== "open"
                            text: root.glifoCandado
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // Lo que ha fallado al conectar directamente, sin formulario.
            Text {
                Layout.fillWidth: true
                visible: root.wifi.error !== ""
                text: root.wifi.error
                color: Theme.danger
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        // --- El formulario ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.elegida !== null
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: root.elegida === null ? "" : (root.elegida.guardada ? "Cambiar los datos de " : "Conectar a ") + root.elegida.nombre
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            // PEAP con MSCHAPv2 es lo que usa casi todo eduroam; TTLS con PAP,
            // el resto. Sólo se elige al dar de alta la red.
            RowLayout {
                visible: root.pideUsuario && root.elegida !== null && !root.elegida.guardada
                spacing: 6

                Text {
                    text: "Método"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11
                    rightPadding: 4
                }

                Repeater {
                    model: ["PEAP", "TTLS"]

                    delegate: Rectangle {
                        id: chip

                        required property string modelData
                        readonly property bool puesto: root.metodo === chip.modelData

                        implicitWidth: textoChip.implicitWidth + 18
                        implicitHeight: 22
                        radius: 11
                        color: Qt.rgba(1, 1, 1, chip.puesto ? 0.16 : (sobreChip.containsMouse ? 0.07 : 0))
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, chip.puesto ? 0.30 : 0.12)

                        Text {
                            id: textoChip
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: chip.puesto ? Theme.strong : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: sobreChip
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.metodo = chip.modelData
                        }
                    }
                }
            }

            Campo {
                id: campoUsuario
                visible: root.pideUsuario
                pista: "usuario@universidad.es"
                siguiente: campoClave.entrada
                onAceptado: campoClave.entrada.forceActiveFocus()
            }

            Campo {
                id: campoClave
                pista: "Contraseña"
                secreto: true
                ver: root.verClave
                onAlternarVer: root.verClave = !root.verClave
                onAceptado: root.enviar()
            }

            Text {
                Layout.fillWidth: true
                visible: root.elegida !== null && root.wifi.error !== "" && root.wifi.errorDe === root.elegida.ruta
                text: root.wifi.error
                color: Theme.danger
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // Una red de empresa se guarda en /var/lib/iwd, que es de root.
            Text {
                Layout.fillWidth: true
                visible: root.pideUsuario
                text: "Se pedirá la contraseña de administrador para guardar la red."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }

                Boton {
                    texto: "Cancelar"
                    onPulsado: root.cerrarFormulario()
                }

                Boton {
                    texto: root.elegida !== null && root.wifi.trabajando === root.elegida.ruta ? "Conectando…" : "Conectar"
                    principal: true
                    activo: root.wifi.trabajando === ""
                    onPulsado: root.enviar()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        // Lo de Omarchy sigue a mano para lo que esto no cubre: redes ocultas,
        // punto de acceso, el detalle de cada estación.
        Accion {
            text: "Más opciones en Impala"
            onPulsado: {
                root.shell.close();
                root.wifi.abrirImpala();
            }
        }
    }
}
