import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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

    readonly property bool wanted: !block.shell.hidden

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

    mask: Region {
        x: block.derecha ? Math.round((block.width + block.anchoIsla) / 2) : 0
        y: 0
        width: Math.round((block.width - block.anchoIsla) / 2)
        height: block.marginTop + block.pillH + 2
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

        width: Math.max(1, fila.implicitWidth + block.pillPad * 2)
        height: block.pillH
        radius: block.radio
        clip: true

        opacity: block.reveal
        transform: Translate {
            y: -(1 - block.reveal) * (block.marginTop + block.pillH + 6)
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

        RowLayout {
            id: fila

            anchors.centerIn: parent
            height: block.pillH
            spacing: 14
        }
    }

    // El globo, colgado del mismo lado que el bloque. Reemplaza al tooltip de
    // GTK, que además llevaba meses ilegible: la paleta muerta que heredaba
    // waybar le daba fondo blanco con texto blanco.
    Rectangle {
        id: globo

        readonly property bool puesto: block.pista !== "" && block.reveal > 0.99

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
