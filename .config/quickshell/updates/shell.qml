import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Aviso de paquetes pendientes al iniciar sesión: una tarjeta colgada de la
// parte de arriba de la pantalla con cuántas actualizaciones hay y un botón
// para lanzarlas.
//
// Las cuentas no se hacen aquí. Las trae ya hechas
// ~/.config/hypr/scripts/updates-notify.sh en dos variables de entorno, y ese
// script sólo arranca esta configuración cuando hay algo que contar. Así la
// tarjeta nunca aparece para decir que no hay nada, ni se queda un rato con un
// "comprobando…" mientras checkupdates habla con los servidores.
PanelWindow {
    id: root

    // Namespace propio: le corresponde el layer_rule "updates-anim" de
    // ~/.config/hypr/hyprland.lua.
    WlrLayershell.namespace: "updates"
    WlrLayershell.layer: WlrLayer.Overlay
    // Un aviso no roba el teclado. Al iniciar sesión esto aparece encima de lo
    // que sea que esté arrancando, y quedarse con el foco sería justo la clase
    // de interrupción que un aviso no debe causar.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Anclada sólo arriba: el compositor la centra horizontalmente y la deja
    // colgando del borde superior, por debajo de la barra. La superficie es
    // algo mayor que la tarjeta para que el rebote de la animación no se corte
    // contra su propio borde, y no ocupa la pantalla entera para no quedarse
    // con los clics del resto del escritorio.
    anchors.top: true
    margins.top: 38
    implicitWidth: 420
    implicitHeight: 300

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

    // --- Glassmorphism ---------------------------------------------------
    // Mismos valores que el lanzador y el menú de sesión, que a su vez salen de
    // waybar. Si cambias uno, cambia los tres.
    readonly property color cGlassTop: Qt.rgba(0, 0, 0, 0.76)
    readonly property color cGlassBottom: Qt.rgba(0, 0, 0, 0.64)
    readonly property color cEdgeTop: Qt.rgba(1, 1, 1, 0.30)
    readonly property color cEdgeBottom: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cText: Qt.rgba(1, 1, 1, 0.78)
    readonly property color cSelected: "#ffffff"
    readonly property color cMuted: Qt.rgba(1, 1, 1, 0.55)

    readonly property int cardW: 320
    readonly property int pad: 22

    // Actualiza repos y AUR de una vez. No lleva sudo delante a propósito:
    // paru lo pide por su cuenta cuando le hace falta y se niega a arrancar
    // como root, porque compilar paquetes del AUR con privilegios es
    // justamente lo que no se debe hacer. La terminal se queda abierta al
    // terminar para poder leer lo que ha pasado.
    readonly property string updateCmd: "paru -Syu; printf '\\n'; read -r -p 'Pulsa Enter para cerrar… '"

    // Las cuentas llegan por entorno. Un valor que no se pueda leer cuenta
    // como cero en vez de dejar un "NaN" en mitad de la tarjeta.
    function count(name) {
        const raw = parseInt(Quickshell.env(name), 10);
        return isNaN(raw) ? 0 : raw;
    }

    readonly property int repos: count("UPDATES_REPO")
    readonly property int aur: count("UPDATES_AUR")
    readonly property int total: repos + aur

    property bool shown: false

    function dismiss() {
        if (!root.shown)
            return;
        root.shown = false;
        quitTimer.start();
    }

    function runUpdate() {
        Quickshell.execDetached(["ghostty", "--title=Actualizar", "-e", "bash", "-c", root.updateCmd]);
        root.dismiss();
    }

    Component.onCompleted: root.shown = true

    Timer {
        id: quitTimer
        interval: 220
        onTriggered: Qt.quit()
    }

    // Se va sola, pero no mientras el ratón esté encima: con un botón dentro,
    // desaparecer justo cuando vas a pulsarlo sería lo peor que podría hacer.
    // Al apartar el ratón vuelve a contar desde cero, que es tiempo de sobra.
    Timer {
        running: !cardHover.hovered
        interval: 20000
        onTriggered: root.dismiss()
    }

    // La capa exterior es *solo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire. Es la
    // única forma de conseguir un borde con degradado en QML, porque un
    // Rectangle solo admite un border.color plano.
    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10

        width: root.cardW
        height: content.implicitHeight + root.pad * 2
        radius: 20

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

        // Cae desde el borde de arriba: el origen de la escala es la parte
        // superior, así que la tarjeta se despliega hacia abajo en vez de
        // crecer desde su centro.
        transformOrigin: Item.Top
        scale: root.shown ? 1 : 0.86
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? 440 : 200
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.2
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 160 : 200
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, card.radius - 1)

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

        HoverHandler {
            id: cardHover
        }

        // Un clic en la tarjeta la quita de en medio sin esperar al plazo. El
        // botón está por delante y se queda con los suyos, así que pulsarlo no
        // cuenta como descartar.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: root.dismiss()
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.total
                color: root.cSelected
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 54
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.total === 1 ? "actualización" : "actualizaciones"
                color: root.cText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }

            // El desglose sólo aparece cuando hay algo del AUR que separar:
            // con todo viniendo de los repos, la línea no diría nada nuevo.
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                visible: root.aur > 0
                text: root.repos + " repos  ·  " + root.aur + " AUR"
                color: root.cMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            // El botón es otra lámina de cristal, una capa por encima: blanca y
            // casi transparente, con un filo que la levanta de la superficie.
            Rectangle {
                id: button

                Layout.fillWidth: true
                Layout.topMargin: 16
                implicitHeight: 40
                radius: 12

                color: Qt.rgba(1, 1, 1, buttonHover.hovered ? 0.20 : 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, buttonHover.hovered ? 0.38 : 0.20)

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

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 9

                    Text {
                        text: "󰚰"
                        color: root.cSelected
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                    }

                    Text {
                        text: "Actualizar ahora"
                        color: root.cSelected
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }

                HoverHandler {
                    id: buttonHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.runUpdate()
                }
            }
        }
    }
}
