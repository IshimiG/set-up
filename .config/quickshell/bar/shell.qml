import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import "shared"

// La isla central de la barra, y todo lo que sale de ella.
//
// Sustituye a tres cosas que antes vivían por separado: el bloque central de
// waybar (reloj, campana y botón de sesión), la configuración "powermenu" y la
// configuración "notifications". Están juntas a propósito, porque lo que se
// quería no se puede hacer con piezas separadas: que el bloque central crezca y
// se convierta en el panel, interpolando geometría, en vez de abrir una ventana
// encima. Eso exige que la barra y el panel sean el mismo Item, y por tanto el
// mismo proceso.
//
// waybar sigue viva de momento, reducida a los escritorios a la izquierda y la
// telemetría con la bandeja a la derecha. Son dos capas de layer-shell
// distintas y conviven sin enterarse la una de la otra.
ShellRoot {
    id: root

    // --- Qué hay abierto -------------------------------------------------
    // Un único panel que cambia de contenido, no un panel por botón: pulsar la
    // campana con el calendario abierto no cierra y vuelve a abrir, reajusta el
    // que ya está. Por eso el estado es global al proceso y no de cada isla.
    //
    // "" es cerrado. El resto es qué se está mostrando.
    property string mode: ""

    // En qué monitor. Cada isla se abre sólo si le toca, así pulsar la campana
    // en una pantalla no despliega también la otra.
    property string modeScreen: ""

    readonly property bool open: root.mode !== ""

    // La barra escondida a mano, con SUPER+SHIFT+V. Es el mismo atajo que apaga
    // y enciende waybar, porque las dos mitades de la barra tienen que irse
    // juntas: esconder sólo una dejaría los escritorios y la telemetría
    // flotando sin nada en medio.
    property bool hidden: false

    function toggleHidden() {
        root.hidden = !root.hidden;
        if (root.hidden)
            root.close();
        return root.hidden;
    }

    function toggle(screenName, which) {
        if (root.mode === which && root.modeScreen === screenName) {
            root.close();
            return;
        }
        root.modeScreen = screenName;
        root.mode = which;
        if (which === "notifications")
            root.unread = false;
    }

    function close() {
        root.mode = "";
    }

    // Abrir desde fuera (atajo de teclado, script) va al monitor con el foco,
    // que es el mismo criterio que usaban el menú de sesión y el centro.
    function toggleFocused(which) {
        const focused = Hyprland.focusedMonitor;
        root.toggle(focused ? focused.name : "", which);
    }

    // --- La hora ----------------------------------------------------------
    // Un solo reloj para las dos islas. Es un temporizador alineado al minuto
    // dentro de este proceso: ni un fork, ni un script que se despierte cada
    // minuto para mirar qué hora es.
    readonly property date now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- Notificaciones ---------------------------------------------------

    // Mientras está puesto, nada salta a la pantalla; todo va directo al
    // historial.
    property bool silent: false

    // Hay algo que no se ha mirado. Se apaga al abrir el panel, no al llegar el
    // aviso a la pantalla: lo que cuenta es si lo has visto tú.
    property bool unread: false

    // La campana da un respingo cuando entra algo. Va como señal y no como
    // propiedad porque es un evento, no un estado: dos avisos seguidos tienen
    // que animar dos veces.
    signal arrived

    // El historial, del más reciente al más antiguo.
    //
    // Cada entrada lleva los campos que se pintan y, si la notificación sigue
    // viva en este proceso, una referencia a ella en "notif". Esa referencia es
    // lo que permite invocar sus acciones y descartarla de una en una aunque ya
    // se haya ido de la pantalla: quien la mantiene viva es el RetainableLock
    // de más abajo.
    //
    // Las entradas que se leen del disco al arrancar no tienen "notif" —una
    // notificación no se puede resucitar en otro proceso—, así que se pintan
    // igual pero sin acciones.
    property var history: []
    readonly property int historyLimit: 100

    function pushHistory(notif) {
        const entry = {
            appName: notif.appName,
            appIcon: notif.appIcon,
            summary: notif.summary,
            body: notif.body,
            urgency: notif.urgency,
            time: Date.now(),
            notif: notif
        };
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
        root.unread = true;
        saveTimer.restart();
    }

    // Ojo con el orden: primero se cierra la notificación y sólo después sale del
    // array. Al salir del array se destruye su RetainableLock, y sin candado el
    // servidor tira el objeto; hacerlo al revés dejaría el dismiss() tocando
    // memoria ya liberada.
    function forgetEntry(index) {
        const next = root.history.slice();
        const gone = next.splice(index, 1)[0];
        if (gone && gone.notif)
            gone.notif.dismiss();
        root.history = next;
        saveTimer.restart();
    }

    function clearHistory() {
        const all = root.history;
        for (let i = 0; i < all.length; i++) {
            if (all[i].notif)
                all[i].notif.dismiss();
        }
        root.history = [];
        saveTimer.restart();
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
            // Sin esto la notificación se descarta nada más llegar: el servidor
            // sólo conserva las que alguien dice querer.
            notif.tracked = true;

            // Al historial en cuanto llega, no al cerrarse. Antes se apuntaba en
            // el "closed" y eso dejaba fuera del historial lo que estaba en
            // pantalla en ese momento; además con el silencio puesto el aviso se
            // descarta al instante y el orden se volvía impredecible.
            root.pushHistory(notif);
            root.arrived();

            if (root.silent)
                notif.dismiss();
        }
    }

    // Un candado por entrada viva del historial. Mientras existe, la
    // notificación sobrevive a su propio dismiss() y sus acciones siguen
    // siendo invocables; cuando la entrada sale del array, el candado se
    // destruye con ella y el servidor la tira.
    Instantiator {
        model: root.history
        delegate: RetainableLock {
            required property var modelData
            object: modelData.notif ?? null
            locked: true
        }
    }

    // --- Historial en disco -----------------------------------------------
    // Sólo para que un reinicio del daemon no borre lo de la última hora. Se
    // guarda una copia de lo que se pinta, sin las acciones, porque una acción
    // vive en el proceso de la aplicación que la mandó y no se puede resucitar.
    FileView {
        id: store

        path: Quickshell.env("HOME") + "/.local/share/notificaciones/historial.json"
        // Escritura atómica: si el equipo se apaga a mitad, el fichero anterior
        // sigue entero en vez de quedarse a medias.
        atomicWrites: true
        // No hace falta vigilarlo: este proceso es el único que lo escribe.
        watchChanges: false

        onLoaded: {
            try {
                const saved = JSON.parse(store.text());
                if (Array.isArray(saved))
                    root.history = saved.slice(0, root.historyLimit);
            } catch (e) {
                // Un fichero corrupto no puede impedir que arranque la barra.
                console.warn("historial ilegible, se empieza de cero: " + e);
            }
        }

        onLoadFailed: err => {
            // La primera vez no existe todavía, y eso no es un problema.
            if (err !== FileViewError.FileNotFound)
                console.warn("no se pudo leer el historial: " + err);
        }
    }

    // Las notificaciones llegan a ráfagas, así que no se escribe una vez por
    // aviso: se espera a que la ráfaga pare.
    Timer {
        id: saveTimer
        interval: 2000
        onTriggered: {
            const plain = root.history.map(e => ({
                        appName: e.appName,
                        appIcon: e.appIcon,
                        summary: e.summary,
                        body: e.body,
                        urgency: e.urgency,
                        time: e.time
                    }));
            store.setText(JSON.stringify(plain));
        }
    }

    // --- Órdenes desde fuera ----------------------------------------------
    // Las mandan el atajo de teclado y, mientras siga existiendo,
    // ~/.config/hypr/scripts/notify-ctl.sh.
    IpcHandler {
        target: "bar"

        function toggleSilent(): string {
            root.silent = !root.silent;
            return root.silent ? "on" : "off";
        }

        function silentState(): string {
            return root.silent ? "on" : "off";
        }

        // Qué hay abierto y en qué monitor. Sirve para scripts y, sobre todo,
        // para poder mirar desde fuera si la isla sigue desplegada: la respuesta
        // de un toggle sólo dice qué pasó en ese instante.
        function state(): string {
            return (root.mode === "" ? "cerrada" : root.mode) + " " + root.modeScreen;
        }

        // Esconder y sacar la barra. Devuelve en cuál de los dos estados se ha
        // quedado, para que quien llame pueda dejar a waybar igual: la isla es
        // la que decide y waybar la sigue, así no se pueden desparejar.
        function toggleBar(): string {
            return root.toggleHidden() ? "oculta" : "visible";
        }

        function trayCount(): string {
            return SystemTray.items.values.length + "";
        }

        function barState(): string {
            return root.hidden ? "oculta" : "visible";
        }

        function toggleCenter(): string {
            root.toggleFocused("notifications");
            return root.mode === "notifications" ? "open" : "closed";
        }

        function toggleCalendar(): string {
            root.toggleFocused("calendar");
            return root.mode === "calendar" ? "open" : "closed";
        }

        function togglePower(): string {
            root.toggleFocused("power");
            return root.mode === "power" ? "open" : "closed";
        }

        function toggleWifi(): string {
            root.toggleFocused("wifi");
            return root.mode === "wifi" ? "open" : "closed";
        }

        function dismissAll(): string {
            const live = server.trackedNotifications.values;
            for (let i = live.length - 1; i >= 0; i--)
                live[i].dismiss();
            return "ok";
        }

        function clearHistory(): string {
            root.clearHistory();
            return "ok";
        }
    }

    // --- Las superficies ---------------------------------------------------

    // Las lecturas de la barra: cpu, memoria, temperatura, gpu, ratón y el
    // loopback del micrófono. Una sola vez para los dos monitores.
    Telemetry {
        id: telemetria

        shell: root
    }

    // La wifi: el icono de la derecha y su desplegable. También una sola vez.
    Wifi {
        id: estadoWifi

        shell: root
        mirando: root.mode === "wifi"
    }

    // Las tres piezas de la barra, una terna por monitor y todas desde este
    // proceso. Esto es lo que quita de raíz la carrera que tenía waybar con los
    // módulos duplicados: no hay dos lectores de nada porque no hay dos
    // procesos.
    //
    // Son tres superficies de layer-shell y no una porque cada una se ancla a un
    // sitio distinto y la del centro tiene que poder crecer; unirlas obligaría a
    // una única superficie a pantalla completa con una máscara de tres huecos,
    // que es más difícil de seguir y no gana nada.
    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            // La franja que reserva el hueco de la barra. Va aparte porque
            // ninguna de las otras tres puede hacerlo: están ancladas a los
            // cuatro lados y layer-shell entonces ignora la zona exclusiva.
            Strut {
                screen: modelData
                shell: root
            }

            WorkspacesBlock {
                screen: modelData
                shell: root
            }

            Island {
                screen: modelData
                shell: root
            }

            TelemetryBlock {
                screen: modelData
                shell: root
                tel: telemetria
                wifi: estadoWifi
            }
        }
    }

    // La pila de avisos que salta a la pantalla, en la esquina superior
    // derecha. Va aparte de la isla: un aviso aparece solo, sin que nadie pulse
    // nada, y no tiene por qué desplegar la barra.
    NotificationPopups {
        shell: root
        server: server
    }
}
