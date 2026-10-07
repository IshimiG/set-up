import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// Aviso de paquetes pendientes al iniciar sesión: una tarjeta colgada de la
// parte de arriba de la pantalla con cuántas actualizaciones hay y un botón
// para lanzarlas.
//
// Tiene tres salidas, y conviene no confundirlas: el botón lanza la
// actualización, un clic en el cristal la descarta —se acabó hasta el próximo
// arranque— y la flecha de arriba sólo la esconde, dejando una pestañita
// colgando para volver a bajarla. Esconder existe porque la tarjeta cae encima
// de lo que sea que esté arrancando, y querer apartarla un momento no es lo
// mismo que querer olvidarse de las actualizaciones.
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

    // De esos 420x300 sólo recibe clics lo que de verdad se está viendo: la
    // tarjeta, o la pestaña cuando está escondida. Sin esta máscara la
    // superficie entera se quedaría con los clics de su rectángulo, que
    // escondida es justo lo contrario de lo que se ha pedido: apartarla de en
    // medio y seguir usando el escritorio que hay debajo.
    mask: Region {
        item: root.collapsed ? tab : card
    }

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

    // El cristal, el texto y la tipografía salen del Theme compartido
    // (~/.config/quickshell/shared/Theme.qml), que llega por el symlink
    // "shared" de este directorio. Allí está el porqué de cada valor, incluido
    // el alfa mínimo de 0.5 que el ignore_alpha del layer_rule necesita para
    // seguir desenfocando.

    readonly property int cardW: 320
    readonly property int pad: 22

    // Actualiza repos y AUR de una vez. No lleva sudo delante a propósito:
    // paru lo pide por su cuenta cuando le hace falta y se niega a arrancar
    // como root, porque compilar paquetes del AUR con privilegios es
    // justamente lo que no se debe hacer. La terminal se queda abierta al
    // terminar para poder leer lo que ha pasado.
    //
    // paru en la torre (CachyOS) y yay en el portátil, que es el que trajo
    // Omarchy. Los dos aceptan -Syu igual y piden sudo igual.
    readonly property string updateCmd: "if command -v paru >/dev/null; then paru -Syu; else yay -Syu; fi; printf '\\n'; read -r -p 'Pulsa Enter para cerrar… '"

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

    // Escondida no es lo mismo que descartada. Descartar cierra el aviso y con
    // él este proceso: se acabó hasta el próximo arranque. Esconder lo recoge
    // hacia arriba y deja colgando una pestañita para volver a bajarlo cuando
    // interese, que es lo que hace falta cuando la tarjeta cae encima de algo
    // que se estaba mirando pero las actualizaciones siguen ahí.
    property bool collapsed: false

    // Lo que se ve: la tarjeta sólo cuando está desplegada, y nunca ninguna de
    // las dos antes de la animación de entrada o después de la de salida.
    readonly property bool cardVisible: root.shown && !root.collapsed
    readonly property bool tabVisible: root.shown && root.collapsed

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
        // Lo justo para que la tarjeta termine de recogerse antes de que el
        // proceso se vaya: si se cerrara antes, la salida se vería como un
        // corte.
        interval: Theme.animOut + 40
        onTriggered: Qt.quit()
    }

    // Se va sola, pero no mientras el ratón esté encima: con un botón dentro,
    // desaparecer justo cuando vas a pulsarlo sería lo peor que podría hacer.
    // Al apartar el ratón vuelve a contar desde cero, que es tiempo de sobra.
    //
    // Escondida a mano tampoco cuenta atrás: esconder algo es decir "ahora no",
    // no "olvídalo", así que la pestaña espera ahí arriba todo lo que haga
    // falta.
    Timer {
        running: !cardHover.hovered && !root.collapsed
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
                color: Theme.edgeTop
            }
            GradientStop {
                position: 1.0
                color: Theme.edgeBottom
            }
        }

        // Cae desde el borde de arriba: el origen de la escala es la parte
        // superior, así que la tarjeta se despliega hacia abajo en vez de
        // crecer desde su centro. Y se recoge por donde vino, encogiendo hacia
        // ese mismo borde, tanto al esconderla como al descartarla.
        transformOrigin: Item.Top
        scale: root.cardVisible ? 1 : 0.78
        opacity: root.cardVisible ? 1 : 0
        visible: opacity > 0

        // Un empujón corto hacia arriba encima del encogido, para que se lea
        // como meterse detrás de la barra y no como apagarse en el sitio.
        transform: Translate {
            y: root.cardVisible ? 0 : -14

            Behavior on y {
                NumberAnimation {
                    duration: root.cardVisible ? Theme.animIn : Theme.animOut
                    easing.type: root.cardVisible ? Easing.OutBack : Easing.InBack
                    easing.overshoot: root.cardVisible ? Theme.overshootIn : Theme.overshootOut
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.cardVisible ? Theme.animIn : Theme.animOut
                easing.type: root.cardVisible ? Easing.OutBack : Easing.InBack
                easing.overshoot: root.cardVisible ? 2.2 : Theme.overshootOut
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.cardVisible ? 160 : Theme.animOut - 60
                easing.type: root.cardVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, card.radius - 1)

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

        HoverHandler {
            id: cardHover
        }

        // Un clic en la tarjeta la quita de en medio sin esperar al plazo. Va
        // con z negativo, por detrás de todo lo demás, para que el botón y la
        // flecha de esconder —que están por delante— se queden con los suyos y
        // pulsarlos no cuente como descartar.
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: root.dismiss()
        }

        // La flecha de esconder, centrada en el aire que deja el relleno
        // superior. En reposo es apenas una marca: está para encontrarla
        // cuando se la busca, no para competir con la cifra que hay debajo.
        Text {
            id: collapseArrow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6

            text: "󰅃"
            color: collapseHover.hovered ? Theme.strong : Theme.faint
            font.family: Theme.font
            font.pixelSize: 16

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            // El glifo es estrecho y queda demasiado arriba para acertarle:
            // esto le da un área de clic cómoda sin agrandar el dibujo.
            HoverHandler {
                id: collapseHover
                margin: 10
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                margin: 10
                onTapped: root.collapsed = true
            }
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
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 54
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.total === 1 ? "actualización" : "actualizaciones"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }

            // El desglose sólo aparece cuando hay algo del AUR que separar:
            // con todo viniendo de los repos, la línea no diría nada nuevo.
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                visible: root.aur > 0
                text: root.repos + " repos  ·  " + root.aur + " AUR"
                color: Theme.muted
                font.family: Theme.font
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
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    Text {
                        text: "Actualizar ahora"
                        color: Theme.strong
                        font.family: Theme.font
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

    // Lo que queda cuando la tarjeta se esconde: una lengüeta colgando del
    // mismo borde, con la flecha al revés. Mide lo justo para verse y para
    // acertarle, y es el único trozo de la superficie que recibe clics
    // mientras está escondida.
    //
    // Se pinta con el mismo doble Rectangle que la tarjeta —el canto fuera, el
    // cristal dentro dejando 1px— porque es la misma lámina, sólo que casi
    // toda ella metida detrás de la barra.
    Rectangle {
        id: tab

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10

        width: 58
        height: 22
        radius: 11

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

        transformOrigin: Item.Top
        scale: root.tabVisible ? 1 : 0.6
        opacity: root.tabVisible ? 1 : 0
        visible: opacity > 0

        Behavior on scale {
            NumberAnimation {
                duration: root.tabVisible ? Theme.animIn : Theme.animOut
                easing.type: root.tabVisible ? Easing.OutBack : Easing.InBack
                easing.overshoot: root.tabVisible ? 2.2 : Theme.overshootOut
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.tabVisible ? 160 : Theme.animOut - 60
                easing.type: root.tabVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, tab.radius - 1)

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

        Text {
            anchors.centerIn: parent
            text: "󰅀"
            color: tabHover.hovered ? Theme.strong : Theme.muted
            font.family: Theme.font
            font.pixelSize: 15

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        HoverHandler {
            id: tabHover
            cursorShape: Qt.PointingHandCursor
        }

        // Volver a bajarla es sólo dejar de esconderla: la tarjeta sigue
        // montada detrás, con sus cuentas intactas.
        TapHandler {
            onTapped: root.collapsed = false
        }
    }
}
