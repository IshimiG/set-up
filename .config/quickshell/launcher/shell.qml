import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "shared"

PanelWindow {
    id: root

    // Namespace matches the layer_rule in ~/.config/hypr/hyprland.lua.
    WlrLayershell.namespace: "launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // Fullscreen transparent surface: the card is centered inside and animated
    // in QML, so the compositor never resizes the surface itself.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // El cristal, el texto y la tipografía salen del Theme compartido
    // (~/.config/quickshell/shared/Theme.qml), que llega por el symlink
    // "shared" de este directorio. Allí está el porqué de cada valor, incluido
    // el alfa mínimo de 0.5 que el ignore_alpha del layer_rule necesita para
    // seguir desenfocando.

    property string query: ""

    // --- Residente --------------------------------------------------------
    // El lanzador ya no es un proceso por cada SUPER+SPACE. Arranca una vez con
    // la sesión (hyprland.lua) y se abre y se cierra por IPC, igual que la isla
    // de la barra. Cuando era un proceso nuevo, Quickshell tardaba ~0,4 s en
    // arrancar y otros 0,3-0,5 s en pintar el primer fotograma —leer los
    // .desktop, crear las filas, cargar los iconos—, y la animación, que
    // arrancaba al crearse y no al verse, se consumía en esa espera: el primer
    // fotograma salía con la tarjeta casi entera y el resto a trompicones
    // (medido: huecos de 90-160 ms entre fotogramas durante el despliegue).
    //
    // "mapped" es que la superficie exista; "shown", que la tarjeta esté
    // desplegada. Van separadas por lo mismo que en la isla: poner visible a
    // false destruye la superficie al instante, así que al cerrar se recoge
    // primero la tarjeta y sólo después se quita la superficie.
    property bool mapped: false
    property bool shown: false
    // Entre que la superficie se crea y la animación puede arrancar.
    property bool esperandoFotograma: false
    property int fotogramas: 0

    visible: root.mapped

    function openLauncher() {
        if (root.shown || root.esperandoFotograma)
            return;
        cierre.stop();
        input.text = "";
        list.currentIndex = filtered.values.length > 0 ? 0 : -1;
        list.positionViewAtBeginning();
        content.opacity = 0;
        root.fotogramas = 0;
        root.esperandoFotograma = true;
        root.mapped = true;
        porSiAcaso.restart();
    }

    function closeLauncher() {
        if (!root.mapped)
            return;
        root.esperandoFotograma = false;
        root.shown = false;
        cierre.restart();
    }

    function toggleLauncher() {
        if (root.shown || root.esperandoFotograma)
            root.closeLauncher();
        else
            root.openLauncher();
    }

    function launchSelected() {
        const item = list.currentItem;
        if (item && item.modelData) {
            item.modelData.execute();
            root.closeLauncher();
        }
    }

    // La animación arranca con la superficie ya en pantalla, no antes: así se
    // ve entera, desde el punto, en vez de empezar a medias.
    //
    // Se espera al segundo fotograma y no al primero. Entre los dos pasan
    // 60-90 ms (medido en el portátil, con la capa recién creada) y, arrancando
    // en el primero, ese hueco caía dentro de la animación: se perdía el 15 %
    // inicial, que con el rebote es casi la mitad del recorrido. La tarjeta
    // todavía es invisible en ese rato, así que esperar no se nota.
    function desplegar() {
        if (!root.esperandoFotograma)
            return;
        root.esperandoFotograma = false;
        root.shown = true;
        input.forceActiveFocus();
    }

    Connections {
        target: card.Window.window
        enabled: root.esperandoFotograma
        function onFrameSwapped() {
            root.fotogramas++;
            if (root.fotogramas >= 2)
                root.desplegar();
        }
    }

    // Si por lo que sea el aviso del fotograma no llega, la tarjeta se
    // despliega igual al rato en vez de quedarse sin aparecer.
    // Tiene que quedar por encima de lo que tarda el segundo fotograma (unos
    // 150 ms), o se adelantaría a él.
    Timer {
        id: porSiAcaso
        interval: 300
        onTriggered: root.desplegar()
    }

    onShownChanged: if (root.shown)
        aparecerContenido.restart()

    Timer {
        id: cierre
        interval: 180
        onTriggered: root.mapped = false
    }

    // SUPER+SPACE llama a toggle. Si el proceso no estaba vivo, hyprland.lua lo
    // arranca con LAUNCHER_ABRIR=1 para que esa misma pulsación ya lo abra.
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggleLauncher();
        }

        function open(): void {
            root.openLauncher();
        }

        function close(): void {
            root.closeLauncher();
        }
    }

    Component.onCompleted: if (Quickshell.env("LAUNCHER_ABRIR") === "1")
        root.openLauncher()

    // Circular reveal: the card starts as a small circle (seed x seed, radius
    // half of that) and grows into the full rounded rectangle, so the shape
    // morphs from a dot rather than just scaling a rectangle up.
    readonly property int seed: 84
    readonly property int cardW: 720
    readonly property int rowH: 42
    readonly property int pad: 20
    // Driven by the content's own height (the list is an exact number of whole
    // rows), so no entry is ever cut off at the bottom edge.
    readonly property int cardH: content.implicitHeight + root.pad * 2

    // Clic fuera de la tarjeta: cierra el lanzador, sin tener que pulsar
    // Escape. La superficie ocupa la pantalla entera, así que todo clic llega
    // aquí; sólo hay que distinguir los que caen sobre el cristal.
    //
    // Va declarado antes que la tarjeta a propósito: en QML los hermanos se
    // pintan en orden, así que esto queda por debajo y los clics sobre la
    // tarjeta —una fila de la lista, el campo de búsqueda— los atienden primero
    // sus propios manejadores. Un Rectangle no consume eventos de ratón, sin
    // embargo, de modo que un clic sobre una zona vacía del cristal sí bajaría
    // hasta este MouseArea: de ahí la comprobación geométrica contra la
    // tarjeta, que es lo que evita que el lanzador se cierre al clicar dentro.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            const p = mapToItem(card, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height)
                root.closeLauncher();
        }
    }

    // La capa exterior es *solo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire.
    // Es la única forma de conseguir un borde con degradado en QML, porque
    // un Rectangle solo admite un border.color plano.
    Rectangle {
        id: card
        anchors.centerIn: parent

        width: root.shown ? root.cardW : root.seed
        height: root.shown ? root.cardH : root.seed
        radius: root.shown ? 24 : root.seed / 2
        clip: true

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.edgeTop
            }
            GradientStop {
                position: 1.0
                color: Theme.edgeBottom
            }
        }

        // El cuerpo esmerilado. Va declarado antes que "content", así que
        // queda por debajo: en QML los hermanos se pintan en orden.
        Rectangle {
            id: glass
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, card.radius - 1)
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.glassTop
                }
                GradientStop {
                    position: 1.0
                    color: Theme.glassBottom
                }
            }
        }

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 120 : 140
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: root.shown ? 460 : 180
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 3.2
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.shown ? 520 : 180
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.8
            }
        }
        // The corner radius catches up faster than the box, so the silhouette
        // reads as a circle first and settles into a rounded rectangle.
        Behavior on radius {
            NumberAnimation {
                duration: 340
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: content
            // Anchored to the top only: its height comes from its children,
            // which is what the card's height is derived from.
            //
            // El ancho es fijo, el de la tarjeta ya desplegada, y no va atado a
            // los lados de la tarjeta. Atado a ellos, cada fotograma del
            // despliegue cambiaba el ancho y obligaba a recolocar el campo de
            // búsqueda, la lista y cada fila (con su texto recortado) aunque
            // todavía fueran invisibles. Así sólo se desplaza, y lo que sobra
            // mientras la tarjeta es pequeña lo recorta el clip.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.pad
            width: root.cardW - root.pad * 2
            spacing: 12

            // Held back until the box has most of its size, otherwise the text
            // is visibly cut by the circle while it is still expanding.
            opacity: 0
            SequentialAnimation {
                id: aparecerContenido
                PauseAnimation {
                    duration: 190
                }
                NumberAnimation {
                    target: content
                    property: "opacity"
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "›"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 22
                }

                TextField {
                    id: input
                    Layout.fillWidth: true
                    focus: true
                    placeholderText: "Buscar aplicación…"
                    placeholderTextColor: Theme.muted
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 17
                    padding: 0
                    background: Rectangle {
                        color: "transparent"
                    }

                    onTextChanged: {
                        root.query = text;
                        list.currentIndex = filtered.values.length > 0 ? 0 : -1;
                    }

                    Keys.onEscapePressed: root.closeLauncher()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Up) {
                            event.accepted = true;
                            if (list.currentIndex > 0)
                                list.currentIndex--;
                        } else if (event.key === Qt.Key_Down) {
                            event.accepted = true;
                            if (list.currentIndex < list.count - 1)
                                list.currentIndex++;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true;
                            root.launchSelected();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            ScriptModel {
                id: filtered
                values: {
                    const all = [...DesktopEntries.applications.values];
                    const q = root.query.trim().toLowerCase();
                    const matched = q === "" ? all : all.filter(d => d.name && d.name.toLowerCase().includes(q));
                    // DesktopEntries yields hash order, which differs between
                    // runs. localeCompare keeps accented names in the right
                    // place for Spanish.
                    return matched.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(1, Math.min(9, list.count)) * root.rowH
                clip: true
                model: filtered.values
                currentIndex: 0
                keyNavigationWraps: true
                highlightMoveDuration: 140
                highlightResizeDuration: 0

                // La fila activa es otra lámina de cristal, una capa por
                // encima: tinte del acento más un filo blanco que la levanta
                // de la superficie en vez de limitarse a colorearla.
                highlight: Rectangle {
                    radius: 12
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: root.rowH

                    // Staggered entrance: each row slides in slightly after the
                    // one above it, which is what makes the list feel alive.
                    opacity: 0
                    transform: Translate {
                        id: rowShift
                        x: 14
                    }

                    // Con el lanzador residente las filas sobreviven de una
                    // apertura a otra, así que la entrada se repite al
                    // desplegar. Se devuelven antes a su punto de partida: si
                    // no, durante la pausa del escalonado se verían quietas y
                    // de golpe se apagarían para volver a entrar.
                    function entrar() {
                        row.opacity = 0;
                        rowShift.x = 14;
                        entrada.restart();
                    }

                    Connections {
                        target: root
                        function onShownChanged() {
                            if (root.shown)
                                row.entrar();
                        }
                    }

                    SequentialAnimation {
                        id: entrada
                        running: true
                        PauseAnimation {
                            duration: Math.min(row.index, 9) * 26
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: row
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: rowShift
                                property: "x"
                                from: 14
                                to: 0
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        IconImage {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            // Fuera del hilo de la interfaz: al filtrar entran
                            // filas nuevas, y cargar sus iconos de golpe
                            // (muchos son SVG que hay que rasterizar) congelaba
                            // la lista mientras se escribía.
                            asynchronous: true
                            source: Quickshell.iconPath(row.modelData.icon, true)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: list.currentIndex === row.index ? Theme.strong : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 15
                            elide: Text.ElideRight
                        }
                    }

                    TapHandler {
                        onTapped: {
                            list.currentIndex = row.index;
                            root.launchSelected();
                        }
                    }
                }
            }
        }
    }
}
