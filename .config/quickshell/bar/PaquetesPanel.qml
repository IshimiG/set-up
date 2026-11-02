pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "shared"

// Desinstalar paquetes, desde el menú de sesión: su entrada «Desinstalar»
// cambia la isla a este panel, que se reajusta desde el menú en vez de cerrar
// y volver a abrir.
//
//   󰆴  Desinstalar                                     240 paquetes
//   ──────────────────────────────────────────────────────────────
//   [ 󰍉  Buscar…                                                 ]
//    ○  firefox 128.0-1                                  245.3 MiB
//       Standalone web browser from mozilla.org
//    ●  yay 12.5.0-1  AUR                                  8.1 MiB
//       Yet another yogurt. Pacman wrapper and AUR helper…
//    󰌾  glibc 2.40-1                                      47.9 MiB
//       GNU C Library                                    protegido
//   ──────────────────────────────────────────────────────────────
//   1 seleccionado                            [ 󰆴 Desinstalar (1) ]
//
// La lista la da ~/.config/hypr/scripts/paquetes.sh lista: una línea por
// paquete instalado a propósito (pacman -Qe), con los campos separados por
// tabuladores. Se lee cada vez que se abre el panel, no se guarda de una vez
// para otra: después de desinstalar, la siguiente vez sale al día.
//
// Este panel no desinstala nada. Lo que hace es abrir una terminal con
// `paquetes.sh desinstalar …`, que lanza `sudo pacman -Rns`: la contraseña la
// pide sudo y la confirmación final, pacman. Así lo que se ve
// antes de decir que sí —qué dependencias se van, cuánto se libera, si algo
// lo impide— es lo de pacman, no una imitación.
//
// Lo que está protegido (el script decide qué: la base del sistema, el
// escritorio…) sale apagado y con candado, y no se puede marcar.
Item {
    id: root

    required property var shell

    // Lo pone la isla: si este panel es el que se ve, en esta pantalla. El
    // modo es global y hay una isla por monitor, así que mirar sólo el modo
    // haría que las dos islas leyeran la lista y se pelearan por el teclado.
    property bool abierto: false

    // El script y cómo se lanza la terminal. Son propiedades para que la
    // prueba (pruebas/paquetes) ponga uno falso y se quede con la orden en vez
    // de abrir una terminal.
    property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/paquetes.sh"
    property var lanzador: orden => Quickshell.execDetached(orden)

    implicitWidth: 420
    implicitHeight: contenido.implicitHeight + Theme.pad * 2

    // Dos líneas por paquete: el nombre y, debajo, la descripción.
    readonly property int filaH: 42
    // Ocho filas a la vista y el resto con la rueda. La zona de la lista mide
    // siempre eso, también mientras carga, si falla o si el filtro la deja en
    // dos: el panel no cambia de alto al teclear, y la isla no salta.
    readonly property int filasVisibles: 8

    // --- El estado ------------------------------------------------------------

    // "" sin leer, "cargando", "listo" o "error".
    property string estado: ""
    // Lo leído: { nombre, version, tamano, origen, protegido, requeridos,
    // descripcion, busqueda }, en el orden del script (por nombre).
    property var paquetes: []
    // Los marcados, por nombre (nombre → true). Por nombre y no por fila:
    // marcar algo, buscar otra cosa y marcar más tiene que conservar lo de antes.
    property var seleccion: ({})
    // La fila resaltada, entre las que se ven.
    property int resalte: 0
    // Quién mueve el resalte: el ratón (sigue a la fila de debajo, también al
    // girar la rueda) o el teclado (la lista se desplaza para enseñarla).
    property bool porRaton: false
    property bool confirmando: false
    // En la confirmación: 0 Cancelar, 1 Desinstalar. Empieza en Cancelar, así
    // que un Enter de más no desinstala nada.
    property int eleccion: 0
    // Ya se ha dicho que sí: lo que se pulse hasta que el panel se reinicie
    // no lanza otra terminal.
    property bool lanzando: false
    property var cola: []
    // Cuenta las lecturas: lo que llega de una vieja (el panel se cerró o se
    // volvió a abrir mientras tanto) se tira.
    property int vez: 0
    // Quien tenía el teclado al abrir (la isla, que es quien cierra con Escape
    // y quien lo necesita si se cambia a otro panel): se le devuelve al cerrar.
    property Item tecladoAntes: null
    property bool cargandoVisible: false

    readonly property string filtro: campo.text.trim().toLowerCase()
    readonly property var visibles: root.filtro === "" ? root.paquetes : root.paquetes.filter(p => p.busqueda.indexOf(root.filtro) >= 0)
    // Lo marcado, en el orden de la lista: el de la orden que se lanza.
    readonly property var elegidos: root.paquetes.filter(p => root.seleccion[p.nombre] === true)
    readonly property int nElegidos: root.elegidos.length

    // Un paquete marcado que otros necesitan. pacman -Rns se niega entonces a
    // la desinstalación entera, salvo que lo que lo necesita vaya también en
    // ella; por eso se avisa y no se impide.
    readonly property var necesitados: root.elegidos.filter(p => p.requeridos > 0)

    // Los que otros necesitan, para el aviso: por su nombre si son pocos
    // («python-requests y vlc»), y si no, cuántos. Detrás de cada guion va un
    // U+2060 (invisible, no deja partir la línea ahí): «python-» al final de
    // una línea y «requests» en la siguiente ya no se lee como un nombre. No
    // vale el guion que no parte (U+2011): JetBrains Mono no lo tiene y saldría
    // de otra fuente.
    function listaNecesitados() {
        const n = root.necesitados.map(p => p.nombre.replace(/-/g, "-\u2060"));
        if (n.length > 3)
            return n.length + " de ellos";
        return n.length > 1 ? n.slice(0, -1).join(", ") + " y " + n[n.length - 1] : n.join("");
    }

    // Un protegido que se ha intentado marcar: su candado tiembla.
    signal sacudida(string nombre)

    // Otra búsqueda u otra lista: se vuelve arriba, a la primera que coincide.
    onVisiblesChanged: {
        root.resalte = 0;
        desliza.stop();
        lista.contentY = 0;
    }

    // --- Abrir y cerrar -------------------------------------------------------

    onAbiertoChanged: {
        if (root.abierto) {
            olvido.stop();
            root.reiniciar();
            root.cargar();
            // Después, no ahora: al abrir desde cerrada, la isla le da el
            // teclado a su propio Item en este mismo cambio de modo, y si el
            // buscador lo cogiera antes, se lo quitaría.
            Qt.callLater(root.enfocar);
        } else {
            root.vez++;
            root.soltarTeclado();
            olvido.restart();
        }
    }

    // Lo de dentro se olvida cuando la isla ha terminado de cerrarse (sus
    // 220 ms y los 200 del fundido del panel), no al instante: si no, la
    // confirmación se volvería la lista a mitad de la animación de cierre.
    // Al volver a abrir antes de eso se reinicia igual (onAbiertoChanged).
    Timer {
        id: olvido
        interval: 450
        onTriggered: {
            root.reiniciar();
            root.paquetes = [];
            root.estado = "";
        }
    }

    function reiniciar() {
        campo.text = "";
        root.seleccion = ({});
        root.confirmando = false;
        root.eleccion = 0;
        root.resalte = 0;
        root.porRaton = false;
        root.lanzando = false;
        desliza.stop();
        lista.contentY = 0;
    }

    // El teclado, al buscador. Escape, ↑/↓ y Enter siguen funcionando con él
    // dentro porque el propio campo se los pasa a handleKey (más abajo).
    function enfocar() {
        if (!root.abierto)
            return;
        const antes = root.Window.activeFocusItem;
        if (antes && antes !== campo && antes !== root)
            root.tecladoAntes = antes;
        if (root.confirmando)
            root.forceActiveFocus();
        else
            campo.forceActiveFocus();
    }

    // Por focus y no por activeFocus: si la isla se cierra por un clic fuera,
    // la ventana ya ha perdido el teclado y nadie tiene activeFocus, pero el
    // buscador seguiría siendo quien lo recibe al volver.
    function soltarTeclado() {
        if (campo.focus || root.focus) {
            if (root.tecladoAntes)
                root.tecladoAntes.forceActiveFocus();
            else {
                campo.focus = false;
                root.focus = false;
            }
        }
        root.tecladoAntes = null;
    }

    // --- La lista -------------------------------------------------------------

    Component {
        id: lectura
        Process {
            id: orden
            signal leida(string texto)
            stdout: StdioCollector {
                onStreamFinished: orden.leida(this.text)
            }
        }
    }

    // Lee la lista. Como Tareas.ejecutar: el final del texto y la salida del
    // proceso llegan en cualquier orden, y si el script no llega a arrancar no
    // hay ninguna de las dos.
    function cargar() {
        const v = ++root.vez;
        root.estado = "cargando";
        root.paquetes = [];
        // «Cargando…» sólo si tarda: una lectura rápida no tiene que parpadear.
        root.cargandoVisible = false;
        esperaCargando.restart();
        const o = lectura.createObject(root, {
            command: [root.script, "lista"]
        });
        let codigo = -1, leida = false, hecha = false, texto = "";
        const acabar = () => {
            if (hecha || codigo < 0 || !leida)
                return;
            hecha = true;
            o.destroy();
            if (v !== root.vez)
                return;
            const l = codigo === 0 ? root.leer(texto) : null;
            if (l === null) {
                root.estado = "error";
                return;
            }
            root.paquetes = l;
            root.estado = "listo";
        };
        o.leida.connect(t => {
            texto = t;
            leida = true;
            acabar();
        });
        o.exited.connect(c => {
            codigo = c;
            acabar();
        });
        o.runningChanged.connect(() => {
            if (!o.running)
                Qt.callLater(() => {
                    if (!hecha && codigo < 0) {
                        codigo = 127;
                        leida = true;
                        acabar();
                    }
                });
        });
        o.running = true;
    }

    Timer {
        id: esperaCargando
        interval: 150
        onTriggered: root.cargandoVisible = true
    }

    // nombre, versión, tamaño, origen, protegido, requeridos y descripción, por
    // tabuladores. La descripción va la última y se junta entera aunque traiga
    // algún tabulador. Una línea que no trae los siete campos se salta; un
    // texto con algo pero sin ninguna buena es que el script ha fallado.
    function leer(texto) {
        const l = [];
        const lineas = String(texto).split("\n");
        let algo = false;
        for (let i = 0; i < lineas.length; i++) {
            const linea = lineas[i].replace(/\r$/, "");
            if (linea.trim() === "")
                continue;
            algo = true;
            const c = linea.split("\t");
            if (c.length < 7 || c[0] === "")
                continue;
            const descripcion = c.slice(6).join(" ").trim();
            l.push({
                nombre: c[0],
                version: c[1],
                tamano: c[2],
                origen: c[3],
                protegido: c[4] === "1",
                requeridos: Math.max(0, parseInt(c[5], 10) || 0),
                descripcion: descripcion,
                busqueda: (c[0] + " " + descripcion).toLowerCase()
            });
        }
        return algo && l.length === 0 ? null : l;
    }

    // --- Marcar ---------------------------------------------------------------

    function alternar(p) {
        if (!p)
            return;
        if (p.protegido) {
            root.sacudida(p.nombre);
            return;
        }
        const s = Object.assign({}, root.seleccion);
        if (s[p.nombre])
            delete s[p.nombre];
        else
            s[p.nombre] = true;
        root.seleccion = s;
    }

    function mover(paso) {
        const n = root.visibles.length;
        if (n === 0)
            return;
        root.porRaton = false;
        root.resalte = Math.max(0, Math.min(n - 1, root.resalte + paso));
        root.mostrar(root.resalte);
    }

    // --- Desplazar ------------------------------------------------------------

    readonly property real maxY: Math.max(0, root.visibles.length * root.filaH - lista.height)

    // A dónde va la lista: si ya se está desplazando, a donde iba. Así varios
    // giros de rueda seguidos se suman en vez de pisarse.
    function destinoY() {
        return desliza.running ? desliza.to : lista.contentY;
    }

    function desplazar(y, animado) {
        const fin = Math.max(0, Math.min(root.maxY, y));
        desliza.stop();
        if (animado) {
            desliza.from = lista.contentY;
            desliza.to = fin;
            desliza.start();
        } else {
            lista.contentY = fin;
        }
    }

    // Lo justo para que la fila i se vea entera.
    function mostrar(i) {
        const arriba = i * root.filaH;
        const abajo = arriba + root.filaH;
        const y = root.destinoY();
        if (arriba < y)
            root.desplazar(arriba, true);
        else if (abajo > y + lista.height)
            root.desplazar(abajo - lista.height, true);
    }

    NumberAnimation {
        id: desliza
        target: lista
        property: "contentY"
        duration: 160
        easing.type: Easing.OutCubic
    }

    // --- Confirmar y lanzar ---------------------------------------------------

    function pedirConfirmacion() {
        if (root.estado !== "listo" || root.nElegidos === 0 || root.confirmando)
            return;
        root.eleccion = 0;
        root.confirmando = true;
        // El buscador se esconde: el teclado pasa al panel, que también lleva
        // a handleKey.
        root.forceActiveFocus();
    }

    // Vuelve a la lista con lo marcado intacto.
    function cancelar() {
        root.confirmando = false;
        campo.forceActiveFocus();
    }

    function orden(nombres) {
        return ["ghostty", "--title=Desinstalar", "-e", root.script, "desinstalar"].concat(nombres);
    }

    // Como PowerPanel.run: la terminal se abre cuando la isla ya ha terminado
    // de cerrarse, no encima de ella. La orden se copia ahora porque cerrar
    // reinicia lo marcado.
    function desinstalar() {
        if (root.lanzando || root.nElegidos === 0)
            return;
        root.lanzando = true;
        root.cola = root.orden(root.elegidos.map(p => p.nombre));
        root.shell.close();
        lanzamiento.restart();
    }

    Timer {
        id: lanzamiento
        interval: 220
        onTriggered: {
            if (root.cola.length > 0)
                root.lanzador(root.cola);
            root.cola = [];
        }
    }

    // --- Teclado --------------------------------------------------------------
    // Llega por tres sitios, y por eso todo pasa por aquí:
    //   - el Item de teclado de la isla, que llama a handleKey del panel abierto
    //     (y se queda él con Escape);
    //   - el buscador, que es quien tiene el foco en la lista. Ese Item de la
    //     isla NO es antepasado de los paneles, así que lo que se teclea en el
    //     campo nunca le llega: el campo le pasa aquí cada tecla antes de
    //     tratarla él, y Escape cierra la isla desde aquí (shell.close()) igual
    //     que haría ella;
    //   - el propio panel, que tiene el foco en la confirmación (el buscador no
    //     se ve).
    // ↑/↓ mueven el resalte con el foco en el buscador, Enter marca o desmarca
    // la fila resaltada y Ctrl+Enter pasa a la confirmación. En ella, las
    // flechas y el tabulador cambian de botón y Enter pulsa el elegido.
    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const intro = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
        if (event.key === Qt.Key_Escape) {
            root.shell.close();
            return true;
        }
        if (root.confirmando) {
            if (intro) {
                if (root.eleccion === 1)
                    root.desinstalar();
                else
                    root.cancelar();
                return true;
            }
            if (event.key === Qt.Key_Left) {
                root.eleccion = 0;
                return true;
            }
            if (event.key === Qt.Key_Right) {
                root.eleccion = 1;
                return true;
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.eleccion = 1 - root.eleccion;
                return true;
            }
            return false;
        }
        if (event.key === Qt.Key_Up) {
            root.mover(-1);
            return true;
        }
        if (event.key === Qt.Key_Down) {
            root.mover(1);
            return true;
        }
        if (event.key === Qt.Key_PageUp) {
            root.mover(-root.filasVisibles);
            return true;
        }
        if (event.key === Qt.Key_PageDown) {
            root.mover(root.filasVisibles);
            return true;
        }
        if (intro && ctrl) {
            root.pedirConfirmacion();
            return true;
        }
        if (intro) {
            if (root.estado === "listo")
                root.alternar(root.visibles[root.resalte]);
            return true;
        }
        // El tabulador sacaría el foco del buscador a ninguna parte.
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            return true;
        // Con el teclado en la isla y no en el campo (no debería, pero si la
        // ventana aún no tenía el foco al abrir), escribir busca igual.
        if (!campo.activeFocus && event.text.length === 1 && event.text >= " " && !ctrl && !(event.modifiers & Qt.AltModifier)) {
            campo.forceActiveFocus();
            campo.insert(campo.cursorPosition, event.text);
            return true;
        }
        return false;
    }

    Keys.onPressed: event => {
        if (!event.accepted)
            event.accepted = root.handleKey(event);
    }

    // --- Piezas ---------------------------------------------------------------

    // Un botón de cristal, pulsable entero: el MouseArea cubre todo el
    // rectángulo, no sólo el texto. «encendido» es estar bajo el ratón o
    // elegido con el teclado; el de peligro se enciende en el rojo de los
    // estados críticos.
    component Boton: Rectangle {
        id: boton

        property string icono: ""
        property string texto: ""
        property bool activo: true
        property bool peligro: false
        // Teñido de rojo también en reposo (el «Desinstalar» de la
        // confirmación); el del pie sólo se tiñe al pasar por encima.
        property bool rojo: false
        property bool elegido: false
        property int minimo: 0
        readonly property bool encendido: boton.activo && (zona.containsMouse || boton.elegido)
        readonly property bool enRojo: boton.activo && boton.peligro && (boton.rojo || zona.containsMouse || boton.elegido)
        signal pulsado
        signal sobre

        implicitWidth: Math.max(boton.minimo, filaBoton.implicitWidth + 26)
        implicitHeight: 28
        radius: 9
        color: !boton.activo ? Qt.rgba(1, 1, 1, 0.02) : boton.enRojo ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, boton.encendido ? (zona.pressed ? 0.42 : 0.32) : 0.12) : Qt.rgba(1, 1, 1, boton.encendido ? (zona.pressed ? 0.2 : 0.14) : 0.05)
        border.width: 1
        border.color: !boton.activo ? Theme.rule : boton.enRojo ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, boton.encendido ? 0.85 : 0.5) : Qt.rgba(1, 1, 1, boton.encendido ? 0.3 : 0.16)
        scale: zona.pressed ? 0.97 : 1

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            id: filaBoton

            anchors.centerIn: parent
            spacing: 7

            Text {
                visible: boton.icono !== ""
                text: boton.icono
                color: !boton.activo ? Theme.faint : boton.encendido ? Theme.strong : boton.enRojo ? "#ff8a96" : Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }

            Text {
                text: boton.texto
                color: !boton.activo ? Theme.faint : boton.encendido ? Theme.strong : boton.enRojo ? "#ff8a96" : Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: boton.encendido
            }
        }

        MouseArea {
            id: zona

            anchors.fill: parent
            enabled: boton.activo
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: boton.sobre()
            onClicked: boton.pulsado()
        }
    }

    // --- El panel -------------------------------------------------------------

    ColumnLayout {
        id: contenido

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: 10

        // La cabecera, como la del menú de sesión. En la confirmación, el
        // mismo aviso que allí.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.confirmando ? "󰀦" : "󰆴"
                color: root.confirmando ? Theme.warn : Theme.accent
                font.family: Theme.font
                font.pixelSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: root.confirmando ? "¿Seguro?" : "Desinstalar"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 13
            }

            Text {
                objectName: "cuentaPaquetes"
                visible: !root.confirmando && root.estado === "listo"
                text: root.filtro !== "" ? root.visibles.length + " de " + root.paquetes.length : root.paquetes.length + (root.paquetes.length === 1 ? " paquete" : " paquetes")
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        // --- La lista ---

        // El buscador: una lámina de cristal, más clara con el foco. Pulsar en
        // cualquier punto de ella (también en la lupa) lleva el foco al campo.
        Rectangle {
            objectName: "buscador"
            Layout.fillWidth: true
            implicitHeight: 32
            visible: !root.confirmando
            radius: 10
            color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.09 : 0.05)
            border.width: 1
            border.color: campo.activeFocus ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: campo.forceActiveFocus()
            }

            Text {
                id: lupa

                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: campo.activeFocus ? Theme.text : Theme.muted
                font.family: Theme.font
                font.pixelSize: 14
            }

            Text {
                anchors.fill: campo
                verticalAlignment: Text.AlignVCenter
                visible: campo.text === "" && campo.preeditText === ""
                text: "Buscar…"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
            }

            TextInput {
                id: campo

                objectName: "campoBuscar"
                anchors.left: lupa.right
                anchors.leftMargin: 9
                anchors.right: borrar.visible ? borrar.left : parent.right
                anchors.rightMargin: borrar.visible ? 4 : 11
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                maximumLength: 100
                selectByMouse: true
                color: Theme.strong
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                selectedTextColor: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12

                // Antes que el propio campo (Keys va por delante del Item): lo
                // que handleKey no quiere, el campo lo escribe.
                Keys.onPressed: event => {
                    event.accepted = root.handleKey(event);
                }
            }

            // Vaciar la búsqueda, cuando hay algo.
            Text {
                id: borrar

                objectName: "borrarBusqueda"
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: campo.text !== ""
                text: "󰅖"
                color: borrarZona.containsMouse ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 13

                MouseArea {
                    id: borrarZona

                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        campo.text = "";
                        campo.forceActiveFocus();
                    }
                }
            }
        }

        Item {
            id: zonaLista

            objectName: "zonaLista"
            Layout.fillWidth: true
            Layout.preferredHeight: root.filasVisibles * root.filaH
            visible: !root.confirmando

            ListView {
                id: lista

                objectName: "listaPaquetes"

                readonly property bool hayScroll: root.visibles.length * root.filaH > lista.height
                // Con scroll, las filas dejan a la derecha el sitio de la barra.
                readonly property real anchoFila: lista.width - (lista.hayScroll ? 9 : 0)

                anchors.fill: parent
                clip: true
                // Ni arrastrar para desplazar (en un escritorio con ratón, un
                // clic que se movía un pelo se convertía en un arrastre) ni que
                // ListView mueva la vista sola: la rueda y las flechas la
                // desplazan a mano (desplazar(), más arriba).
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                currentIndex: -1
                visible: root.estado === "listo"
                model: root.visibles

                // La fila resaltada es otra lámina de cristal, como en el menú
                // de sesión: tinte del acento y un filo blanco. No es el
                // highlight de ListView a propósito: ése va con currentIndex, y
                // ListView desplaza la vista para enseñar la fila actual cada
                // vez que cambia; con el resalte siguiendo al ratón, girar la
                // rueda con el puntero quieto peleaba con el desplazamiento.
                // Va en el contenido de la lista, así que se desplaza con las
                // filas. El parent hay que darlo a mano: declarado dentro de un
                // ListView, un Item se queda en el propio ListView, quieto.
                Rectangle {
                    objectName: "resalte"
                    parent: lista.contentItem
                    z: -1
                    x: 0
                    y: root.resalte * root.filaH
                    width: lista.anchoFila
                    height: root.filaH
                    radius: 10
                    visible: root.visibles.length > 0
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, raton.pressed ? 0.2 : 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)

                    Behavior on y {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                delegate: Item {
                    id: fila

                    required property var modelData
                    required property int index

                    readonly property bool elegida: root.seleccion[fila.modelData.nombre] === true
                    readonly property bool resaltada: root.resalte === fila.index
                    readonly property bool protegido: fila.modelData.protegido

                    objectName: "filaPaquete"
                    width: lista.anchoFila
                    height: root.filaH

                    Connections {
                        target: root
                        function onSacudida(nombre) {
                            if (nombre === fila.modelData.nombre)
                                temblor.restart();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 11

                        // El círculo de selección (relleno y con el visto si
                        // está marcada) o, si está protegido, el candado.
                        Item {
                            objectName: "marcaPaquete"
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter

                            transform: Translate {
                                id: desvio
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !fila.protegido
                                radius: 9
                                color: "transparent"
                                border.width: 1.5
                                border.color: fila.elegida ? Theme.strong : Qt.rgba(1, 1, 1, fila.resaltada ? 0.55 : 0.3)

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !fila.protegido
                                radius: 9
                                color: Theme.strong
                                scale: fila.elegida ? 1 : 0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.9
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄬"
                                    color: "#000000"
                                    opacity: 0.85
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: fila.protegido
                                text: "󰌾"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 14
                            }

                            // Intentar marcar un protegido: el candado dice que
                            // no con la cabeza.
                            SequentialAnimation {
                                id: temblor

                                NumberAnimation {
                                    target: desvio
                                    property: "x"
                                    to: -3
                                    duration: 45
                                }
                                NumberAnimation {
                                    target: desvio
                                    property: "x"
                                    to: 3
                                    duration: 70
                                }
                                NumberAnimation {
                                    target: desvio
                                    property: "x"
                                    to: -2
                                    duration: 60
                                }
                                NumberAnimation {
                                    target: desvio
                                    property: "x"
                                    to: 0
                                    duration: 50
                                }
                            }
                        }

                        ColumnLayout {
                            id: textos

                            // Todo lo que deja el círculo, y nada que dependa de
                            // lo que pida su contenido (ver «libre», abajo).
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1
                            // Lo protegido, apagado.
                            opacity: fila.protegido ? 0.45 : 1

                            // El nombre, la versión, «AUR» y el tamaño. Si no
                            // cabe, cede antes la versión que el nombre.
                            RowLayout {
                                id: linea

                                // Lo que queda para el nombre y la versión. Sale del
                                // ancho de la fila (menos los márgenes, el círculo
                                // y su hueco) y no de linea.width: el ancho de un
                                // Layout depende de lo que piden sus hijos, y si
                                // los hijos dependieran de él se recolocaría en
                                // bucle.
                                readonly property real ancho: fila.width - 24 - 18 - 11
                                readonly property real libre: Math.max(0, linea.ancho - tamano.implicitWidth - (aur.visible ? aur.implicitWidth + linea.spacing : 0) - linea.spacing * 3)
                                readonly property real anchoNombre: Math.min(nombre.implicitWidth, linea.libre)
                                readonly property real anchoVersion: Math.min(version.implicitWidth, linea.libre - linea.anchoNombre)

                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    id: nombre

                                    objectName: "nombrePaquete"
                                    Layout.preferredWidth: linea.anchoNombre
                                    Layout.minimumWidth: linea.anchoNombre
                                    text: fila.modelData.nombre
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.strong
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }

                                Text {
                                    id: version

                                    Layout.preferredWidth: linea.anchoVersion
                                    Layout.minimumWidth: linea.anchoVersion
                                    Layout.alignment: Qt.AlignBaseline
                                    // Cortada hasta «…» no dice nada.
                                    visible: linea.anchoVersion >= 24
                                    text: fila.modelData.version
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                }

                                // «AUR», discreta: un filo y nada más.
                                Rectangle {
                                    id: aur

                                    objectName: "etiquetaAur"
                                    visible: fila.modelData.origen === "aur"
                                    implicitWidth: aurTexto.implicitWidth + 8
                                    implicitHeight: 13
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 4
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.22)

                                    Text {
                                        id: aurTexto

                                        anchors.centerIn: parent
                                        text: "AUR"
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: 8
                                        font.bold: true
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    id: tamano

                                    Layout.alignment: Qt.AlignBaseline
                                    text: fila.modelData.tamano
                                    textFormat: Text.PlainText
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }
                            }

                            // La descripción y, a la derecha, por qué puede que
                            // no se deje quitar.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: fila.modelData.descripcion
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                }

                                Text {
                                    objectName: "pistaPaquete"
                                    visible: text !== ""
                                    text: fila.protegido ? "protegido" : fila.modelData.requeridos > 0 ? (fila.modelData.requeridos === 1 ? "lo necesita otro" : "lo necesitan " + fila.modelData.requeridos) : ""
                                    color: fila.protegido ? Theme.faint : Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.7)
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }

                onContentYChanged: {
                    if (root.porRaton && raton.containsMouse)
                        root.resaltarBajo(raton.mouseY);
                }
            }

            // La barra de desplazamiento: fina y sólo para saber por dónde se va.
            Rectangle {
                objectName: "barraScroll"
                visible: lista.visible && lista.hayScroll
                x: zonaLista.width - 4
                width: 3
                radius: 1.5
                height: Math.max(24, zonaLista.height * zonaLista.height / Math.max(1, root.visibles.length * root.filaH))
                y: root.maxY > 0 ? (zonaLista.height - height) * lista.contentY / root.maxY : 0
                color: Qt.rgba(1, 1, 1, raton.containsMouse ? 0.3 : 0.15)

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
            }

            // Todo lo del ratón sobre la lista, en una sola capa por encima de
            // las filas: la fila entera es pulsable, de canto a canto y sin
            // huecos entre una y otra, porque la fila se saca de la altura del
            // clic y no de qué Item hay debajo.
            //
            // El resalte sólo sigue al ratón cuando el ratón se mueve de
            // verdad. Al desplazar la lista con las flechas, las filas pasan
            // por debajo del puntero quieto y Qt manda «hover» igual; si se le
            // hiciera caso, el resalte saltaría del sitio al que lo llevan las
            // flechas a la fila de debajo del ratón.
            MouseArea {
                id: raton

                property real ultimoX: -1
                property real ultimoY: -1
                readonly property int filaBajo: raton.containsMouse ? root.filaEn(raton.mouseY) : -1

                anchors.fill: parent
                enabled: root.estado === "listo"
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: raton.filaBajo < 0 ? Qt.ArrowCursor : root.visibles[raton.filaBajo].protegido ? Qt.ForbiddenCursor : Qt.PointingHandCursor

                onPositionChanged: mouse => {
                    if (mouse.x === raton.ultimoX && mouse.y === raton.ultimoY)
                        return;
                    raton.ultimoX = mouse.x;
                    raton.ultimoY = mouse.y;
                    root.porRaton = true;
                    root.resaltarBajo(mouse.y);
                }

                onClicked: mouse => {
                    const i = root.filaEn(mouse.y);
                    if (i < 0)
                        return;
                    root.porRaton = true;
                    root.resalte = i;
                    root.alternar(root.visibles[i]);
                }

                // La rueda: dos filas por muesca, con un deslizamiento corto; el
                // panel táctil, a la par del dedo. Sólo vertical (lo que hace
                // WheelHandler por defecto).
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        root.porRaton = true;
                        if (event.device.type === PointerDevice.TouchPad && event.pixelDelta.y !== 0)
                            root.desplazar(root.destinoY() - event.pixelDelta.y, false);
                        else
                            root.desplazar(root.destinoY() - event.angleDelta.y / 120 * root.filaH * 2, true);
                    }
                }
            }

            // Lo que se dice en el sitio de la lista cuando no hay lista.
            Column {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 8
                visible: root.estado !== "listo" || root.visibles.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.estado !== "cargando"
                    text: root.estado === "error" ? "󰀦" : "󰍉"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 22
                }

                Text {
                    id: mensaje

                    objectName: "mensajeLista"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: root.estado === "cargando" ? (root.cargandoVisible ? "Cargando…" : "") : root.estado === "error" ? "No se pudo leer la lista de paquetes" : root.estado === "listo" && root.paquetes.length === 0 ? "No hay paquetes que enseñar" : root.estado === "listo" ? "Nada coincide con \"" + campo.text.trim() + "\"" : ""
                    color: root.estado === "cargando" ? Theme.muted : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12

                    // Mientras carga, respira despacio.
                    SequentialAnimation on opacity {
                        running: root.estado === "cargando" && root.cargandoVisible
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation {
                            from: 1
                            to: 0.45
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.45
                            to: 1
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }

        // --- La confirmación ---

        ColumnLayout {
            objectName: "confirmacion"
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            visible: root.confirmando
            spacing: 6

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                wrapMode: Text.Wrap
                // -Rns: también las dependencias que se quedan sin nadie que
                // las use, y su configuración guardada.
                text: root.nElegidos === 1 ? "Se desinstalará, con sus dependencias sin uso:" : "Se desinstalarán " + root.nElegidos + " paquetes y sus dependencias sin uso:"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
            }

            // Hasta seis, y cuántos más.
            Repeater {
                model: root.confirmando ? root.elegidos.slice(0, 6) : []

                RowLayout {
                    id: elegido

                    required property var modelData

                    objectName: "nombreConfirmacion"
                    readonly property string nombre: elegido.modelData.nombre

                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 5
                        implicitHeight: 5
                        radius: 2.5
                        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.9)
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: elegido.modelData.nombre
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Text {
                        text: elegido.modelData.tamano
                        textFormat: Text.PlainText
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                objectName: "masConfirmacion"
                Layout.leftMargin: 17
                visible: root.nElegidos > 6
                text: "y " + (root.nElegidos - 6) + " más"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }

            // Lo que pacman puede rechazar: algo marcado que otros necesitan.
            RowLayout {
                objectName: "avisoNecesitados"
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: root.necesitados.length > 0
                spacing: 7

                Text {
                    Layout.alignment: Qt.AlignTop
                    text: "󰀦"
                    color: Theme.warn
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: "Puede que pacman se niegue: otros paquetes necesitan " + root.listaNecesitados() + "."
                    color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.9)
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                wrapMode: Text.Wrap
                text: "Se abre una terminal y pacman pide allí la última confirmación."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.rule
        }

        // --- El pie ---

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            Text {
                objectName: "seleccionados"
                Layout.fillWidth: true
                visible: !root.confirmando
                text: root.nElegidos === 0 ? "" : root.nElegidos === 1 ? "1 seleccionado" : root.nElegidos + " seleccionados"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }

            Item {
                Layout.fillWidth: true
                visible: root.confirmando
            }

            // El ancho mínimo cabe «Desinstalar (99)»: el botón no crece a
            // saltos al ir marcando.
            Boton {
                objectName: "botonDesinstalar"
                visible: !root.confirmando
                icono: "󰆴"
                texto: root.nElegidos > 0 ? "Desinstalar (" + root.nElegidos + ")" : "Desinstalar"
                activo: root.nElegidos > 0 && root.estado === "listo"
                peligro: true
                minimo: 160
                onPulsado: root.pedirConfirmacion()
            }

            Boton {
                objectName: "botonCancelar"
                visible: root.confirmando
                texto: "Cancelar"
                minimo: 92
                elegido: root.eleccion === 0
                onSobre: root.eleccion = 0
                onPulsado: root.cancelar()
            }

            Boton {
                objectName: "botonConfirmar"
                visible: root.confirmando
                icono: "󰆴"
                texto: "Desinstalar"
                peligro: true
                rojo: true
                minimo: 120
                elegido: root.eleccion === 1
                onSobre: root.eleccion = 1
                onPulsado: root.desinstalar()
            }
        }
    }

    // --- Ayudas del ratón -----------------------------------------------------

    // La fila que hay a esa altura de la zona de la lista, o -1.
    function filaEn(y) {
        const i = Math.floor((y + lista.contentY) / root.filaH);
        return i >= 0 && i < root.visibles.length ? i : -1;
    }

    function resaltarBajo(y) {
        const i = root.filaEn(y);
        if (i >= 0)
            root.resalte = i;
    }
}
