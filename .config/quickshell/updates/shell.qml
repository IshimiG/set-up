import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Aviso de paquetes pendientes al iniciar sesión: un disco en el centro de la
// pantalla con cuántas actualizaciones hay.
//
// Las cuentas no se hacen aquí. Las trae ya hechas
// ~/.config/hypr/scripts/updates-notify.sh en dos variables de entorno, y ese
// script sólo arranca esta configuración cuando hay algo que contar. Así el
// disco nunca aparece para decir que no hay nada, ni se queda un rato con un
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

    // Sin anclas: el compositor centra la superficie. Y la superficie es sólo
    // un poco mayor que el disco, no la pantalla entera, para no quedarse con
    // los clics del resto del escritorio durante los segundos que dura.
    implicitWidth: 300
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

    readonly property int diameter: 220

    // Las cuentas llegan por entorno. Un valor que no se pueda leer cuenta
    // como cero en vez de dejar un "NaN" en mitad del disco.
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

    Component.onCompleted: root.shown = true

    Timer {
        id: quitTimer
        interval: 220
        onTriggered: Qt.quit()
    }

    // Se va solo. Ocho segundos son suficientes para leer un número de dos
    // cifras sin que el aviso llegue a estorbar.
    Timer {
        running: true
        interval: 8000
        onTriggered: root.dismiss()
    }

    // La capa exterior es *solo* el canto: se pinta entera con el degradado
    // blanco y el cuerpo de cristal se dibuja encima dejando 1px al aire. Es la
    // única forma de conseguir un borde con degradado en QML, porque un
    // Rectangle solo admite un border.color plano.
    Rectangle {
        id: disc

        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter
        radius: width / 2

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

        scale: root.shown ? 1 : 0.7
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? 440 : 200
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.6
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
            radius: width / 2

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
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.total
                color: root.cSelected
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 58
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
                Layout.topMargin: 6
                visible: root.aur > 0
                text: root.repos + " repos  ·  " + root.aur + " AUR"
                color: root.cMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }

        // Un clic en el disco lo quita de en medio sin esperar a que se cumpla
        // el plazo. Va dentro del disco y no en la superficie entera para que
        // el resto de la pantalla siga siendo del escritorio.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: root.dismiss()
        }
    }
}
