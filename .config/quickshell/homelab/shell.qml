import QtQuick
import Quickshell
import Quickshell.Io
import "shared"

// El panel del homelab, dentro del escritorio.
//
// Es otro cliente de la API del panel del NUC (panel.lab.ishimi.es), como su
// web, pero pintado con las piezas del escritorio: el mismo cristal que la isla
// y el mismo rebote al entrar. El plan entero y el porqué de cada decisión están
// en el vault, en «30 Áreas/Servidor/26-panel-escritorio.md».
//
// Se saca arrastrándolo desde el centro del borde derecho: al acercar el ratón
// asoma un asa, y el cajón sigue al ratón mientras se tira de ella. También se
// abre y se cierra con SUPER+H (hyprland.lua), que llama al IPC de abajo.
//
// Va en su propio proceso y no dentro de la barra: la barra lleva el demonio de
// notificaciones, y un fallo o una recarga de esto no debe llevárselo con él.
//
// Fase 1: todavía sin conexión con el NUC. Lo que se ve dentro son datos de
// prueba (Contenido.qml).
ShellRoot {
    id: root

    // Lo que se quiere, no lo que se ve: el cajón anima hasta aquí. Lo cambian
    // el IPC, el arrastre del asa, Escape y el clic fuera.
    property bool abierto: false

    // Fijado, el cajón no se cierra al hacer clic en otra ventana: se queda
    // delante mientras se trabaja detrás.
    property bool fijado: false

    function estado(): string {
        if (!root.abierto)
            return "cerrado";
        return root.fijado ? "fijado" : "abierto";
    }

    // Sólo el monitor de más a la derecha tiene asa. El borde derecho de los
    // demás da a otro monitor, y el ratón pasaría de largo en vez de pararse.
    // Sale de la posición de las pantallas, así vale tal cual para la torre
    // (DP-1 a la derecha de HDMI-A-1) y para el portátil con el 27" a la
    // izquierda, sin escribir nada en equipo.lua; y se recalcula solo al
    // enchufar o quitar un monitor.
    readonly property var pantalla: {
        const lista = Quickshell.screens;
        let mejor = null;
        for (let i = 0; i < lista.length; i++) {
            const s = lista[i];
            if (!mejor || s.x + s.width > mejor.x + mejor.width)
                mejor = s;
        }
        return mejor;
    }

    // SUPER+H llama a toggle. Si el proceso no estaba vivo, hyprland.lua lo
    // arranca con HOMELAB_ABRIR=1 para que esa misma pulsación ya lo abra,
    // igual que el lanzador.
    IpcHandler {
        target: "homelab"

        function toggle(): string {
            root.abierto = !root.abierto;
            return root.estado();
        }

        function abrir(): string {
            root.abierto = true;
            return root.estado();
        }

        function cerrar(): string {
            root.abierto = false;
            return root.estado();
        }

        function fijar(): string {
            root.fijado = !root.fijado;
            return root.estado();
        }

        // Para scripts y para mirar desde fuera cómo se ha quedado.
        function estado(): string {
            return root.estado();
        }
    }

    Component.onCompleted: if (Quickshell.env("HOMELAB_ABRIR") === "1")
        root.abierto = true

    // Una superficie, en la pantalla que toque. Si cambia la de la derecha, la
    // lista cambia de objeto y Variants quita la vieja y crea la nueva.
    Variants {
        model: root.pantalla ? [root.pantalla] : []

        Borde {
            required property var modelData

            screen: modelData
            shell: root
        }
    }
}
