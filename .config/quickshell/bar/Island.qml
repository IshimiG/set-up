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
    // Los paneles que salen de la isla. El modo es global y también abre los
    // desplegables de los bloques laterales (la wifi, en el portátil): con uno
    // de ésos abierto, la isla se queda en pastilla.
    readonly property var modos: ["calendar", "notifications", "power"]
    readonly property bool open: island.modos.indexOf(island.shell.mode) >= 0 && island.shell.modeScreen === island.screenName

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

    // --- Los tiempos y las curvas -----------------------------------------
    // Salen del vocabulario que ya usa el escritorio en hyprland.lua, para que
    // la isla no invente un ritmo propio:
    //
    //   - Lo que entra rebota una vez y se asienta. Allí es el muelle
    //     "subtleBounce" (rigidez 200, amortiguación 19, razón de
    //     amortiguamiento ~0.67), que se pasa del punto de reposo alrededor de
    //     un 5 % y vuelve en el primer vaivén. Aquí se imita con OutBack, que
    //     hace exactamente eso mismo y además tiene duración fija, que es lo que
    //     permite que ancho, alto y radio vayan acompasados. Un muelle de
    //     verdad (SpringAnimation) tiene duración emergente y las tres
    //     dimensiones acabarían llegando en momentos distintos.
    //   - Lo que sale NO rebota. Allí es el bezier "easeInOutQuint"; aquí,
    //     InOutQuint. Un rebote al esconder algo se lee como un fallo.
    //
    // Las duraciones son las de las capas de Hyprland traducidas a
    // milisegundos: su "speed" va en decisegundos, así que layersIn 4.2 son 420
    // y layersOut 3 son 300. Así la isla y waybar entran y salen a la vez
    // cuando se esconde la barra con SUPER+SHIFT+V.
    readonly property int durOpen: 420
    readonly property int durClose: 220
    // Reajustar de un contenido a otro va más rápido que abrir desde cero: la
    // isla ya está ahí, sólo cambia de tamaño.
    readonly property int durMorph: 300
    readonly property int durHide: 300

    // Cuánto se pasa del punto de reposo. Medido en la máquina: con 1.4, un panel
    // de 388 px llega a 407 y vuelve, o sea un 4.9 % de más. Es justo el carácter
    // del muelle "subtleBounce" de hyprland.lua, que se pasa alrededor de un 5 %.
    readonly property real overshoot: 1.4

    // --- Por qué la curva es una propiedad y no una expresión --------------
    // Estas tres no se escriben directamente en los Behavior como
    // `island.open ? A : B`. Se probó y estaba mal: al cerrar, la isla seguía
    // usando la curva de abrir y se pasaba del reposo *hacia dentro*, con lo que
    // la pastilla se encogía hasta 1 px y volvía a salir. Medido en el log:
    // 309, 241, ... 4, 1, 1, 3, 8, ... 26.
    //
    // El motivo es que un Behavior lee las propiedades de su animación en el
    // instante en que arranca, y arranca cuando se escribe el valor nuevo. Si la
    // curva es otro binding que depende de lo mismo, no hay garantía de que se
    // haya recalculado antes: QML no ordena las actualizaciones de bindings
    // hermanos.
    //
    // La solución es fijarlas donde se calcula el destino, dentro del propio
    // binding de la geometría. Un efecto lateral en un binding no es bonito,
    // pero aquí es exactamente lo que hace falta: la escritura que dispara el
    // Behavior ocurre *después* de que la expresión termine, así que cuando el
    // Behavior mira, ya están puestas.
    property int curva: Easing.OutBack
    property int duracion: island.durOpen
    property int curvaRevelado: Easing.OutBack
    property int duracionRevelado: island.durOpen

    // Devuelve el destino y, de paso, deja puestas la curva y la duración que le
    // corresponden. Lo llaman los bindings de ancho y alto del cristal.
    function conCurva(abierta, valor) {
        island.curva = abierta ? Easing.OutBack : Easing.InOutQuint;
        island.duracion = abierta ? (island.content !== "" ? island.durMorph : island.durOpen) : island.durClose;
        return valor;
    }

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

    // --- Esconder y sacar (SUPER+SHIFT+V) ----------------------------------
    // Un panel abierto la saca igualmente: si con la barra escondida se pide el
    // historial con su atajo, lo que se quiere es verlo, no que no pase nada. Al
    // cerrarlo vuelve a esconderse sola.
    readonly property bool wanted: !island.shell.hidden || island.open

    // El estado de la animación, de 0 (escondida) a 1 (fuera). No se puede
    // atar "visible" directamente a "wanted": poner visible a false destruye la
    // superficie de layer-shell al instante y no habría nada que animar. Así que
    // la superficie se mantiene viva mientras queda algo que enseñar, y sólo
    // desaparece cuando la animación ha terminado de verdad.
    property real reveal: {
        // Mismo truco que en la geometría: la curva se fija aquí, donde se
        // calcula el valor, no en un binding hermano dentro del Behavior.
        island.curvaRevelado = island.wanted ? Easing.OutBack : Easing.InOutQuint;
        island.duracionRevelado = island.wanted ? island.durOpen : island.durHide;
        return island.wanted ? 1 : 0;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: island.duracionRevelado
            easing.type: island.curvaRevelado
            easing.overshoot: island.overshoot
        }
    }

    visible: island.reveal > 0.001

    // La máscara de entrada es justo el cristal: todo lo que caiga fuera le llega
    // al escritorio como si esta superficie no existiera.
    //
    // Va atada a la geometría propiedad por propiedad y NO con `item: glassEdge`,
    // aunque eso último sea más corto. Con `item` la máscara se queda con el
    // tamaño que tenía el cristal al crearse —el de la pastilla, 26 px de alto—
    // y no vuelve a mirarlo: la isla se desplegaba bien pero el ratón no llegaba
    // al panel, ni para pulsar ni para resaltar la fila bajo el cursor. Atada
    // así, cada fotograma de la animación reevalúa el binding.
    // La máscara de entrada es justo el cristal: todo lo que caiga fuera le llega
    // al escritorio como si esta superficie no existiera.
    //
    // Va atada a la geometría propiedad por propiedad y NO con `item: glassEdge`,
    // que sería más corto: con `item` la máscara se queda con el tamaño que
    // tenía el cristal al crearse —el de la pastilla, 26 px de alto— y no vuelve
    // a mirarlo, de modo que la isla se desplegaba bien pero el ratón no llegaba
    // al panel. Atada así, cada fotograma de la animación reevalúa el binding.
    // --- La máscara de entrada ---------------------------------------------
    // La superficie ocupa la pantalla entera, así que sin máscara se comería
    // todos los clics del escritorio. Pero la máscara no puede seguir a la
    // geometría del cristal mientras se anima: se probaron las dos formas
    // —`item: glassEdge` y atar x/y/width/height— y con la isla desplegada el
    // ratón no llegaba al panel, ni para pulsar ni para resaltar la fila de
    // debajo. La región se queda con el tamaño que tenía al crearse.
    //
    // Así que la máscara cambia por ESTADO y no por fotograma, que es una
    // asignación normal de propiedad y no depende de que una región reaccione:
    //
    //   - Desplegada, un rectángulo del tamaño que el panel va a tener cuando
    //     termine de abrirse, centrado como él. No sigue la animación: sale de
    //     las medidas del contenido, que no cambian mientras el cristal crece,
    //     así que no depende de que la región reaccione fotograma a fotograma.
    //     Durante los 420 ms de apertura la zona es algo mayor que el cristal,
    //     y eso no se nota.
    //   - Plegada, un rectángulo fijo y generoso centrado sobre la franja de la
    //     barra. Fijo a propósito: la pastilla cambia de ancho sola —"mié 17" y
    //     "jueves 1" no miden lo mismo— y una máscara que tuviera que seguir eso
    //     tendría el mismo problema. El sobrante cae dentro de los 29 px que la
    //     barra ya reserva, donde no hay ventanas a las que robarles nada, y se
    //     queda corto para no pisar los bloques laterales.
    //
    // Que desplegada NO sea la pantalla entera es lo que hace que cerrar
    // pulsando fuera funcione de verdad. Antes lo era, copiando al lanzador, y
    // el resultado es que la isla se quedaba con todos los clics del
    // escritorio: el de fuera no llegaba a ninguna otra ventana, y como quien
    // avisa de que hay que cerrar es el focus grab de Hyprland —que sólo se
    // entera cuando el foco se va a otra superficie—, el panel se quedaba
    // abierto. Sólo se cerraba pulsando en la franja de arriba, por donde el
    // clic sí salía de la máscara. Recortada al panel, cualquier clic fuera va
    // a donde tenga que ir y el grab cierra.
    mask: island.open ? regionAbierta : regionPastilla

    Region {
        id: regionAbierta

        // El ancho del cristal abierto, sin la curva de la animación de por
        // medio: el mayor entre la pastilla y el panel que se esté mostrando.
        readonly property int ancho: Math.max(pill.implicitWidth + island.pillPad * 2, island.panelW)

        x: Math.round((island.width - regionAbierta.ancho) / 2)
        y: 0
        width: regionAbierta.ancho
        // Desde el borde de arriba —el margen de la barra entra dentro, para no
        // dejar una rendija muerta entre la pastilla y el canto de la
        // pantalla— hasta el bajo del panel, con un par de píxeles de propina.
        height: island.marginTop + island.pillH + island.panelH + 2
    }

    Region {
        id: regionPastilla

        readonly property int ancho: 460

        x: Math.round((island.width - regionPastilla.ancho) / 2)
        y: 0
        width: regionPastilla.ancho
        height: island.marginTop + island.pillH + 2
    }

    // Clic en cualquier otro sitio: cierra. No hace falta un MouseArea a
    // pantalla completa —que además haría inútil la máscara—: Hyprland avisa de
    // que el foco se ha ido a otra parte.
    //
    // Sólo si sigue abierta: si el grab se suelta porque se ha abierto el
    // desplegable de un bloque lateral, cerrar aquí lo cerraría también.
    HyprlandFocusGrab {
        active: island.open
        windows: [island]
        onCleared: if (island.open)
            island.shell.close()
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
        width: island.conCurva(island.open, island.open ? Math.max(pill.implicitWidth + island.pillPad * 2, island.panelW) : pill.implicitWidth + island.pillPad * 2)
        height: island.conCurva(island.open, island.open ? island.pillH + island.panelH : island.pillH)
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

        // Esconderse y salir: se va hacia arriba, por detrás del borde de la
        // pantalla, igual que hace waybar con su animación de capa "slide". No
        // se anima el ancho ni el alto aquí, sólo la posición y la opacidad, de
        // modo que esconder una isla desplegada no la obliga además a encogerse.
        opacity: island.reveal
        transform: Translate {
            y: -(1 - island.reveal) * (island.marginTop + glassEdge.height + 6)
        }

        // El despliegue. Un solo Behavior por dimensión, con la duración y la
        // curva dependiendo de qué está pasando: abrir desde cero rebota una vez
        // y se asienta, reajustar de un contenido a otro hace lo mismo un poco
        // más rápido, y cerrar baja liso, sin rebote.
        Behavior on width {
            NumberAnimation {
                duration: island.duracion
                easing.type: island.curva
                easing.overshoot: island.overshoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: island.duracion
                easing.type: island.curva
                easing.overshoot: island.overshoot
            }
        }
        // El radio no rebota aunque lo hagan el ancho y el alto: un borde que se
        // pasa de redondo y vuelve no se lee como elasticidad, se lee como que
        // la esquina parpadea.
        Behavior on radius {
            NumberAnimation {
                duration: island.duracion
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

            // El contenido entra empujado desde arriba, como si lo soltara la
            // propia pastilla, y llega con el mismo rebote que el cristal. Va en
            // el contenedor y no en cada panel porque los tres se mueven igual y
            // sólo uno está visible a la vez.
            transform: Translate {
                y: island.open ? 0 : -10

                Behavior on y {
                    NumberAnimation {
                        duration: island.duracion
                        easing.type: island.curva
                        easing.overshoot: island.overshoot
                    }
                }
            }

            CalendarPanel {
                id: calendar
                anchors.fill: parent
                shell: island.shell
                opacity: island.content === "calendar" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
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
                        duration: 200
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
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
