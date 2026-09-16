import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

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

    property string query: ""
    property bool shown: false

    function closeLauncher() {
        root.shown = false;
        quitTimer.start();
    }

    function launchSelected() {
        const item = list.currentItem;
        if (item && item.modelData) {
            item.modelData.execute();
            root.closeLauncher();
        }
    }

    Component.onCompleted: root.shown = true

    Timer {
        id: quitTimer
        interval: 180
        onTriggered: Qt.quit()
    }

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
                color: root.cEdgeTop
            }
            GradientStop {
                position: 1.0
                color: root.cEdgeBottom
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
                    color: root.cGlassTop
                }
                GradientStop {
                    position: 1.0
                    color: root.cGlassBottom
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
            // Anchored top/left/right only: its height comes from its children,
            // which is what the card's height is derived from.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 12

            // Held back until the box has most of its size, otherwise the text
            // is visibly squashed while the circle is still expanding.
            opacity: 0
            SequentialAnimation {
                running: true
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
                    color: root.cAccent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                }

                TextField {
                    id: input
                    Layout.fillWidth: true
                    focus: true
                    placeholderText: "Buscar aplicación…"
                    placeholderTextColor: root.cMuted
                    color: root.cText
                    font.family: "JetBrainsMono Nerd Font"
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
                color: root.cRule
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

                    // Staggered entrance: each row slides in slightly after the
                    // one above it, which is what makes the list feel alive.
                    opacity: 0
                    transform: Translate {
                        id: rowShift
                        x: 14
                    }

                    SequentialAnimation {
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
                            source: Quickshell.iconPath(row.modelData.icon, true)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: list.currentIndex === row.index ? root.cSelected : root.cText
                            font.family: "JetBrainsMono Nerd Font"
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
