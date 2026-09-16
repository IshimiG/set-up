import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Menú de sesión de la barra: bloquear, suspender, cerrar sesión, reiniciar y
// apagar. Sustituye al fuzzel en modo dmenu que había antes.
//
// El motivo del cambio es el cierre con un clic fuera. fuzzel toma el teclado
// en exclusiva y no sabe cerrarse por un clic; su modo --keyboard-focus=on-demand
// tampoco vale aquí, porque con follow_mouse = 1 el menú se cierra en cuanto el
// ratón sale de él —y ni siquiera llega a abrirse si el cursor no está justo
// encima al aparecer—. Una superficie propia a pantalla completa sí puede
// distinguir dónde ha caído el clic, que es exactamente lo que hace el
// lanzador de ~/.config/quickshell/launcher/shell.qml.
PanelWindow {
    id: root

    // Namespace propio: le corresponde el layer_rule "powermenu-anim" de
    // ~/.config/hypr/hyprland.lua. No comparte el del lanzador porque cada uno
    // anima su tarjeta a su manera.
    WlrLayershell.namespace: "powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // El menú cuelga del botón de apagado de la barra, y la barra está en los
    // dos monitores, así que tiene que dibujarse en aquel donde se ha hecho
    // clic. Hyprland no lo dice directamente, pero el monitor con el foco es
    // el mismo: pulsar un módulo de waybar mueve el foco a ese monitor.
    // Si por lo que sea no hay respuesta, null deja que Quickshell elija la
    // pantalla por defecto, que es mejor que no dibujar nada.
    screen: {
        const focused = Hyprland.focusedMonitor;
        if (!focused)
            return null;
        const all = Quickshell.screens;
        for (let i = 0; i < all.length; i++) {
            if (all[i].name === focused.name)
                return all[i];
        }
        return null;
    }

    color: "transparent"

    // Superficie a pantalla completa: la tarjeta se coloca dentro y se anima en
    // QML, así el compositor nunca redimensiona la superficie. Es también lo
    // que permite recibir los clics que caen fuera de la tarjeta.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // --- Glassmorphism ---------------------------------------------------
    // La paleta sale de waybar (~/Projects/set-up/.config/waybar/style.css) y
    // no al revés: la barra es la referencia y no se toca, así que lo que
    // flota sobre el escritorio se ajusta a ella. Allí el cuerpo es
    // rgba(0, 0, 0, 0.7), el texto es blanco y el color sólo aparece en los
    // estados (verde "algo está sonando", naranja, rojo). Aquí no hay estados
    // que señalar, de modo que todo es blanco sobre negro translúcido.
    //
    // El material sigue siendo una lámina de vidrio: el cuerpo es negro
    // translúcido con un degradado vertical —algo más denso arriba, donde la
    // lámina recoge la luz— y el canto es una lámina blanca aparte que va de
    // brillante a casi invisible, como la luz resbalando por el borde.
    //
    // El alfa del cuerpo no puede bajar de 0.5: el layer_rule de
    // ~/.config/hypr/hyprland.lua usa ignore_alpha = 0.5 y por debajo de ese
    // umbral Hyprland deja de desenfocar esta superficie y el cristal se queda
    // liso, sin el frosted.
    readonly property color cGlassTop: Qt.rgba(0, 0, 0, 0.76)
    readonly property color cGlassBottom: Qt.rgba(0, 0, 0, 0.64)

    // Canto: blanco puro, igual que el borde de ventana de Hyprland. Sólo
    // varía el alfa, y va mucho más contenido que sobre cristal claro porque
    // un filo brillante sobre negro se lee como un subrayado.
    readonly property color cEdgeTop: Qt.rgba(1, 1, 1, 0.30)
    readonly property color cEdgeBottom: Qt.rgba(1, 1, 1, 0.08)

    readonly property color cText: Qt.rgba(1, 1, 1, 0.78)
    readonly property color cSelected: "#ffffff"
    // Mismo atenuado que usa la barra para lo que está ahí pero no reclama la
    // vista (#custom-power y #custom-expand-icon en reposo van a opacity 0.55).
    readonly property color cMuted: Qt.rgba(1, 1, 1, 0.55)
    // El resalte no es un color de marca: es otra lámina de cristal, blanca y
    // casi transparente, encima de la anterior.
    readonly property color cAccent: "#ffffff"
    readonly property color cRule: Qt.rgba(1, 1, 1, 0.12)

    // Geometría. Los márgenes son los que tenía el fuzzel (--x-margin=14,
    // --y-margin=38), para que el menú siga cayendo donde se espera: debajo de
    // la barra, pegado al borde derecho.
    readonly property int cardW: 260
    readonly property int rowH: 38
    readonly property int pad: 16
    readonly property int marginRight: 14
    readonly property int marginTop: 38

    property bool shown: false

    // Las tres acciones destructivas piden confirmación en un segundo menú
    // cuya primera entrada —la preseleccionada— es "Cancelar", así que un
    // Enter de más no apaga el equipo. La decisión va por índice, no por el
    // texto, para que cambiar un glifo no rompa nada.
    readonly property var entries: [
        {
            icon: "󰌾",
            label: "Bloquear",
            cmd: "hyprlock",
            confirm: ""
        },
        {
            icon: "󰒲",
            label: "Suspender",
            // Bloquear antes de suspender, no después: si la pantalla se apaga
            // primero, hay una ventana en la que el escritorio queda visible
            // al despertar.
            cmd: "hyprlock & sleep 0.4; systemctl suspend",
            confirm: ""
        },
        {
            icon: "󰗽",
            label: "Cerrar sesión",
            cmd: "hyprctl dispatch exit",
            confirm: "Cerrar sesión"
        },
        {
            icon: "󰜉",
            label: "Reiniciar",
            cmd: "systemctl reboot",
            confirm: "Reiniciar"
        },
        {
            icon: "󰐥",
            label: "Apagar",
            cmd: "systemctl poweroff",
            confirm: "Apagar"
        }
    ]

    // -1 = menú normal. Cualquier otro valor es el índice de la entrada que
    // está esperando confirmación, y la lista pasa a ser Cancelar / acción.
    property int pending: -1

    readonly property var model: pending < 0 ? entries : [
        {
            icon: "󰅖",
            label: "Cancelar",
            cmd: "",
            confirm: ""
        },
        {
            icon: entries[pending].icon,
            label: entries[pending].confirm,
            cmd: entries[pending].cmd,
            confirm: ""
        }
    ]

    readonly property string title: pending < 0 ? "Sesión" : "¿Seguro?"
    readonly property string titleIcon: pending < 0 ? "󰐥" : "󰀦"

    // El comando se guarda y se lanza cuando la animación de cierre ha
    // terminado, no antes: hyprlock levanta su propia superficie y, si se
    // solapan, el menú se queda un instante por encima del bloqueo.
    property string queuedCmd: ""

    function closeMenu() {
        root.shown = false;
        quitTimer.start();
    }

    function run(cmd) {
        root.queuedCmd = cmd;
        root.closeMenu();
    }

    function activate(i) {
        const entry = root.model[i];
        if (root.pending >= 0) {
            // Cancelar (índice 0) cierra el menú entero, igual que hacía el
            // script de fuzzel: al rechazar la confirmación, terminaba.
            if (i === 0)
                root.closeMenu();
            else
                root.run(entry.cmd);
            return;
        }
        if (entry.confirm !== "") {
            root.pending = i;
            list.currentIndex = 0;
        } else {
            root.run(entry.cmd);
        }
    }

    // El botón de la barra se enciende mientras el menú está abierto, y para
    // saberlo depende de esta señal: SIGRTMIN+9 hace que waybar vuelva a
    // ejecutar power-state.sh. Se avisa al abrir y al cerrar porque el menú
    // puede cerrarse por su cuenta —Escape, un clic fuera, elegir una
    // opción— sin que la barra se entere de nada.
    function notifyBar() {
        Quickshell.execDetached(["pkill", "-RTMIN+9", "waybar"]);
    }

    Component.onCompleted: {
        root.shown = true;
        root.notifyBar();
    }

    Timer {
        id: quitTimer
        interval: 160
        onTriggered: {
            root.notifyBar();
            if (root.queuedCmd !== "")
                Quickshell.execDetached(["sh", "-c", root.queuedCmd]);
            Qt.quit();
        }
    }

    // Clic fuera de la tarjeta: cierra el menú, sin tener que pulsar Escape.
    // Declarado antes que la tarjeta a propósito: en QML los hermanos se pintan
    // en orden, así que esto queda por debajo y los clics sobre una fila los
    // atiende primero su propio manejador. Un Rectangle no consume eventos de
    // ratón, de modo que un clic sobre el cristal vacío sí bajaría hasta aquí:
    // de ahí la comprobación geométrica contra la tarjeta.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            const p = mapToItem(card, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height)
                root.closeMenu();
        }
    }

    // Teclado. Va en un Item propio con el foco en lugar de en la tarjeta
    // porque la tarjeta cambia de tamaño y de contenido al pasar a la
    // confirmación, y el foco no debe depender de eso.
    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.closeMenu();
            } else if (event.key === Qt.Key_Up) {
                event.accepted = true;
                if (list.currentIndex > 0)
                    list.currentIndex--;
            } else if (event.key === Qt.Key_Down) {
                event.accepted = true;
                if (list.currentIndex < list.count - 1)
                    list.currentIndex++;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                root.activate(list.currentIndex);
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                // Atajo directo por número, contando desde 1 arriba.
                const i = event.key - Qt.Key_1;
                if (i < root.model.length) {
                    event.accepted = true;
                    list.currentIndex = i;
                    root.activate(i);
                }
            }
        }
    }

    // La capa exterior es *solo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire. Es la
    // única forma de conseguir un borde con degradado en QML, porque un
    // Rectangle solo admite un border.color plano.
    Rectangle {
        id: card

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.marginRight
        anchors.topMargin: root.marginTop

        width: root.cardW
        height: content.implicitHeight + root.pad * 2
        radius: 18
        clip: true

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.cEdgeTop
            }
            GradientStop {
                position: 1.0
                color: root.cEdgeBottom
            }
        }

        // Cae desde el botón que lo abre: el origen de la escala es la esquina
        // superior derecha, así que la tarjeta se despliega hacia abajo y hacia
        // la izquierda en vez de crecer desde su centro.
        transformOrigin: Item.TopRight
        scale: root.shown ? 1 : 0.82
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? 380 : 150
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.4
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 110 : 140
                easing.type: Easing.OutCubic
            }
        }
        // El paso a la confirmación deja la tarjeta en dos filas en vez de
        // cinco; sin esto el salto de altura es brusco.
        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // El cuerpo esmerilado. Declarado antes que "content", así que queda
        // por debajo: en QML los hermanos se pintan en orden.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, card.radius - 1)
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.cGlassTop
                }
                GradientStop {
                    position: 1.0
                    color: root.cGlassBottom
                }
            }
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.titleIcon
                    color: root.cAccent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.cMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: root.cRule
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: list.count * root.rowH
                interactive: false
                model: root.model
                currentIndex: 0
                highlightMoveDuration: 140
                highlightResizeDuration: 0

                // La fila activa es otra lámina de cristal, una capa por
                // encima: tinte del acento más un filo blanco que la levanta de
                // la superficie en vez de limitarse a colorearla.
                highlight: Rectangle {
                    radius: 10
                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: root.rowH

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: row.modelData.icon
                            color: list.currentIndex === row.index ? root.cSelected : root.cText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.label
                            color: list.currentIndex === row.index ? root.cSelected : root.cText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                    }

                    // El resalte sigue al ratón, de modo que lo que se ve
                    // seleccionado y lo que ejecutaría un Enter son siempre lo
                    // mismo, aunque se haya llegado hasta ahí con el teclado.
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                list.currentIndex = row.index;
                        }
                    }

                    TapHandler {
                        onTapped: {
                            list.currentIndex = row.index;
                            root.activate(row.index);
                        }
                    }
                }
            }
        }
    }
}
