import QtQuick

// Una lámina de cristal: el canto con degradado, el cuerpo esmerilado y, si el
// tema lo trae, el brillo especular y el tinte. Antes cada superficie (la
// isla, los bloques de la barra, las notificaciones, el lanzador, el
// recordatorio y el aviso de actualizaciones) copiaba a mano un Rectangle con
// el degradado del canto y otro dentro con el del cuerpo; ahora todas usan
// éste.
//
// La capa exterior es *solo* el canto: se pinta entera con el degradado
// edgeTop → edgeBottom y el cuerpo se dibuja encima dejando `borde` píxeles al
// aire. Es la única forma de conseguir un borde con degradado en QML, porque
// un Rectangle solo admite un border.color plano.
//
// Se usa como un Rectangle: width, height, radius, clip, scale, opacity,
// transform… se ponen en el propio Cristal, y lo que se declare dentro queda
// por encima del cuerpo (en QML los hermanos se pintan en orden).
//
// En default pinta exactamente lo de antes: borde de 1 px, glassTop →
// glassBottom, y el especular (altura 0) y el tinte (transparente) no se
// dibujan. En liquido suma el brillo del tercio de arriba y el tinte frío.
//
// El cristal sólo va en la capa de navegación y no se apila: lo que va dentro
// de una lámina usa velos sutiles (Qt.rgba(1,1,1,0.0x)), no otro Cristal.
Rectangle {
    id: cristal

    // Más opaco (glassDense) para lo que flota sobre contenido, sin desenfoque
    // detrás; ahí el especular y el tinte sobran.
    property bool denso: false
    // El grueso del canto.
    property real borde: Theme.bordeAnchura
    // El brillo del tercio de arriba; se puede quitar en una lámina muy baja.
    property bool brillo: true

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
        id: cuerpo

        anchors.fill: parent
        anchors.margins: cristal.borde
        radius: Math.max(0, cristal.radius - cristal.borde)

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
