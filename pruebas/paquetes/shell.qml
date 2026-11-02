import QtQuick
import QtTest
import Quickshell
import "shared"
import "barra" as Barra

// Prueba sin pantalla del panel de paquetes (la lanza prueba.sh, al lado).
//
// El PaquetesPanel.qml del repo va dentro de un cristal como el de la isla
// (con su pastilla encima, para que las capturas se vean como en la barra), y
// el PowerPanel.qml del repo al lado, los dos con el mismo shell falso. Un Item
// de teclado hace de el de la isla: tiene el foco al principio, cierra con
// Escape y ofrece el resto de teclas al panel abierto. Todo se mueve con
// TestEvent. Cada comprobación imprime OK o FALLO; al final, el recuento.
//
// Al final, la isla de verdad (IslaPrueba.qml: el Island.qml del repo como
// FloatingWindow, lo hace prueba.sh) con todos sus paneles y su propio shell
// falso: el menú se reajusta al panel de paquetes sin cerrarse, el cristal y
// la máscara de entrada miden el panel, y el teclado va de la isla al
// buscador y vuelve. Va escondida (la barra oculta, SUPER+SHIFT+V) para que
// sólo salga mientras está abierta: una ventana que se enseña se queda con el
// teclado, y las teclas de la primera parte tienen que ir a esta.
//
// Lo que no se puede probar sin compositor: que la máscara recorte de verdad
// los clics, el focus grab de Hyprland y el teclado de layer-shell.
FloatingWindow {
    id: ventana

    implicitWidth: 800
    implicitHeight: 600
    color: "#10121a"

    readonly property string dir: Quickshell.env("PRUEBA_DIR") + "/"
    readonly property string bin: ventana.dir + "bin/"

    // --- El shell falso ----------------------------------------------------------

    QtObject {
        id: shellFalso
        property string mode: ""
        property string modeScreen: "prueba"
        property int cierres: 0
        function toggle(screenName, which) {
            if (mode === which && modeScreen === screenName) {
                close();
                return;
            }
            modeScreen = screenName;
            mode = which;
        }
        function close() {
            cierres++;
            mode = "";
        }
    }

    // Lo que el panel habría lanzado.
    property var lanzadas: []

    // El Item de teclado de la isla: Escape cierra y el resto va al panel.
    Item {
        id: teclado
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                shellFalso.close();
                return;
            }
            const p = shellFalso.mode === "paquetes" ? paq : shellFalso.mode === "power" ? menu : null;
            if (p)
                event.accepted = p.handleKey(event);
        }
    }

    // --- La escena: un fondo, el cristal de la isla y el panel -----------------

    component Fondo: Rectangle {
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#1d2233"
            }
            GradientStop {
                position: 1
                color: "#2a1f33"
            }
        }
    }

    // El cristal de la isla: el canto con su degradado y el cuerpo encima, y la
    // pastilla arriba con el botón de sesión encendido.
    component Cristal: Rectangle {
        id: cristal
        default property alias contenido: cuerpo.data
        radius: 18
        clip: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.edgeTop
            }
            GradientStop {
                position: 1
                color: Theme.edgeBottom
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 17
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.glassTop
                }
                GradientStop {
                    position: 1
                    color: Theme.glassBottom
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 26
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "lun 2"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "16:20"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰂚"
                color: Theme.strong
                opacity: 0.55
                font.family: Theme.font
                font.pixelSize: 13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰐥"
                color: Theme.danger
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
        Item {
            id: cuerpo
            anchors.fill: parent
            anchors.topMargin: 26
        }
    }

    Fondo {
        id: escena
        x: 0
        y: 0
        width: 480
        height: 600

        Cristal {
            id: cristalPaq
            x: Math.round((escena.width - width) / 2)
            y: 3
            width: paq.implicitWidth
            height: 26 + paq.implicitHeight

            Barra.PaquetesPanel {
                id: paq
                width: implicitWidth
                height: implicitHeight
                shell: shellFalso
                abierto: shellFalso.mode === "paquetes"
                script: ventana.bin + "paquetes.sh"
                lanzador: orden => ventana.lanzadas = ventana.lanzadas.concat([orden])
                // Como en la isla: fundido al entrar y al salir.
                opacity: shellFalso.mode === "paquetes" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Fondo {
        id: escenaMenu
        x: 490
        y: 0
        width: 310
        height: 380

        Cristal {
            x: Math.round((escenaMenu.width - width) / 2)
            y: 3
            width: menu.implicitWidth
            height: 26 + menu.implicitHeight

            Barra.PowerPanel {
                id: menu
                width: implicitWidth
                height: implicitHeight
                shell: shellFalso
            }
        }
    }

    // --- La isla de verdad --------------------------------------------------------

    QtObject {
        id: shellIsla
        property string mode: ""
        property string modeScreen: ""
        property bool hidden: true
        property date now: new Date(2026, 10, 2, 16, 20)
        property var history: []
        property bool silent: false
        property bool unread: false
        property var agenda: null
        property var tareas: null
        property int cierres: 0
        signal arrived
        function toggle(screenName, which) {
            if (mode === which && modeScreen === screenName) {
                close();
                return;
            }
            modeScreen = screenName;
            mode = which;
        }
        function close() {
            cierres++;
            mode = "";
        }
        function clearHistory() {
        }
        function forgetEntry(i) {
        }
    }

    Barra.IslaPrueba {
        id: isla
        shell: shellIsla
    }

    // Cuántas veces se ha abierto o cerrado la isla: reajustarse de un panel
    // a otro no puede contar.
    property int cambiosIsla: 0

    Connections {
        target: isla
        function onOpenChanged() {
            ventana.cambiosIsla++;
        }
    }

    function enIsla(nombre) {
        let r = null;
        ventana.recorrer(isla.pruebaPaquetes, it => {
            if (r === null && it.objectName === nombre && it.visible)
                r = it;
        });
        return r;
    }

    // Las cuatro esquinas de item, en la ventana de la isla, dentro de la región.
    function enRegion(item, region) {
        const a = item.mapToItem(null, 0, 0);
        const b = item.mapToItem(null, item.width, item.height);
        return a.x >= region.x && a.y >= region.y && b.x <= region.x + region.width && b.y <= region.y + region.height;
    }

    property real altoIsla: 0

    TestEvent {
        id: ev
    }

    // --- Ayudas ------------------------------------------------------------------

    property var fallos: []
    property int hechas: 0

    function comprobar(ok, que, extra) {
        console.log((ok ? "OK     " : "FALLO  ") + que + (extra !== undefined && extra !== "" ? "  (" + extra + ")" : ""));
        ventana.hechas++;
        if (!ok)
            ventana.fallos.push(que);
    }

    function captura(item, nombre) {
        item.grabToImage(r => r.saveToFile(ventana.dir + "capturas/" + nombre + ".png"));
    }

    function recorrer(item, f) {
        f(item);
        for (let k = 0; k < item.children.length; k++)
            ventana.recorrer(item.children[k], f);
    }

    function todos(raiz, nombre) {
        const l = [];
        ventana.recorrer(raiz, it => {
            if (it.objectName === nombre && it.visible)
                l.push(it);
        });
        return l;
    }

    function uno(nombre) {
        const l = ventana.todos(paq, nombre);
        return l.length ? l[0] : null;
    }

    function igual(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function nombres(l) {
        return l.map(p => p.nombre);
    }

    // Las piezas fijas del panel, buscadas una vez y aunque no se vean (con el
    // panel ya fundido al cerrar hay que poder preguntarles igual).
    property var piezas: ({})

    function pieza(nombre) {
        if (!ventana.piezas[nombre])
            ventana.recorrer(paq, it => {
                if (!ventana.piezas[nombre] && it.objectName === nombre)
                    ventana.piezas[nombre] = it;
            });
        return ventana.piezas[nombre] || null;
    }

    function campo() {
        return ventana.pieza("campoBuscar");
    }

    function zona() {
        return ventana.pieza("zonaLista");
    }

    function lista() {
        return ventana.pieza("listaPaquetes");
    }

    function boton(nombre) {
        return ventana.uno(nombre);
    }

    function texto(nombre) {
        const t = ventana.uno(nombre);
        return t ? t.text : null;
    }

    function clicEn(item, x, y) {
        ev.mouseClick(item, x === undefined ? item.width / 2 : x, y === undefined ? item.height / 2 : y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    // Clic en la fila i de la lista, a la altura dy dentro de ella.
    function clicFila(i, dy) {
        const z = ventana.zona();
        ev.mouseClick(z, z.width / 2, i * paq.filaH + dy - ventana.lista().contentY, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function teclear(t) {
        for (let k = 0; k < t.length; k++)
            ev.keyClickChar(t[k], Qt.NoModifier, -1);
    }

    function tecla(k, m) {
        ev.keyClick(k, m === undefined ? Qt.NoModifier : m, -1);
    }

    // Busca un paquete y lo marca con Enter, como se haría a mano.
    function marcarBuscando(nombre) {
        ventana.campo().text = nombre;
        ventana.tecla(Qt.Key_Return);
        ventana.campo().text = "";
    }

    // Las cuatro esquinas de item dentro del tamaño implícito del panel (lo
    // que mide la máscara de la isla).
    function dentroDelPanel(item) {
        const a = item.mapToItem(paq, 0, 0);
        const b = item.mapToItem(paq, item.width, item.height);
        return a.x >= 0 && a.y >= 0 && b.x <= paq.implicitWidth && b.y <= paq.implicitHeight;
    }

    function nombresConfirmacion() {
        return ventana.todos(paq, "nombreConfirmacion").map(x => x.nombre);
    }

    function filaMenu(etiqueta) {
        let f = null;
        ventana.recorrer(menu, it => {
            if (f === null && it.modelData !== undefined && it.modelData !== null && it.modelData.label === etiqueta && it.visible)
                f = it;
        });
        return f;
    }

    function etiquetasMenu() {
        return menu.model.map(e => e.label);
    }

    // --- Los pasos ---------------------------------------------------------------

    property real alto0: 0
    property int vez0: 0
    property int cierres0: 0

    readonly property var pasos: [
        [300, () => {
                ventana.comprobar(!paq.abierto && paq.estado === "" && paq.paquetes.length === 0, "cerrado, el panel no lee nada");
                ventana.comprobar(teclado.activeFocus, "(el teclado lo tiene el Item de la isla)");
                // Se abre directo, como haría el atajo (IPC togglePaquetes).
                shellFalso.mode = "paquetes";
            }],
        [400, () => {
                const c = ventana.campo();
                ventana.comprobar(paq.estado === "listo" && paq.paquetes.length === 15, "al abrir lee la lista del script: 15 paquetes", paq.estado + ", " + paq.paquetes.length);
                ventana.comprobar(ventana.texto("cuentaPaquetes") === "15 paquetes", "la cabecera dice cuántos hay", ventana.texto("cuentaPaquetes"));
                const p = paq.paquetes;
                ventana.comprobar(p[0].nombre === "base" && p[0].protegido && p[9].origen === "aur" && p[10].requeridos === 12 && p[4].version === "2.40+r16+gaa533d58ff-2" && p[2].tamano === "245.31 MiB", "los siete campos se leen bien (protegido, AUR, requeridos, versión, tamaño)");
                ventana.comprobar(p[12].descripcion.indexOf("<b>markup</b>") >= 0, "  y la descripción tal cual, sin interpretar etiquetas");
                ventana.comprobar(c !== null && c.activeFocus, "el buscador tiene el foco al abrir");
                ventana.comprobar(paq.implicitWidth === 420, "el panel mide 420 de ancho", paq.implicitWidth);
                ventana.alto0 = paq.implicitHeight;
                ventana.comprobar(3 + 26 + paq.implicitHeight <= 1080 && ventana.lista().height === 8 * paq.filaH, "8 filas a la vista y la isla entera cabe en una pantalla de 1080", "isla de " + (3 + 26 + paq.implicitHeight) + " px");
                ventana.comprobar(ventana.uno("barraScroll") !== null, "con 15 sale la barra de desplazamiento");
                const b = ventana.boton("botonDesinstalar");
                ventana.comprobar(b !== null && !b.activo && b.texto === "Desinstalar" && ventana.texto("seleccionados") === "", "sin nada marcado, «Desinstalar» está apagado y el pie no dice nada");
                ventana.comprobar(ventana.dentroDelPanel(b) && ventana.dentroDelPanel(ventana.zona()) && ventana.dentroDelPanel(ventana.uno("buscador")), "el botón, la lista y el buscador caen enteros dentro del tamaño del panel (la máscara de la isla)");
                const filas = ventana.todos(paq, "filaPaquete").filter(f => f.y < 8 * paq.filaH);
                ventana.comprobar(filas.length === 8, "  8 filas pintadas en la zona visible", filas.length);
                const aurs = ventana.todos(paq, "etiquetaAur").length;
                ventana.comprobar(aurs >= 1, "  las de AUR llevan su etiqueta", aurs);
                ventana.clicEn(b);
            }],
        [200, () => {
                ventana.comprobar(!paq.confirmando, "pulsar «Desinstalar» sin nada marcado no hace nada");
                ventana.captura(escena, "01-lista");
            }],
        [150, () => {
                ventana.teclear("fire");
            }],
        [200, () => {
                ventana.comprobar(ventana.igual(ventana.nombres(paq.visibles), ["firefox"]), "escribir filtra por nombre", ventana.nombres(paq.visibles).join(" "));
                ventana.comprobar(ventana.texto("cuentaPaquetes") === "1 de 15", "  y la cabecera dice «N de M»", ventana.texto("cuentaPaquetes"));
                ventana.comprobar(paq.implicitHeight === ventana.alto0, "  sin que el panel cambie de alto");
                ventana.campo().text = "GNU";
            }],
        [200, () => {
                ventana.comprobar(ventana.igual(ventana.nombres(paq.visibles), ["gimp", "glibc"]), "filtra también por la descripción, sin distinguir mayúsculas", ventana.nombres(paq.visibles).join(" "));
                ventana.captura(escena, "02-filtro");
            }],
        [150, () => {
                ventana.campo().text = "zzz";
            }],
        [200, () => {
                ventana.comprobar(paq.visibles.length === 0 && ventana.texto("mensajeLista") === "Nada coincide con \"zzz\"", "si no queda nada, lo dice", ventana.texto("mensajeLista"));
                ventana.comprobar(paq.implicitHeight === ventana.alto0, "  y el panel sigue igual de alto");
                ventana.captura(escena, "03-sin-resultados");
            }],
        [150, () => {
                ventana.clicEn(ventana.uno("borrarBusqueda"));
            }],
        [200, () => {
                ventana.comprobar(ventana.campo().text === "" && ventana.campo().activeFocus && paq.visibles.length === 15, "la ✕ vacía la búsqueda y deja el foco en el campo");
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                const r1 = paq.resalte;
                ventana.tecla(Qt.Key_Up);
                ventana.comprobar(r1 === 2 && paq.resalte === 1 && ventana.campo().activeFocus, "↑/↓ mueven el resalte con el foco en el buscador", r1 + " y " + paq.resalte);
                ventana.tecla(Qt.Key_Return);
                const marcado = ventana.igual(ventana.nombres(paq.elegidos), ["btop"]);
                ventana.tecla(Qt.Key_Return);
                const desmarcado = paq.nElegidos === 0;
                ventana.tecla(Qt.Key_Return);
                ventana.comprobar(marcado && desmarcado && ventana.igual(ventana.nombres(paq.elegidos), ["btop"]), "Enter marca la fila resaltada, y otra vez la desmarca");
                const b = ventana.boton("botonDesinstalar");
                ventana.comprobar(b.activo && b.texto === "Desinstalar (1)" && ventana.texto("seleccionados") === "1 seleccionado", "con una marcada: «Desinstalar (1)» encendido y «1 seleccionado»", b.texto + " / " + ventana.texto("seleccionados"));
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Return);
                ventana.comprobar(paq.resalte === 4 && paq.nElegidos === 1, "Enter en un protegido (glibc) no lo marca");
                ventana.tecla(Qt.Key_PageDown);
                ventana.tecla(Qt.Key_PageDown);
            }],
        [350, () => {
                const l = ventana.lista();
                ventana.comprobar(paq.resalte === 14 && Math.abs(l.contentY - (15 * paq.filaH - l.height)) < 1, "bajar hasta el final desplaza la lista para enseñar la fila", paq.resalte + ", y=" + Math.round(l.contentY));
                ventana.tecla(Qt.Key_PageUp);
                ventana.tecla(Qt.Key_PageUp);
            }],
        [350, () => {
                ventana.comprobar(paq.resalte === 0 && ventana.lista().contentY === 0, "y subir la devuelve arriba");
                // firefox por el centro y gimp por el canto de abajo (a 1 px de
                // la siguiente fila).
                ventana.clicFila(2, paq.filaH / 2);
                ventana.clicFila(3, paq.filaH - 1);
            }],
        [200, () => {
                ventana.comprobar(ventana.igual(ventana.nombres(paq.elegidos), ["btop", "firefox", "gimp"]), "un clic en la fila la marca, también pulsando en su canto de abajo", ventana.nombres(paq.elegidos).join(" "));
                ventana.comprobar(paq.resalte === 3 && ventana.campo().activeFocus, "  el resalte va a la fila pulsada y el teclado se queda en el buscador");
                ventana.clicFila(3, 1);
            }],
        [200, () => {
                ventana.comprobar(ventana.igual(ventana.nombres(paq.elegidos), ["btop", "firefox"]), "pulsar otra vez (por el canto de arriba) la desmarca");
                ventana.clicFila(3, paq.filaH / 2);
                ventana.clicFila(4, paq.filaH / 2);
            }],
        [200, () => {
                ventana.comprobar(ventana.igual(ventana.nombres(paq.elegidos), ["btop", "firefox", "gimp"]), "un clic en un protegido (glibc) no lo marca");
                const z = ventana.zona();
                ev.mouseMove(z, z.width / 2, 6 * paq.filaH + 20, -1, Qt.NoButton, Qt.NoModifier);
            }],
        [200, () => {
                ventana.comprobar(paq.resalte === 6, "el resalte sigue al ratón", paq.resalte);
                const z = ventana.zona();
                ev.mouseWheel(z, z.width / 2, 6 * paq.filaH + 20, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
            }],
        [350, () => {
                ventana.comprobar(ventana.lista().contentY === 2 * paq.filaH, "una muesca de rueda baja dos filas", Math.round(ventana.lista().contentY));
                ventana.comprobar(paq.resalte === 8, "  y el resalte sigue en la fila que queda bajo el ratón", paq.resalte);
                const lam = ventana.pieza("resalte");
                const yLam = lam.mapToItem(ventana.zona(), 0, 0).y;
                ventana.comprobar(lam.visible && yLam === 8 * paq.filaH - ventana.lista().contentY, "  y la lámina del resalte se desplaza con las filas (está pintada en esa fila)", "y=" + yLam);
                ventana.captura(escena, "04-rueda");
            }],
        [150, () => {
                // Con el ratón quieto encima de la lista, las flechas mandan.
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
                ventana.tecla(Qt.Key_Down);
            }],
        [350, () => {
                const l = ventana.lista();
                ventana.comprobar(paq.resalte === 14 && l.contentY === 15 * paq.filaH - l.height, "con el ratón quieto encima, las flechas mueven el resalte aunque la lista pase por debajo", paq.resalte + ", y=" + Math.round(l.contentY));
                const z = ventana.zona();
                ev.mouseWheel(z, z.width / 2, 6 * paq.filaH + 20, Qt.NoButton, Qt.NoModifier, 0, 1200, -1);
            }],
        [350, () => {
                ventana.comprobar(ventana.lista().contentY === 0, "la rueda hacia arriba no se pasa del principio");
                const b = ventana.boton("botonDesinstalar");
                ev.mouseMove(b, b.width / 2, b.height / 2, -1, Qt.NoButton, Qt.NoModifier);
            }],
        [250, () => {
                const b = ventana.boton("botonDesinstalar");
                ventana.comprobar(b.enRojo && b.color.r > b.color.g * 2, "al pasar por encima, «Desinstalar (3)» se tiñe de rojo", b.color + "");
                ventana.captura(escena, "05-seleccion");
            }],
        [150, () => {
                // Por el canto de abajo, como el botón del aviso que no se dejaba.
                const b = ventana.boton("botonDesinstalar");
                ventana.clicEn(b, b.width / 2, b.height - 2);
            }],
        [350, () => {
                ventana.comprobar(paq.confirmando && paq.eleccion === 0, "pulsar el botón (por su canto de abajo) pasa a la confirmación, con «Cancelar» elegido");
                ventana.comprobar(ventana.igual(ventana.nombresConfirmacion(), ["btop", "firefox", "gimp"]) && ventana.uno("masConfirmacion") === null && ventana.uno("avisoNecesitados") === null, "  con los nombres elegidos, en orden y sin aviso");
                ventana.comprobar(paq.implicitHeight < ventana.alto0, "  y el panel encoge (la isla se reajusta)", Math.round(paq.implicitHeight) + " < " + Math.round(ventana.alto0));
                ventana.comprobar(ventana.dentroDelPanel(ventana.boton("botonConfirmar")) && ventana.dentroDelPanel(ventana.boton("botonCancelar")), "  los dos botones caen enteros dentro del panel");
                ventana.comprobar(paq.activeFocus, "  el teclado pasa al panel (el buscador no se ve)");
                ventana.captura(escena, "06-confirmacion");
            }],
        [150, () => {
                ventana.tecla(Qt.Key_Return);
            }],
        [300, () => {
                ventana.comprobar(!paq.confirmando && paq.nElegidos === 3 && ventana.campo().activeFocus, "Enter en la confirmación es «Cancelar»: vuelve a la lista sin perder lo marcado");
                ventana.comprobar(paq.implicitHeight === ventana.alto0, "  y el panel vuelve a su alto");
                // Cinco más, buscando cada uno: lo marcado se conserva entre búsquedas.
                ["vlc", "neovim", "inkscape", "obsidian", "python-requests"].forEach(n => ventana.marcarBuscando(n));
                ventana.comprobar(ventana.igual(ventana.nombres(paq.elegidos), ["btop", "firefox", "gimp", "inkscape", "neovim", "obsidian", "python-requests", "vlc"]), "lo marcado se conserva al cambiar de búsqueda", ventana.nombres(paq.elegidos).join(" "));
                ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
            }],
        [350, () => {
                ventana.comprobar(paq.confirmando && ventana.igual(ventana.nombresConfirmacion(), ["btop", "firefox", "gimp", "inkscape", "neovim", "obsidian"]) && ventana.texto("masConfirmacion") === "y 2 más", "Ctrl+Enter pasa a la confirmación: seis nombres y «y 2 más»", ventana.texto("masConfirmacion"));
                const aviso = ventana.uno("avisoNecesitados");
                // Los guiones de los nombres no parten la línea (llevan un U+2060 detrás).
                const textoAviso = aviso ? aviso.children[1].text.replace(/\u2060/g, "") : "";
                ventana.comprobar(textoAviso === "Puede que pacman se niegue: otros paquetes necesitan python-requests y vlc.", "  y avisa, por su nombre, de los que necesitan otros paquetes", textoAviso);
                ventana.comprobar(ventana.dentroDelPanel(ventana.boton("botonConfirmar")), "  los botones siguen dentro del panel");
                ventana.captura(escena, "07-confirmacion-muchos");
            }],
        [150, () => {
                ventana.clicEn(ventana.boton("botonCancelar"));
            }],
        [300, () => {
                ventana.comprobar(!paq.confirmando && paq.nElegidos === 8, "«Cancelar» con el ratón también vuelve sin perder nada");
                ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
                ventana.tecla(Qt.Key_Right);
                const derecha = paq.eleccion;
                ventana.tecla(Qt.Key_Left);
                ventana.comprobar(derecha === 1 && paq.eleccion === 0, "en la confirmación, → elige «Desinstalar» y ← vuelve a «Cancelar»");
            }],
        // Un paso aparte: los Layout colocan lo que acaba de aparecer en el
        // fotograma siguiente, y antes el botón aún está donde no es.
        [200, () => {
                const b = ventana.boton("botonConfirmar");
                ev.mouseMove(b, b.width / 2, b.height / 2, -1, Qt.NoButton, Qt.NoModifier);
            }],
        [250, () => {
                ventana.comprobar(paq.eleccion === 1, "pasar el ratón por «Desinstalar» lo elige (lo que se ve elegido es lo que haría Enter)");
                ventana.captura(escena, "08-confirmar-hover");
            }],
        [150, () => {
                ventana.cierres0 = shellFalso.cierres;
                const b = ventana.boton("botonConfirmar");
                ventana.clicEn(b);
                ventana.clicEn(b);
            }],
        [100, () => {
                ventana.comprobar(shellFalso.mode === "" && shellFalso.cierres === ventana.cierres0 + 1, "«Desinstalar» cierra la isla (una vez)");
                ventana.comprobar(ventana.lanzadas.length === 0, "  y la terminal todavía no se ha lanzado (espera a que la isla se cierre)");
            }],
        [250, () => {
                const esperada = ["ghostty", "--title=Desinstalar", "-e", ventana.bin + "paquetes.sh", "desinstalar", "btop", "firefox", "gimp", "inkscape", "neovim", "obsidian", "python-requests", "vlc"];
                ventana.comprobar(ventana.lanzadas.length === 1, "pulsado dos veces, lanza una sola terminal", ventana.lanzadas.length + "");
                ventana.comprobar(ventana.lanzadas.length > 0 && ventana.igual(ventana.lanzadas[0], esperada), "  con la orden exacta: ghostty --title=Desinstalar -e <script> desinstalar <paquetes en orden>", ventana.lanzadas.length ? JSON.stringify(ventana.lanzadas[0]).replace(ventana.bin, "…/") : "");
                ventana.comprobar(!ventana.campo().activeFocus && !paq.activeFocus && teclado.activeFocus, "al cerrar, el teclado vuelve a la isla");
            }],
        [450, () => {
                ventana.comprobar(ventana.campo().text === "" && paq.nElegidos === 0 && !paq.confirmando && paq.paquetes.length === 0 && paq.estado === "", "al terminar de cerrarse, todo se olvida (búsqueda, selección, confirmación, lista)");
                ventana.vez0 = paq.vez;
                shellFalso.mode = "paquetes";
            }],
        [400, () => {
                ventana.comprobar(paq.estado === "listo" && paq.paquetes.length === 15 && paq.vez > ventana.vez0, "al volver a abrir se vuelve a leer la lista");
                ventana.comprobar(paq.nElegidos === 0 && !paq.confirmando && ventana.campo().activeFocus && ventana.lanzadas.length === 1, "  y empieza de cero, con el foco en el buscador");
                // Si el teclado estuviera en la isla (la ventana sin foco al
                // abrir), escribir busca igual.
                teclado.forceActiveFocus();
                ventana.teclear("v");
                ventana.comprobar(ventana.campo().text === "v" && ventana.campo().activeFocus, "con el teclado en la isla, escribir lleva al buscador", ventana.campo().text);
                ventana.cierres0 = shellFalso.cierres;
                ventana.tecla(Qt.Key_Escape);
            }],
        [300, () => {
                ventana.comprobar(shellFalso.mode === "" && shellFalso.cierres === ventana.cierres0 + 1, "Escape con el foco en el buscador cierra la isla");
                ventana.comprobar(teclado.activeFocus, "  y el teclado vuelve a la isla");
            }],
        [500, () => {
                paq.script = ventana.bin + "paquetes-falla.sh";
                shellFalso.mode = "paquetes";
            }],
        [400, () => {
                ventana.comprobar(paq.estado === "error" && ventana.texto("mensajeLista") === "No se pudo leer la lista de paquetes", "si el script falla, lo dice", ventana.texto("mensajeLista"));
                ventana.comprobar(ventana.uno("cuentaPaquetes") === null && !ventana.boton("botonDesinstalar").activo && paq.implicitHeight === ventana.alto0, "  sin cuenta, con el botón apagado y del mismo alto");
                ventana.tecla(Qt.Key_Return, Qt.ControlModifier);
                ventana.comprobar(!paq.confirmando, "  y Ctrl+Enter no hace nada");
                ventana.captura(escena, "09-error");
            }],
        [150, () => {
                shellFalso.mode = "";
            }],
        [500, () => {
                paq.script = ventana.bin + "no-existe.sh";
                shellFalso.mode = "paquetes";
            }],
        [400, () => {
                ventana.comprobar(paq.estado === "error", "si el script no está, también es un error (no se queda cargando)", paq.estado);
                shellFalso.mode = "";
            }],
        [500, () => {
                paq.script = ventana.bin + "paquetes-lento.sh";
                shellFalso.mode = "paquetes";
            }],
        [400, () => {
                ventana.comprobar(paq.estado === "cargando" && ventana.texto("mensajeLista") === "Cargando…", "mientras el script tarda: «Cargando…»", ventana.texto("mensajeLista"));
                ventana.comprobar(paq.implicitHeight === ventana.alto0, "  del mismo alto que la lista (la isla no salta al llegar)");
                ventana.captura(escena, "10-cargando");
            }],
        [1000, () => {
                ventana.comprobar(paq.estado === "listo" && paq.paquetes.length === 3, "y al terminar sale la lista", paq.paquetes.length + "");
                shellFalso.mode = "";
            }],
        [500, () => {
                // Abrir con el lento, cerrar enseguida y abrir con el bueno: lo
                // que conteste el lento después no puede pisar la lista nueva.
                shellFalso.mode = "paquetes";
            }],
        [150, () => {
                shellFalso.mode = "";
                paq.script = ventana.bin + "paquetes.sh";
            }],
        [50, () => shellFalso.mode = "paquetes"],
        [1400, () => {
                ventana.comprobar(paq.estado === "listo" && paq.paquetes.length === 15, "lo que llega de una lectura vieja (el panel se cerró a medias) se tira", paq.paquetes.length + "");
                // A otro panel sin cerrar la isla: el teclado vuelve a ella.
                shellFalso.mode = "power";
            }],
        [300, () => {
                ventana.comprobar(!ventana.campo().activeFocus && teclado.activeFocus, "al cambiar a otro panel, el buscador suelta el teclado");
                // --- El menú de sesión ---
                ventana.comprobar(ventana.igual(ventana.etiquetasMenu(), ["Bloquear", "Suspender", "Cerrar sesión", "Actualizar", "Desinstalar", "Reiniciar", "Apagar"]), "en el menú, «Desinstalar» va justo debajo de «Actualizar»", ventana.etiquetasMenu().join(", "));
                const f = ventana.filaMenu("Desinstalar");
                ventana.comprobar(f !== null && f.modelData.icon === "󰆴", "  con su icono");
                ventana.captura(escenaMenu, "11-menu");
            }],
        [150, () => {
                ventana.clicEn(ventana.filaMenu("Desinstalar"));
            }],
        [300, () => {
                ventana.comprobar(shellFalso.mode === "paquetes" && shellFalso.modeScreen === "prueba", "pulsar «Desinstalar» cambia la isla al panel de paquetes, en la misma pantalla", shellFalso.mode);
                ventana.comprobar(ventana.lanzadas.length === 1, "  sin lanzar nada");
                shellFalso.mode = "power";
            }],
        [300, () => {
                teclado.forceActiveFocus();
                ventana.tecla(Qt.Key_5);
            }],
        [300, () => {
                ventana.comprobar(shellFalso.mode === "paquetes", "el atajo 5 del menú es «Desinstalar» (los números se desplazan uno)", shellFalso.mode);
                shellFalso.mode = "power";
            }],
        [300, () => {
                teclado.forceActiveFocus();
                ventana.tecla(Qt.Key_7);
            }],
        [200, () => {
                ventana.comprobar(shellFalso.mode === "power" && menu.pending === 6 && menu.model[1].label === "Apagar", "y el 7 es «Apagar», que pide confirmación como antes", "pending " + menu.pending);
                shellFalso.mode = "";
            }],
        // --- La isla de verdad ---
        [300, () => {
                shellIsla.modeScreen = isla.screenName;
                shellIsla.mode = "power";
            }],
        [600, () => {
                const c = isla.pruebaCristal;
                ventana.comprobar(isla.open && isla.content === "power" && c.height === 26 + isla.pruebaMenu.implicitHeight, "la isla de verdad abre el menú de sesión", Math.round(c.width) + "×" + Math.round(c.height));
                ventana.cambiosIsla = 0;
                let fila = null;
                ventana.recorrer(isla.pruebaMenu, it => {
                    if (fila === null && it.modelData && it.modelData.label === "Desinstalar")
                        fila = it;
                });
                ventana.clicEn(fila);
            }],
        [600, () => {
                const c = isla.pruebaCristal;
                const p = isla.pruebaPaquetes;
                const r = isla.pruebaRegion;
                ventana.comprobar(shellIsla.mode === "paquetes" && isla.content === "paquetes" && isla.open && ventana.cambiosIsla === 0, "en la isla, «Desinstalar» cambia al panel de paquetes sin cerrarla", "cambios " + ventana.cambiosIsla);
                ventana.comprobar(c.width === 420 && c.height === 26 + p.implicitHeight, "  el cristal se reajusta al panel", Math.round(c.width) + "×" + Math.round(c.height));
                ventana.comprobar(isla.mask === r && r.width === 420 && r.height === 3 + 26 + p.implicitHeight + 2 && r.x === Math.round((isla.width - 420) / 2), "  la máscara de entrada pasa a medir el panel entero", r.x + "," + r.y + " " + r.width + "×" + r.height);
                const b = ventana.enIsla("botonDesinstalar");
                const z = ventana.enIsla("zonaLista");
                ventana.comprobar(b !== null && z !== null && ventana.enRegion(b, r) && ventana.enRegion(z, r), "  y el botón del pie y la lista caen enteros dentro de ella");
                ventana.comprobar(p.estado === "listo" && p.paquetes.length === 15 && p.script === Quickshell.env("HOME") + "/.config/hypr/scripts/paquetes.sh" && typeof p.lanzador === "function", "  lee la lista del script de siempre (~/.config/hypr/scripts/paquetes.sh), con el lanzador de verdad", p.estado);
                ventana.comprobar(isla.pruebaPastilla.children[2].active, "  el botón de sesión de la pastilla sigue encendido");
                const campo = ventana.enIsla("campoBuscar");
                ventana.comprobar(campo !== null && campo.activeFocus, "  el buscador tiene el teclado");
                ventana.altoIsla = c.height;
                ventana.teclear("vl");
            }],
        [300, () => {
                const campo = ventana.enIsla("campoBuscar");
                const p = isla.pruebaPaquetes;
                ventana.comprobar(campo.text === "vl" && ventana.igual(ventana.nombres(p.visibles), ["vlc"]) && isla.pruebaCristal.height === ventana.altoIsla, "  lo tecleado busca y la isla no cambia de alto", campo.text);
                ventana.captura(isla.pruebaCristal, "12-isla-paquetes");
            }],
        [150, () => {
                ventana.cierres0 = shellIsla.cierres;
                ventana.tecla(Qt.Key_Escape);
            }],
        [600, () => {
                ventana.comprobar(shellIsla.mode === "" && shellIsla.cierres === ventana.cierres0 + 1 && !isla.open, "  Escape en el buscador cierra la isla");
                // Abrirlo directo desde cerrada, como el IPC togglePaquetes: la
                // isla le da el teclado a su Item en el mismo cambio de modo.
                shellIsla.toggle(isla.screenName, "paquetes");
            }],
        [600, () => {
                const campo = ventana.enIsla("campoBuscar");
                ventana.comprobar(isla.open && isla.content === "paquetes" && campo !== null && campo.activeFocus && !isla.pruebaTeclado.activeFocus, "abierto directo (IPC), el buscador se queda con el teclado y no la isla");
                // Pulsar el reloj: otro panel sin cerrar la isla.
                shellIsla.toggle(isla.screenName, "calendar");
            }],
        [600, () => {
                ventana.comprobar(isla.content === "calendar" && isla.pruebaTeclado.activeFocus, "al pasar al calendario, el teclado vuelve a la isla (sus flechas siguen funcionando)");
                shellIsla.mode = "";
            }],
        [300, () => {
                console.log("Resultado: " + (ventana.hechas - ventana.fallos.length) + " de " + ventana.hechas + " bien" + (ventana.fallos.length ? "; fallan: " + ventana.fallos.join(" | ") : ""));
                Qt.quit();
            }]
    ]

    property int i: 0

    Timer {
        id: motor
        interval: 500
        running: true
        onTriggered: {
            if (ventana.i >= ventana.pasos.length)
                return;
            const p = ventana.pasos[ventana.i++];
            // Una excepción en un paso es un fallo, no el final de la prueba.
            try {
                p[1]();
            } catch (e) {
                ventana.comprobar(false, "excepción en el paso " + ventana.i + ": " + e);
            }
            motor.interval = ventana.i < ventana.pasos.length ? ventana.pasos[ventana.i][0] : 100;
            motor.restart();
        }
    }
}
