import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// Uno de los dos bloques laterales de la barra: los escritorios a la izquierda,
// la telemetría a la derecha.
//
// La superficie es fija y a pantalla completa, con máscara de entrada, igual que
// la isla. No es por capricho: los módulos tienen que poder enseñar su globo de
// información por debajo de la barra, y una superficie ajustada a la pastilla lo
// recortaría.
//
// La máscara cubre sólo la pastilla, no el globo. Un globo no necesita recibir
// clics —de hecho es mejor que no los reciba, o taparía lo que hay debajo—, y
// una máscara sólo decide qué entra, no qué se pinta.
//
// Un bloque puede llevar además un desplegable (en el portátil, el de la
// derecha lleva el de la wifi). Se abre como la isla: la pastilla y el panel
// son el mismo cristal, que crece hacia abajo y hacia dentro de la pantalla con
// el mismo rebote, y los módulos de la pastilla no se mueven de su sitio
// mientras tanto.
PanelWindow {
    id: block

    required property var shell
    // A qué borde se pega. La barra sólo tiene dos lados, así que un booleano
    // dice más que un enum.
    property bool derecha: false

    // Los hijos van directos a la fila.
    default property alias contenido: fila.data

    // Lo que enseña el globo. Lo pone y lo quita cada módulo al pasar el ratón
    // por encima; vacío significa que no hay globo.
    property string pista: ""

    // The module that owns the current tooltip, so the tooltip can hang
    // centred under it instead of pinned to the pill's outer edge.
    property Item pistaDe: null

    // --- El desplegable ----------------------------------------------------
    // El panel, como componente, y si está abierto. Lo decide quien usa el
    // bloque a partir del modo de shell.qml, que es global: abrir esto cierra
    // lo que hubiera abierto en la isla, y al revés.
    property Component desplegable: null
    property bool abierto: false

    readonly property Item panel: cargador.item
    readonly property int panelW: block.panel ? block.panel.implicitWidth : 0
    readonly property int panelH: block.panel ? block.panel.implicitHeight : 0
    // Lo más que puede llegar a medir, para la máscara. Si el panel no lo
    // dice, su altura de ahora.
    readonly property int panelMax: block.panel ? (block.panel.alturaMax || block.panelH) : 0

    readonly property int radioPanel: 18
    readonly property int anchoPastilla: Math.max(1, fila.implicitWidth + block.pillPad * 2)

    // Las curvas del despliegue, fijadas dentro del binding de la geometría y
    // no en uno hermano: es el mismo problema que en Island.qml, donde un
    // Behavior leía la curva de abrir al cerrar y la isla rebotaba hacia
    // dentro.
    //
    // Y aquí hay uno más: el ancho de la pastilla cambia solo a menudo —el
    // título de lo que suena, la bandeja al desplegarse, que ya anima su
    // propio ancho— y eso no se puede animar dos veces. Así que el Behavior
    // sólo está encendido mientras el panel está abierto o terminando de
    // cerrarse.
    property int curvaPanel: Easing.OutBack
    property int duracionPanel: 380
    property bool animarPanel: false

    function conCurva(valor) {
        if (block.abierto) {
            block.animarPanel = true;
            block.curvaPanel = Easing.OutBack;
            block.duracionPanel = 380;
        } else {
            block.curvaPanel = Easing.InOutQuint;
            block.duracionPanel = 220;
            if (block.animarPanel)
                recogido.restart();
        }
        return valor;
    }

    Timer {
        id: recogido
        interval: 240
        onTriggered: block.animarPanel = false
    }

    readonly property int pillH: 26
    readonly property int pillPad: 12
    readonly property int marginTop: 3
    // El mismo margen lateral que tenía waybar (margin-left/right 12).
    readonly property int marginSide: 12
    readonly property int radio: 10

    // Las mismas curvas y tiempos que la isla, que a su vez salen de las
    // animaciones de capa de hyprland.lua.
    readonly property int durMostrar: 420
    readonly property int durEsconder: 300
    readonly property real overshoot: 1.4

    // Un desplegable abierto saca la barra aunque esté escondida, igual que
    // la isla: si se pide, es para verlo.
    readonly property bool wanted: !block.shell.hidden || block.abierto

    property int curva: Easing.OutBack
    property int duracion: block.durMostrar

    property real reveal: {
        // La curva se fija aquí, donde se calcula el valor, y no en un binding
        // dentro del Behavior: un Behavior lee las propiedades de su animación
        // en el instante en que arranca, y QML no garantiza que un binding
        // hermano se haya recalculado ya. Es el mismo motivo que en Island.qml,
        // donde eso hacía que la isla rebotara al cerrarse.
        block.curva = block.wanted ? Easing.OutBack : Easing.InOutQuint;
        block.duracion = block.wanted ? block.durMostrar : block.durEsconder;
        return block.wanted ? 1 : 0;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: block.duracion
            easing.type: block.curva
            easing.overshoot: block.overshoot
        }
    }

    // No se puede atar "visible" a "wanted" directamente: poner visible a false
    // destruye la superficie de layer-shell al instante y no quedaría nada que
    // animar.
    visible: block.reveal > 0.001

    WlrLayershell.namespace: "barra"
    WlrLayershell.layer: WlrLayer.Top
    // El teclado sólo hace falta con el desplegable abierto: hay contraseñas
    // que escribir. Cerrado, la barra no le quita el foco a nadie.
    WlrLayershell.keyboardFocus: block.abierto ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // No reserva hueco: de eso se encarga Strut.qml, que es la única superficie
    // de la barra anclada a un solo borde y por tanto la única a la que
    // layer-shell le respeta una zona exclusiva.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // La máscara de entrada, por el mismo motivo y con la misma forma que en la
    // isla: una región no vuelve a mirar la geometría después de crearse, así
    // que no puede seguir a la pastilla. Y aquí la pastilla cambia de ancho a
    // menudo —cada vez que cambia el título de lo que suena, y al desplegarse la
    // bandeja—.
    //
    // La solución es repartir la franja de la barra en tres zonas fijas: el
    // tercio izquierdo para un bloque, el derecho para el otro, y los 460 px del
    // centro para la isla. Ninguna se solapa y ninguna necesita medir nada.
    //
    // El sobrante —la parte de la franja donde no hay pastilla— se queda sin
    // pasar clics al escritorio, pero da igual: son los 29 px que la barra ya
    // reserva, donde no hay ventanas.
    readonly property int anchoIsla: 460

    // Con el desplegable abierto la máscara pasa a ser el rectángulo más
    // grande que puede llegar a ocupar el panel, y no el que ocupa ahora: la
    // región no sigue bien a una geometría que cambia (Island.qml cuenta la
    // historia), y un panel puede cambiar de alto en cualquier momento (el de
    // la wifi, cada vez que aparece una red). Lo que sobra por debajo del
    // cristal lo recoge el MouseArea que hay bajo el cristal, que cierra el
    // panel como lo cerraría un clic en cualquier otro sitio.
    mask: block.abierto ? regionPanel : regionFranja

    Region {
        id: regionFranja

        x: block.derecha ? Math.round((block.width + block.anchoIsla) / 2) : 0
        y: 0
        width: Math.round((block.width - block.anchoIsla) / 2)
        height: block.marginTop + block.pillH + 2
    }

    Region {
        id: regionPanel

        readonly property int ancho: Math.max(block.anchoPastilla, block.panelW) + block.marginSide

        x: block.derecha ? block.width - regionPanel.ancho : 0
        y: 0
        width: regionPanel.ancho
        height: block.marginTop + block.pillH + block.panelMax + 2
    }

    // Un clic fuera de la barra cierra el desplegable. Lo avisa Hyprland, que
    // es quien se entera de que el foco se ha ido a otra parte.
    HyprlandFocusGrab {
        active: block.abierto
        windows: [block]
        onCleared: if (block.abierto)
            block.shell.close()
    }

    // Lo que se escribe va primero al panel, que sabe si le sirve (Escape
    // recoge su formulario antes que nada). Lo que no quiere, Escape incluido,
    // cierra.
    Item {
        id: teclas

        anchors.fill: parent
        focus: block.abierto

        Keys.onPressed: event => {
            const panel = block.panel;
            if (panel && panel.handleKey && panel.handleKey(event)) {
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                block.shell.close();
            }
        }

        // El sobrante de la máscara: dentro de ella pero fuera del cristal.
        // Lo que cae sobre el cristal no se toca —se rechaza en el press y
        // sigue su camino—, para no quitarle el clic a los módulos de la
        // pastilla ni al propio panel.
        MouseArea {
            anchors.fill: parent
            enabled: block.abierto
            onPressed: mouse => {
                mouse.accepted = !canto.contains(mapToItem(canto, mouse.x, mouse.y));
            }
            onClicked: block.shell.close()
        }

        // La capa exterior es sólo el canto, con el cuerpo de cristal encima dejando
        // 1px al aire: es la única forma de tener un borde con degradado en QML.
        Rectangle {
            id: canto

            anchors.top: parent.top
            anchors.topMargin: block.marginTop
            anchors.left: block.derecha ? undefined : parent.left
            anchors.right: block.derecha ? parent.right : undefined
            anchors.leftMargin: block.marginSide
            anchors.rightMargin: block.marginSide

            width: block.conCurva(block.abierto ? Math.max(block.anchoPastilla, block.panelW) : block.anchoPastilla)
            height: block.conCurva(block.abierto ? block.pillH + block.panelH : block.pillH)
            radius: block.conCurva(block.abierto ? block.radioPanel : block.radio)
            clip: true

            Behavior on width {
                enabled: block.animarPanel
                NumberAnimation {
                    duration: block.duracionPanel
                    easing.type: block.curvaPanel
                    easing.overshoot: block.overshoot
                }
            }
            Behavior on height {
                enabled: block.animarPanel
                NumberAnimation {
                    duration: block.duracionPanel
                    easing.type: block.curvaPanel
                    easing.overshoot: block.overshoot
                }
            }
            // El radio no rebota: una esquina que se pasa de redonda y vuelve se
            // lee como un parpadeo.
            Behavior on radius {
                enabled: block.animarPanel
                NumberAnimation {
                    duration: block.duracionPanel
                    easing.type: Easing.OutCubic
                }
            }

            opacity: block.reveal
            transform: Translate {
                y: -(1 - block.reveal) * (block.marginTop + canto.height + 6)
            }

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

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, canto.radius - 1)

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

            // Pegada arriba y al borde de la pantalla, no centrada: cuando el
            // cristal crece hacia dentro, los módulos se quedan donde estaban.
            RowLayout {
                id: fila

                anchors.top: parent.top
                anchors.left: block.derecha ? undefined : parent.left
                anchors.right: block.derecha ? parent.right : undefined
                anchors.leftMargin: block.pillPad
                anchors.rightMargin: block.pillPad
                height: block.pillH
                spacing: 14
            }

            // El panel, debajo de la pastilla y recortado por el cristal. Entra
            // empujado desde arriba, como si lo soltara la propia pastilla.
            Item {
                id: zonaPanel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: fila.bottom
                anchors.bottom: parent.bottom
                clip: true
                visible: block.desplegable !== null

                transform: Translate {
                    y: block.abierto ? 0 : -10

                    Behavior on y {
                        NumberAnimation {
                            duration: block.duracionPanel
                            easing.type: block.curvaPanel
                            easing.overshoot: block.overshoot
                        }
                    }
                }

                Loader {
                    id: cargador

                    // El ancho es el de destino, no el del cristal mientras
                    // anima: si siguiera al cristal, el contenido se
                    // recolocaría en cada fotograma del rebote.
                    anchors.top: parent.top
                    anchors.left: block.derecha ? undefined : parent.left
                    anchors.right: block.derecha ? parent.right : undefined
                    width: block.panelW > 0 ? Math.max(block.panelW, block.anchoPastilla) : 0
                    height: block.panelH
                    sourceComponent: block.desplegable

                    opacity: block.abierto ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        // El globo, colgado del mismo lado que el bloque. Reemplaza al tooltip de
        // GTK, que además llevaba meses ilegible: la paleta muerta que heredaba
        // waybar le daba fondo blanco con texto blanco.
        Rectangle {
            id: globo

            readonly property bool puesto: block.pista !== "" && block.reveal > 0.99 && !block.abierto

            anchors.top: canto.bottom
            anchors.topMargin: 8

            // Centred under the module that asked for it, then clamped so it never
            // runs off the screen edge. The pill's geometry is read explicitly so
            // the binding re-runs when the pill grows or shrinks under it (a track
            // title changing, the tray unfolding); mapToItem alone is not reactive.
            x: {
                const de = block.pistaDe;
                const pillX = canto.x, pillW = canto.width;
                if (!de)
                    return block.derecha ? pillX + pillW - globo.width : pillX;
                const centro = de.mapToItem(globo.parent, de.width / 2, 0).x;
                const minX = block.marginSide;
                const maxX = block.width - block.marginSide - globo.width;
                return Math.round(Math.max(minX, Math.min(maxX, centro - globo.width / 2)));
            }

            // Slides between neighbouring modules while it is showing; when it
            // fades in from nothing it simply appears in place.
            Behavior on x {
                enabled: globo.opacity > 0.5
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            width: textoPista.implicitWidth + 20
            height: textoPista.implicitHeight + 14
            radius: 10

            color: Theme.glassTop
            border.width: 1
            border.color: Theme.rule

            opacity: globo.puesto ? 1 : 0
            visible: opacity > 0.01
            transform: Translate {
                y: globo.puesto ? 0 : -6
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: textoPista

                anchors.centerIn: parent
                text: block.pista
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 11
                lineHeight: 1.25
            }
        }
    }
}
