import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import "shared"

// La telemetría y los periféricos, a la derecha de la barra.
//
// Los datos no se leen aquí: llegan ya leídos desde Telemetry.qml, que los saca
// una sola vez para los dos monitores. Este fichero sólo pinta y recoge clics.
//
// El volumen y lo que está sonando sí salen directos de sus servicios nativos,
// porque Pipewire y Mpris avisan por su cuenta cuando algo cambia y no hay nada
// que muestrear: no son telemetría, son estado.
SideBlock {
    id: root

    // "shell" lo declara SideBlock; volver a declararlo aquí lo ensombrecería.
    required property var tel

    derecha: true

    // El sink por defecto hay que rastrearlo explícitamente o Pipewire no
    // mantiene al día su volumen ni su mute.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null

    // El reproductor que manda: el que esté sonando, y si no hay ninguno
    // sonando, el primero que exista —así lo que está en pausa sigue a la vista
    // en lugar de desaparecer de la barra—.
    readonly property var reproductor: {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying)
                return ps[i];
        }
        return ps.length > 0 ? ps[0] : null;
    }

    // Naranja cuando aprieta, rojo cuando ya duele. Son los mismos umbrales que
    // tenía waybar en sus "states".
    function tintePorUso(v) {
        if (v >= 90)
            return Theme.danger;
        if (v >= 70)
            return Theme.warn;
        return Theme.strong;
    }

    // btop, desde cualquiera de los módulos de telemetría. Va en su propia
    // clase para que hyprland.lua lo saque del mosaico (flotante, centrado y
    // en todos los escritorios), y por launch-or-focus para que un segundo
    // clic enfoque el que ya hay en vez de apilar otro encima.
    //
    // Lo que se busca son 80x24 celdas dentro, el mínimo con el que btop se
    // pinta entero; con menos sólo enseña "Terminal size too small". Pero
    // Ghostty calcula la ventana sin contar el relleno de config.ghostty, así
    // que pedirle 80x24 deja 75x22. Con 85x26 sobra para el relleno y quedan
    // las 80x24 justas.
    function abrirBtop() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/launch-or-focus", "^ghostty\\.btop$", "ghostty", "--class=ghostty.btop", "--title=btop", "--window-width=85", "--window-height=26", "-e", "btop"]);
    }

    // Un módulo de la barra: un glifo, opcionalmente una cifra al lado, y un
    // globo al pasar por encima. Va como componente en línea porque sólo se usa
    // aquí y sacarlo a un fichero propio obligaría a leer dos para entender uno.
    component Modulo: Item {
        id: mod

        property string glifo: ""
        property string valor: ""
        property string pista: ""
        property color tinte: Theme.strong
        // Para lo que está apagado o silenciado: sigue ahí y sigue siendo
        // clicable, pero deja de pesar.
        property real atenuado: 1

        signal pulsado
        signal pulsadoDerecho
        signal pulsadoMedio
        signal rueda(int delta)

        visible: mod.glifo !== "" || mod.valor !== ""
        implicitWidth: visible ? linea.implicitWidth : 0
        implicitHeight: parent ? parent.height : 26
        opacity: mod.atenuado

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        RowLayout {
            id: linea

            anchors.centerIn: parent
            spacing: 6

            Text {
                visible: mod.glifo !== ""
                text: mod.glifo
                color: mod.tinte
                font.family: Theme.font
                font.pixelSize: 12

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            Text {
                visible: mod.valor !== ""
                text: mod.valor
                color: mod.tinte
                font.family: Theme.font
                font.pixelSize: 12

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }
        }

        HoverHandler {
            id: encima
            cursorShape: Qt.PointingHandCursor
        }

        // El globo lo dibuja el bloque, no el módulo: así sólo hay uno y se
        // coloca respecto a la pastilla entera en vez de pelearse por el sitio
        // con los vecinos.
        Connections {
            target: encima
            function onHoveredChanged() {
                if (encima.hovered) {
                    root.pistaDe = mod;
                    root.pista = mod.pista;
                } else if (root.pista === mod.pista) {
                    root.pista = "";
                }
            }
        }

        // Y si el dato cambia mientras el ratón sigue encima, el globo se
        // actualiza en vez de quedarse con la cifra de hace tres segundos.
        onPistaChanged: if (encima.hovered)
            root.pista = mod.pista

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: mod.pulsado()
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: mod.pulsadoDerecho()
        }

        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: mod.pulsadoMedio()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => mod.rueda(event.angleDelta.y)
        }
    }

    // --- Lo que está sonando ------------------------------------------------
    Modulo {
        readonly property string titulo: root.reproductor ? (root.reproductor.trackTitle || "") : ""
        readonly property string artista: root.reproductor ? (root.reproductor.trackArtist || "") : ""

        glifo: titulo === "" ? "" : (root.reproductor.isPlaying ? "󰎈" : "󰏤")
        valor: {
            if (titulo === "")
                return "";
            const t = artista !== "" ? artista + " · " + titulo : titulo;
            // El mismo recorte que tenía waybar en max-length: un disco con
            // título largo no puede empujar la telemetría fuera de la pantalla.
            return t.length > 45 ? t.substring(0, 44) + "…" : t;
        }
        // Verde mientras suena, porque en esta barra el verde significa "algo
        // está activo ahora mismo". En pausa sigue ahí pero deja de reclamar.
        tinte: root.reproductor && root.reproductor.isPlaying ? Theme.ok : Theme.strong
        atenuado: root.reproductor && root.reproductor.isPlaying ? 1 : 0.5
        pista: {
            if (titulo === "")
                return "";
            let p = titulo;
            if (artista !== "")
                p += "\n" + artista;
            const album = root.reproductor.trackAlbum || "";
            if (album !== "")
                p += "\n" + album;
            return p + "\n" + root.reproductor.identity;
        }

        onPulsado: if (root.reproductor)
            root.reproductor.togglePlaying()
        onPulsadoDerecho: if (root.reproductor && root.reproductor.canGoNext)
            root.reproductor.next()
        onPulsadoMedio: if (root.reproductor && root.reproductor.canGoPrevious)
            root.reproductor.previous()
        onRueda: delta => {
            if (root.reproductor && root.reproductor.canSeek)
                root.reproductor.seek(delta > 0 ? 10 : -10);
        }
    }

    // --- Loopback del micrófono ---------------------------------------------
    Modulo {
        // Sin glifo el módulo desaparece, que es lo que toca en una máquina
        // donde el loopback nunca se ha configurado: no hay nada que encender.
        glifo: !root.tel.loopHay ? "" : (root.tel.loopActivo ? "󰍬" : "󰍭")
        tinte: root.tel.loopActivo ? Theme.ok : Theme.strong
        // No se esconde cuando está apagado: sin glifo no habría dónde hacer
        // clic para encenderlo.
        atenuado: root.tel.loopActivo ? 1 : 0.45
        pista: root.tel.loopAviso

        onPulsado: root.tel.alternarLoopback()
        onPulsadoDerecho: Quickshell.execDetached(["pavucontrol"])
        onRueda: delta => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/loopback.sh", delta > 0 ? "up" : "down"])
    }

    // --- Volumen -------------------------------------------------------------
    Modulo {
        readonly property int pct: root.audio ? Math.round(root.audio.volume * 100) : 0
        readonly property bool mudo: root.audio ? root.audio.muted : false

        glifo: {
            if (mudo)
                return "󰝟";
            if (pct <= 33)
                return "󰕿";
            if (pct <= 66)
                return "󰖀";
            return "󰕾";
        }
        valor: pct + "%"
        atenuado: mudo ? 0.45 : 1
        pista: root.sink ? root.sink.description + "\n" + pct + "%" + (mudo ? " · silenciado" : "") : ""

        onPulsado: Quickshell.execDetached(["pavucontrol"])
        onPulsadoDerecho: if (root.audio)
            root.audio.muted = !root.audio.muted
        onRueda: delta => {
            if (!root.audio)
                return;
            // El mismo paso del 5 % que tenía waybar, y el mismo tope: pasar de
            // 1.0 es amplificar por software y suena mal.
            const v = root.audio.volume + (delta > 0 ? 0.05 : -0.05);
            root.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    // --- CPU y su temperatura ------------------------------------------------
    // Van pegadas porque se leen como un solo dato.
    Modulo {
        glifo: "󰍛"
        valor: root.tel.cpu + "%"
        tinte: root.tintePorUso(root.tel.cpu)
        pista: "CPU " + root.tel.cpu + "%"

        onPulsado: root.abrirBtop()
    }

    Modulo {
        visible: root.tel.hwmonListo
        glifo: ""
        valor: root.tel.grados + "°"
        // El umbral de crítico es el mismo que tenía waybar: 85.
        tinte: root.tel.grados >= 85 ? Theme.danger : Theme.strong
        pista: "CPU " + root.tel.sensor + " · " + root.tel.grados + "°C"

        onPulsado: root.abrirBtop()
    }

    // --- Memoria -------------------------------------------------------------
    Modulo {
        glifo: "󰘚"
        valor: root.tel.memPct + "%"
        // Los umbrales de la memoria eran algo más altos que los del resto.
        tinte: root.tel.memPct >= 92 ? Theme.danger : (root.tel.memPct >= 80 ? Theme.warn : Theme.strong)
        pista: "RAM " + root.tel.memUsada.toFixed(1) + " / " + root.tel.memTotal.toFixed(1) + " GiB" + "\nSwap " + root.tel.swapUsada.toFixed(1) + " GiB"

        onPulsado: root.abrirBtop()
    }

    // --- GPU -----------------------------------------------------------------
    Modulo {
        glifo: root.tel.gpuHay ? "󰢮" : ""
        valor: root.tel.gpuHay ? root.tel.gpuPct + "% " + root.tel.gpuGrados + "°" : ""
        tinte: root.tintePorUso(root.tel.gpuPct)
        pista: {
            if (!root.tel.gpuHay)
                return "";
            let p = root.tel.gpuNombre;
            p += "\nUso " + root.tel.gpuPct + "% · " + root.tel.gpuGrados + "°C";
            p += "\nVRAM " + root.tel.gpuVram + " / " + root.tel.gpuVramTotal + " MiB";
            if (root.tel.gpuVatios > 0)
                p += "\nConsumo " + root.tel.gpuVatios.toFixed(0) + " W";
            return p;
        }

        onPulsado: root.abrirBtop()
    }

    // --- Batería del ratón ---------------------------------------------------
    // Sigue saliendo de mouse-battery.py porque UPower no ve el Razer. El texto
    // vacío esconde el módulo, que es lo que pasa con el ratón apagado: dormido
    // no contesta a la petición HID.
    Modulo {
        glifo: root.tel.ratonTexto === "" ? "" : "󰍽"
        valor: root.tel.ratonTexto
        tinte: {
            if (root.tel.ratonClase === "critical")
                return Theme.danger;
            if (root.tel.ratonClase === "warning")
                return Theme.warn;
            if (root.tel.ratonClase === "charging")
                return Theme.ok;
            return Theme.strong;
        }
        pista: root.tel.ratonTexto === "" ? "" : "Razer Viper V3 Pro SE · " + root.tel.ratonTexto
    }

    // --- Batería del portátil -------------------------------------------------
    // Portátil: la torre no tiene batería. Sale de UPower y no de Telemetry.qml
    // por lo mismo que el volumen: UPower avisa por su cuenta de cada cambio, así
    // que no hay nada que muestrear. Sin batería (o mientras UPower no ha
    // contestado) el texto queda vacío y el módulo se esconde solo.
    Modulo {
        id: bateria

        readonly property var disp: UPower.displayDevice
        readonly property bool hay: bateria.disp !== null && bateria.disp.ready && bateria.disp.isLaptopBattery
        // percentage va de 0 a 1.
        readonly property int pct: bateria.hay ? Math.round(bateria.disp.percentage * 100) : 0
        readonly property bool enchufada: bateria.hay && bateria.disp.state !== UPowerDeviceState.Discharging && bateria.disp.state !== UPowerDeviceState.Empty

        // Los mismos glifos y umbrales que tenía la batería en waybar.
        readonly property var glifosDescarga: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        readonly property var glifosCarga: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

        function duracion(segundos) {
            const min = Math.round(segundos / 60);
            if (min < 60)
                return min + " min";
            return Math.floor(min / 60) + " h " + (min % 60) + " min";
        }

        glifo: {
            if (!bateria.hay)
                return "";
            const i = Math.max(0, Math.min(9, Math.floor(bateria.pct / 10)));
            return bateria.enchufada ? bateria.glifosCarga[i] : bateria.glifosDescarga[i];
        }
        valor: bateria.hay ? bateria.pct + "%" : ""
        tinte: {
            if (bateria.enchufada)
                return Theme.ok;
            if (bateria.pct <= 10)
                return Theme.danger;
            if (bateria.pct <= 20)
                return Theme.warn;
            return Theme.strong;
        }
        pista: {
            if (!bateria.hay)
                return "";
            let p = "Batería " + bateria.pct + "%";
            if (bateria.disp.state === UPowerDeviceState.FullyCharged)
                p += "\nCargada";
            else if (bateria.enchufada)
                p += bateria.disp.timeToFull > 0 ? "\nLlena en " + bateria.duracion(bateria.disp.timeToFull) : "\nCargando";
            else if (bateria.disp.timeToEmpty > 0)
                p += "\nQuedan " + bateria.duracion(bateria.disp.timeToEmpty);
            if (Math.abs(bateria.disp.changeRate) > 0.5)
                p += " · " + Math.abs(bateria.disp.changeRate).toFixed(0) + " W";
            return p;
        }
    }

    // --- La bandeja del sistema ---------------------------------------------
    // Cierra la barra pegada al borde derecho, como hacía en waybar.
    //
    // Se despliega al pasar el ratón por el glifo, igual que antes: en reposo
    // son cuatro o cinco iconos que casi nunca se pulsan y no tienen por qué
    // competir con la telemetría. Antes el expansor era un objetivo invisible;
    // aquí al menos el glifo dice que hay algo detrás.
    //
    // OJO: el menú de cada icono lo abre la propia aplicación a través de
    // SystemTrayItem.display(), que lo pinta con el estilo de Qt y no con el
    // cristal del escritorio. Es lo que hay de momento: pintarlo nosotros
    // significa implementar DBusMenu entero —submenús anidados, checkboxes y
    // radios, iconos por tema, y aplicaciones Electron y Steam que lo
    // implementan de forma creativa—, y eso es un trabajo aparte.
    Item {
        id: bandeja

        readonly property bool abierta: expandir.hovered || iconos.containsMouse
        readonly property int anchoIconos: Math.max(0, SystemTray.items.values.length * 26)

        implicitWidth: glifoExpandir.implicitWidth + (bandeja.abierta ? bandeja.anchoIconos + 8 : 0)
        implicitHeight: parent ? parent.height : 26

        // El despliegue lleva el mismo rebote que todo lo demás de la barra.
        Behavior on implicitWidth {
            NumberAnimation {
                duration: bandeja.abierta ? 380 : 240
                easing.type: bandeja.abierta ? Easing.OutBack : Easing.InOutQuint
                easing.overshoot: 1.4
            }
        }

        Text {
            id: glifoExpandir

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰇘"
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 11
            opacity: bandeja.abierta ? 1 : 0.55

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }

            HoverHandler {
                id: expandir
                cursorShape: Qt.PointingHandCursor
            }
        }

        MouseArea {
            id: iconos

            anchors.left: glifoExpandir.right
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: bandeja.abierta ? bandeja.anchoIconos : 0
            hoverEnabled: true
            // Los clics los atiende cada icono; esto sólo está para que el
            // desplegado no se cierre en cuanto el ratón sale del glifo.
            acceptedButtons: Qt.NoButton
            clip: true

            Row {
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: icono

                        required property var modelData

                        width: 26
                        height: 26

                        opacity: bandeja.abierta ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: bandeja.abierta ? 220 : 120
                            }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 14
                            source: icono.modelData.icon
                        }

                        HoverHandler {
                            id: sobreIcono
                            cursorShape: Qt.PointingHandCursor
                        }

                        Connections {
                            target: sobreIcono
                            function onHoveredChanged() {
                                const p = icono.modelData.tooltipTitle || icono.modelData.title || icono.modelData.id;
                                if (sobreIcono.hovered) {
                                    root.pistaDe = icono;
                                    root.pista = p;
                                } else if (root.pista === p) {
                                    root.pista = "";
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                // Hay aplicaciones que sólo ofrecen menú y no
                                // tienen nada que "activar"; en ésas, el clic
                                // izquierdo abre el menú en vez de no hacer nada.
                                if (icono.modelData.onlyMenu)
                                    icono.abrirMenu();
                                else
                                    icono.modelData.activate();
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: icono.abrirMenu()
                        }

                        TapHandler {
                            acceptedButtons: Qt.MiddleButton
                            onTapped: icono.modelData.secondaryActivate()
                        }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => icono.modelData.scroll(event.angleDelta.x, event.angleDelta.y)
                        }

                        function abrirMenu() {
                            if (!icono.modelData.hasMenu)
                                return;
                            // El menú cuelga de debajo del icono. Las
                            // coordenadas van respecto a la ventana, así que hay
                            // que traducir las del icono.
                            const p = icono.mapToItem(null, icono.width / 2, icono.height);
                            icono.modelData.display(root, Math.round(p.x), Math.round(p.y));
                        }
                    }
                }
            }
        }
    }
}
