import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared"

// La superficie del cajón: una columna pegada al borde derecho, alta como la
// pantalla y tan ancha como el cajón abierto más su aire.
//
// Como en la isla, la superficie no cambia nunca de tamaño y lo que se mueve es
// el Item de dentro (Cajon.qml): si la superficie creciera con el cajón, el
// compositor la redimensionaría en cada fotograma del arrastre. Y como en la
// isla, lo que evita que una columna de 500 px se coma los clics de las
// ventanas de debajo es la máscara de entrada.
PanelWindow {
    id: borde

    required property var shell

    WlrLayershell.namespace: "homelab"
    // Top, como la isla: por encima de las ventanas, que es lo que se pidió
    // («delante»), y por debajo de una ventana a pantalla completa, así que con
    // un vídeo a pantalla completa el asa no estorba.
    WlrLayershell.layer: WlrLayer.Top
    // El teclado sólo con el cajón abierto (Escape, y en la fase 3 los atajos de
    // las tareas). Cerrado, no le quita el foco a nadie.
    WlrLayershell.keyboardFocus: borde.shell.abierto ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Tapa lo que hay debajo; no aparta las ventanas (decisión E4 del plan).
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: cajon.anchoSuperficie
    color: "transparent"

    // --- La máscara de entrada ---------------------------------------------
    // Cambia por estado y no por fotograma, por lo mismo que en Island.qml: una
    // región no sigue a una geometría que se anima. Las tres salen de medidas
    // fijas del cajón:
    //
    //   - escondido, la franja de 3 px del centro del borde: lo único que tiene
    //     que notar es que el ratón llega;
    //   - con el asa fuera, la zona del asa, para poder agarrarla;
    //   - abierto, o mientras se mueve, el cajón entero con su asa.
    //
    // Arrastrando no hace falta más: lo que se pulsa dentro de la superficie
    // sigue llegando aquí hasta que se suelta el botón, aunque el ratón salga de
    // la máscara (Wayland le da a la superficie el puntero mientras dura la
    // pulsación).
    mask: cajon.enJuego ? regionCajon : (cajon.asoma ? regionAsa : regionFranja)

    Region {
        id: regionFranja

        x: borde.width - cajon.anchoFranja
        y: cajon.bandaY
        width: cajon.anchoFranja
        height: cajon.bandaAlto
    }

    Region {
        id: regionAsa

        x: borde.width - cajon.anchoZonaAsa
        y: cajon.bandaY
        width: cajon.anchoZonaAsa
        height: cajon.bandaAlto
    }

    Region {
        id: regionCajon

        x: cajon.xZonaAbierta
        y: cajon.arriba
        width: borde.width - cajon.xZonaAbierta
        height: borde.height - cajon.arriba - cajon.abajo
    }

    // Un clic en otra ventana cierra el cajón, salvo que esté fijado. Lo avisa
    // Hyprland, que es quien se entera de que el foco se ha ido a otra parte;
    // la máscara, que deja pasar los clics de fuera, es lo que hace que se
    // entere.
    //
    // Sólo cierra si sigue abierto y sin fijar: el grab también se suelta al
    // fijarlo, y eso no tiene que cerrar nada.
    HyprlandFocusGrab {
        active: borde.shell.abierto && !borde.shell.fijado
        windows: [borde]
        onCleared: if (borde.shell.abierto && !borde.shell.fijado)
            borde.shell.abierto = false
    }

    Item {
        anchors.fill: parent
        focus: borde.shell.abierto

        // Escape cierra siempre, también fijado: fijar es para que no se vaya
        // solo, no para que no se pueda cerrar.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                borde.shell.abierto = false;
            }
        }

        Cajon {
            id: cajon

            anchors.fill: parent
            shell: borde.shell
        }
    }
}
