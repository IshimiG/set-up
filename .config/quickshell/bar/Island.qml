import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// La isla: el bloque central de la barra, que crece hasta ser el panel.
//
// La idea que había que conseguir es que no parezca una ventana que aparece
// encima, sino la barra desplegándose. De ahí las dos decisiones que mandan en
// todo este fichero:
//
//  1. La pastilla y el panel son el MISMO Rectangle. Lo único que se anima es su
//     geometría —ancho, alto y radio—, con la pastilla anclada arriba y el
//     contenido recortado por debajo. No hay dos superficies ni dos tarjetas.
//
//  2. La superficie de layer-shell es fija y a pantalla completa, y lo que se
//     mueve es el Item de dentro. Si la superficie creciera con la isla, el
//     compositor la redimensionaría en cada fotograma de la animación y además
//     aplicaría su propia animación de capa encima de la nuestra. Lo que evita
//     que una superficie a pantalla completa se coma todos los clics es la
//     máscara de entrada, que sigue al cristal.
PanelWindow {
    id: island

    required property var shell

    readonly property string screenName: island.screen ? island.screen.name : ""
    readonly property bool open: island.shell.open && island.shell.modeScreen === island.screenName

    // Qué contenido se pinta. Sigue al modo mientras está abierto, pero al
    // cerrar se conserva hasta que termina la animación: si se borrara al
    // instante, el panel encogería vacío.
    property string content: ""

    onOpenChanged: {
        if (island.open) {
            forget.stop();
            island.content = island.shell.mode;
        } else {
            forget.restart();
        }
    }

    // Cambiar de contenido con la isla ya abierta: el panel se reajusta, no se
    // cierra y vuelve a abrirse.
    Connections {
        target: island.shell
        function onModeChanged() {
            if (island.open)
                island.content = island.shell.mode;
        }
    }

    Timer {
        id: forget
        interval: island.durClose
        onTriggered: island.content = ""
    }

    // --- Medidas -----------------------------------------------------------
    // La pastilla tiene la altura y el margen de los bloques de waybar (height
    // 26, margin-top 3) para que las tres piezas de la barra queden alineadas
    // mientras waybar siga dibujando los lados.
    readonly property int pillH: 26
    readonly property int pillPad: 12
    readonly property int marginTop: 3
    // El radio de la pastilla es el border-radius de los bloques de waybar; el
    // del panel, el de las tarjetas del escritorio.
    readonly property int radiusPill: 10
    readonly property int radiusPanel: 18

    readonly property int durOpen: 340
    readonly property int durClose: 200
    // Reajustar de un contenido a otro va más rápido que abrir desde cero: la
    // isla ya está ahí, sólo cambia de tamaño.
    readonly property int durMorph: 260

    WlrLayershell.namespace: "isla"
    // Top y no Overlay: esto es la barra, y tiene que comportarse como ella.
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand y no Exclusive: el teclado lo trae el focus grab de abajo cuando
    // hay un panel abierto. Con Exclusive la isla se quedaría el teclado también
    // cerrada, y no hay nada que escribir en una pastilla con la hora.
    WlrLayershell.keyboardFocus: island.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // waybar ya reserva el alto de la barra; esta superficie no reserva nada.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // Escondida con SUPER+SHIFT+V. Un panel abierto la saca igualmente: si con
    // la barra escondida se pide el historial con su atajo, lo que se quiere es
    // verlo, no que no pase nada. Al cerrarlo vuelve a esconderse sola.
    visible: !island.shell.hidden || island.open

    // La máscara de entrada es justo el cristal. Todo lo que caiga fuera le
    // llega al escritorio como si esta superficie no existiera, y sigue a la
    // isla mientras se anima porque se declara por Item y no por rectángulo.
    mask: Region {
        item: glassEdge
    }

    // Clic en cualquier otro sitio: cierra. No hace falta un MouseArea a
    // pantalla completa —que además haría inútil la máscara—: Hyprland avisa de
    // que el foco se ha ido a otra parte.
    HyprlandFocusGrab {
        active: island.open
        windows: [island]
        onCleared: island.shell.close()
    }

    // Teclado. Escape cierra siempre; el resto se lo ofrece al panel abierto,
    // que es quien sabe si le sirve —las flechas y el Enter sólo significan algo
    // en el menú de sesión—.
    Item {
        anchors.fill: parent
        focus: island.open

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                island.shell.close();
                return;
            }
            const panel = island.activePanel;
            if (panel && panel.handleKey)
                event.accepted = panel.handleKey(event);
        }
    }

    // --- El cristal --------------------------------------------------------

    readonly property Item activePanel: island.content === "calendar" ? calendar : island.content === "notifications" ? notifications : island.content === "power" ? power : null

    readonly property int panelW: island.activePanel ? island.activePanel.implicitWidth : 0
    readonly property int panelH: island.activePanel ? island.activePanel.implicitHeight : 0

    // La capa exterior es *sólo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire. Es la
    // única forma de tener un borde con degradado en QML, porque un Rectangle
    // sólo admite un border.color plano.
    Rectangle {
        id: glassEdge

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: island.marginTop

        // Crece simétricamente alrededor del centro de la pantalla, así que la
        // hora no se mueve de su sitio mientras el cristal se abre a los lados.
        width: island.open ? Math.max(pill.implicitWidth + island.pillPad * 2, island.panelW) : pill.implicitWidth + island.pillPad * 2
        height: island.open ? island.pillH + island.panelH : island.pillH
        radius: island.open ? island.radiusPanel : island.radiusPill
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

        // El despliegue. Un solo Behavior por dimensión, con la duración
        // dependiendo de qué está pasando: abrir desde cero se toma su tiempo,
        // cerrar es más seco, y reajustar de un contenido a otro va en medio.
        Behavior on width {
            NumberAnimation {
                duration: island.open ? (island.content !== "" ? island.durMorph : island.durOpen) : island.durClose
                easing.type: island.open ? Easing.OutCubic : Easing.InOutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: island.open ? (island.content !== "" ? island.durMorph : island.durOpen) : island.durClose
                easing.type: island.open ? Easing.OutCubic : Easing.InOutCubic
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: island.open ? island.durOpen : island.durClose
                easing.type: Easing.OutCubic
            }
        }

        // El cuerpo esmerilado. Declarado antes que el contenido, así que queda
        // por debajo: en QML los hermanos se pintan en orden.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, glassEdge.radius - 1)

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

        // --- La pastilla: lo que se ve siempre ---
        RowLayout {
            id: pill

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            height: island.pillH
            spacing: 12

            Clock {
                shell: island.shell
                screenName: island.screenName
                active: island.open && island.shell.mode === "calendar"
            }

            Bell {
                shell: island.shell
                screenName: island.screenName
                active: island.open && island.shell.mode === "notifications"
            }

            PowerButton {
                shell: island.shell
                screenName: island.screenName
                active: island.open && island.shell.mode === "power"
            }
        }

        // --- El panel: lo que aparece al desplegarse ---
        // Recortado por el cristal, así que mientras la isla es una pastilla
        // esto simplemente no se ve. Los tres paneles existen a la vez y sólo
        // cambia cuál es opaco: así el cruce entre uno y otro es un fundido y
        // no un parpadeo.
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: pill.bottom
            anchors.bottom: parent.bottom
            clip: true

            CalendarPanel {
                id: calendar
                anchors.fill: parent
                shell: island.shell
                opacity: island.content === "calendar" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }

            NotificationsPanel {
                id: notifications
                anchors.fill: parent
                shell: island.shell
                opacity: island.content === "notifications" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }

            PowerPanel {
                id: power
                anchors.fill: parent
                shell: island.shell
                opacity: island.content === "power" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
