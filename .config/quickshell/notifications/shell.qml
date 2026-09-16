import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Daemon de notificaciones del escritorio.
//
// Hasta ahora no había ninguno: notify-send fallaba con ServiceUnknown y
// ninguna aplicación podía avisar de nada. Este proceso toma
// org.freedesktop.Notifications en el bus de sesión, así que cualquier
// programa —el navegador, Signal, el calendario, un script con notify-send—
// entra por aquí sin que haya que configurar nada en él.
//
// Va aparte del lanzador y del menú de sesión porque no es un menú que se abre
// y se cierra: vive toda la sesión, arrancado desde ~/.config/hypr/hyprland.lua.
ShellRoot {
    id: root

    // Historial de lo que ya se ha ido de la pantalla, del más reciente al más
    // antiguo. Se guarda en memoria a propósito: es para mirar qué me he
    // perdido hace un rato, no un archivo permanente.
    property var history: []
    readonly property int historyLimit: 100

    // Mientras está puesto, nada salta a la pantalla; todo va directo al
    // historial. Lo alterna ~/.config/hypr/scripts/notify-ctl.sh, que es lo que
    // usan el atajo de teclado y el botón de la barra.
    property bool silent: false

    // El centro de notificaciones sólo existe mientras está abierto: es una
    // superficie a pantalla completa que se queda con el teclado, y no tiene
    // sentido tenerla ahí parada el resto del tiempo.
    property bool centerOpen: false

    function pushHistory(notif) {
        const entry = {
            appName: notif.appName,
            appIcon: notif.appIcon,
            image: notif.image,
            summary: notif.summary,
            body: notif.body,
            urgency: notif.urgency,
            time: Date.now()
        };
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
    }

    NotificationServer {
        id: server

        // Sin esto, al recargar la configuración se perderían las
        // notificaciones que estén en pantalla.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: notif => {
            // Sin esto la notificación se descarta nada más llegar: el
            // servidor sólo conserva las que alguien dice querer.
            notif.tracked = true;

            notif.closed.connect(() => root.pushHistory(notif));

            if (root.silent)
                notif.dismiss();
        }
    }

    // Órdenes desde fuera: el atajo de teclado y el botón de la barra escriben
    // una palabra en este socket en vez de hablar por D-Bus, que para tres
    // órdenes sería mucho aparato.
    IpcHandler {
        target: "notifications"

        function toggleSilent(): string {
            root.silent = !root.silent;
            return root.silent ? "on" : "off";
        }

        function silentState(): string {
            return root.silent ? "on" : "off";
        }

        function toggleCenter(): string {
            root.centerOpen = !root.centerOpen;
            return root.centerOpen ? "open" : "closed";
        }

        function dismissAll(): string {
            const live = server.trackedNotifications.values;
            for (let i = live.length - 1; i >= 0; i--)
                live[i].dismiss();
            return "ok";
        }

        function clearHistory(): string {
            root.history = [];
            return "ok";
        }
    }

    // La pila de notificaciones, colgada de la esquina superior derecha por
    // debajo de la barra. La ventana crece y encoge con su contenido, así que
    // fuera de las tarjetas el escritorio sigue recibiendo sus clics.
    PanelWindow {
        id: panel

        WlrLayershell.namespace: "notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        // Un aviso no roba el teclado: lo que estés escribiendo sigue yendo
        // donde estabas escribiéndolo.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

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

        anchors.top: true
        anchors.right: true
        margins.top: 38
        margins.right: 14

        color: "transparent"
        visible: stack.children.length > 0

        implicitWidth: Theme.cardWidth
        implicitHeight: Math.max(1, stack.implicitHeight)

        ColumnLayout {
            id: stack

            anchors.fill: parent
            spacing: Theme.gap

            Repeater {
                model: server.trackedNotifications

                delegate: NotificationCard {
                    id: entry

                    required property var modelData

                    notif: modelData
                    Layout.fillWidth: true

                    onDismissed: modelData.dismiss()
                    onInvoked: identifier => {
                        const actions = modelData.actions;
                        for (let i = 0; i < actions.length; i++) {
                            if (actions[i].identifier === identifier) {
                                actions[i].invoke();
                                return;
                            }
                        }
                    }

                    // Entra deslizándose desde el borde derecho, que es de
                    // donde viene.
                    opacity: 0
                    transform: Translate {
                        id: slide
                        x: 30
                    }

                    Component.onCompleted: enter.start()

                    ParallelAnimation {
                        id: enter

                        NumberAnimation {
                            target: entry
                            property: "opacity"
                            to: 1
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: slide
                            property: "x"
                            to: 0
                            duration: 320
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.3
                        }
                    }
                }
            }
        }
    }

    NotificationCenter {
        shell: root
        visible: root.centerOpen
    }
}
