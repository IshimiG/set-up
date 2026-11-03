import QtQuick

// Una lámina de cristal. Antes cada superficie (la isla, los bloques de la
// barra, las notificaciones, el lanzador, el recordatorio, el aviso de
// actualizaciones, el selector de tema y el cajón del homelab) copiaba a mano
// un Rectangle con el degradado del canto y otro dentro con el del cuerpo;
// ahora todas usan éste.
//
// Se usa como un Rectangle: width, height, radius, clip, scale, opacity,
// transform… se ponen en el propio Cristal, y lo que se declare dentro queda
// por encima del cuerpo (en QML los hermanos se pintan en orden). El tema sólo
// cambia el material: el tamaño y el radio los pone quien lo usa, igual en
// todos los temas.
//
// Dos maneras de pintarlo, según el tema:
//
// - Plano (default): la capa exterior es *solo* el canto, pintada entera con
//   el degradado edgeTop → edgeBottom, y el cuerpo (glassTop → glassBottom) se
//   dibuja encima dejando `borde` píxeles al aire: la única forma de tener un
//   borde con degradado con Rectangles, porque un Rectangle sólo admite un
//   border.color plano. Con un cuerpo negro al 0.64-0.76 el canto de debajo
//   apenas se nota; si el tema trae brillo especular o tinte, van encima.
//
// - Vidrio (Theme.vidrio, liquido): lo pinta todo un shader
//   (cristal.frag.qsb, al lado): el cuerpo blanco muy translúcido, el
//   resplandor fino de dentro del canto que da grosor, el canto blanco con su
//   degradado de alfa (brillante arriba a la izquierda, tenue abajo) y el
//   brillo especular. Así el canto no queda debajo de un cuerpo translúcido,
//   que es lo que lo volvía lechoso. Si el shader no carga (un Qt sin RHI, el
//   renderizador por software), sale el cuerpo con un filo plano, para que
//   nunca se quede sin lámina.
//
// El cristal sólo va en la capa de navegación y no se apila: lo que va dentro
// de una lámina usa velos sutiles (Qt.rgba(1,1,1,0.0x)), no otro Cristal.
Rectangle {
    id: cristal

    // Más opaco (glassDense) para lo que flota sobre contenido, sin desenfoque
    // detrás; ahí el especular, el tinte y el velo sobran.
    property bool denso: false
    // El grueso del canto.
    property real borde: Theme.bordeAnchura
    // El brillo de arriba; se puede quitar en una lámina muy baja.
    property bool brillo: true
    // De 0 a 1: cuánto del velo de lectura (Theme.readingVeil) lleva. Para
    // las láminas con texto que caen encima de las ventanas; una pastilla de
    // la barra, sobre el fondo de escritorio, no lo necesita. Se anima, así
    // que la isla lo puede subir al abrirse.
    property real lectura: 0

    Behavior on lectura {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool conVidrio: Theme.vidrio && Theme.rimStops.length === 5
    // Se puede usar el shader: hace falta el renderizador de la RHI (el de
    // siempre en Wayland; el de por software no tiene ShaderEffect) y que no
    // haya fallado al cargar. Si no, se pinta con el respaldo plano.
    // (El status no sirve para saber si está listo: con un .qsb se queda en
    // Uncompiled aunque pinte bien.)
    readonly property bool conShader: vidrio.item !== null && vidrio.item.status !== ShaderEffect.Error

    color: "transparent"
    gradient: cristal.conVidrio ? null : cantoPlano

    Gradient {
        id: cantoPlano

        GradientStop {
            position: 0.0
            color: Theme.edgeTop
        }
        GradientStop {
            position: 1.0
            color: Theme.edgeBottom
        }
    }

    function vec(c, a) {
        return Qt.vector4d(c.r, c.g, c.b, a === undefined ? c.a : a);
    }

    // --- Vidrio --------------------------------------------------------
    // Sólo se crea en un tema con vidrio: en default no hay ni shader ni nada
    // que cargar.
    Loader {
        id: vidrio

        anchors.fill: parent
        active: cristal.conVidrio && cristal.GraphicsInfo.shaderType === GraphicsInfo.RhiShader

        sourceComponent: ShaderEffect {
            fragmentShader: Qt.resolvedUrl("cristal.frag.qsb")

            readonly property size tam: Qt.size(width, height)
            readonly property real radio: cristal.radius
            readonly property real borde: cristal.borde
            // En una pastilla de 26 px el resplandor no puede ser el de una tarjeta.
            readonly property real grosor: Math.min(Theme.thickness, Math.min(width, height) * 0.14)
            readonly property real brillo: cristal.brillo && !cristal.denso ? 1 : 0
            readonly property real esquina: Theme.rimCorner
            readonly property real medio: Theme.rimMid
            readonly property real luz: Theme.rimLight
            readonly property real reflejo: Theme.rimReflect
            readonly property real sheen: Theme.sheen
            readonly property vector4d cuerpoArriba: cristal.vec(cristal.denso ? Theme.glassDense : Theme.glassTop)
            readonly property vector4d cuerpoAbajo: cristal.vec(cristal.denso ? Theme.glassDense : Theme.glassBottom)
            readonly property vector4d velo: cristal.vec(Theme.readingVeil, cristal.denso ? 0 : Theme.readingVeil.a * cristal.lectura)
            readonly property vector4d canto0: cristal.vec(Theme.rimStops[0])
            readonly property vector4d canto1: cristal.vec(Theme.rimStops[1])
            readonly property vector4d canto2: cristal.vec(Theme.rimStops[2])
            readonly property vector4d canto3: cristal.vec(Theme.rimStops[3])
            readonly property vector4d canto4: cristal.vec(Theme.rimStops[4])
        }
    }

    // --- Plano (y el respaldo del vidrio) --------------------------------
    Rectangle {
        id: cuerpo

        readonly property bool respaldo: cristal.conVidrio && !cristal.conShader

        anchors.fill: parent
        anchors.margins: cuerpo.respaldo ? 0 : cristal.borde
        radius: Math.max(0, cristal.radius - anchors.margins)
        visible: !cristal.conShader
        border.width: cuerpo.respaldo ? cristal.borde : 0
        border.color: Theme.edgeTop

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: cristal.denso ? Theme.glassDense : Theme.glassTop
            }
            GradientStop {
                position: 1.0
                color: cristal.denso ? Theme.glassDense : Theme.glassBottom
            }
        }

        // El velo de lectura (sólo en un tema que lo tenga).
        Rectangle {
            anchors.fill: parent
            radius: cuerpo.radius
            visible: !cristal.denso && Theme.readingVeil.a * cristal.lectura > 0
            color: Qt.rgba(Theme.readingVeil.r, Theme.readingVeil.g, Theme.readingVeil.b, Theme.readingVeil.a * cristal.lectura)
        }

        // El tinte: un velo de color encima del cuerpo, sin tocar su alfa.
        Rectangle {
            anchors.fill: parent
            radius: cuerpo.radius
            visible: !cristal.denso && Theme.tint.a > 0
            color: Theme.tint
        }

        // El brillo especular: de `specular` a transparente en el
        // `specularHeight` de arriba.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * Theme.specularHeight
            radius: cuerpo.radius
            visible: cristal.brillo && !cristal.denso && Theme.specularHeight > 0

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.specular
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(Theme.specular.r, Theme.specular.g, Theme.specular.b, 0)
                }
            }
        }
    }
}
