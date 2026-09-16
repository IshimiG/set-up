pragma Singleton

import QtQuick
import Quickshell

// Paleta y medidas compartidas por todo el sistema de notificaciones.
//
// Los valores salen de waybar (~/Projects/set-up/.config/waybar/style.css), que
// es la referencia del escritorio y no se toca: cuerpo negro translúcido, texto
// blanco, y color sólo donde la barra lo usa —verde "algo está activo", naranja
// aviso, rojo crítico—. Son los mismos números que usan el lanzador, el menú de
// sesión y el aviso de actualizaciones; si cambias uno, cambia todos.
Singleton {
    // Cuerpo de cristal. El alfa no puede bajar de 0.5: los layer_rule de
    // ~/.config/hypr/hyprland.lua usan ignore_alpha = 0.5 y por debajo de ese
    // umbral Hyprland deja de desenfocar la superficie.
    readonly property color glassTop: Qt.rgba(0, 0, 0, 0.76)
    readonly property color glassBottom: Qt.rgba(0, 0, 0, 0.64)

    // Canto: blanco puro, sólo varía el alfa.
    readonly property color edgeTop: Qt.rgba(1, 1, 1, 0.30)
    readonly property color edgeBottom: Qt.rgba(1, 1, 1, 0.08)

    readonly property color text: Qt.rgba(1, 1, 1, 0.78)
    readonly property color strong: "#ffffff"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.55)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.35)
    readonly property color rule: Qt.rgba(1, 1, 1, 0.12)

    // Acentos de la barra, reservados para lo que de verdad los merece.
    readonly property color ok: "#6dc89e"
    readonly property color warn: "#e59625"
    readonly property color danger: "#e90b25"

    readonly property string font: "JetBrainsMono Nerd Font"

    readonly property int cardWidth: 380
    readonly property int radius: 16
    readonly property int pad: 14
    readonly property int gap: 10

    // Cuánto se queda en pantalla una notificación que no dice cuánto durar.
    // Las críticas no se van solas: si algo es crítico, se cierra a mano.
    function timeoutFor(urgency) {
        if (urgency === 2)
            return 0;
        if (urgency === 0)
            return 4000;
        return 7000;
    }
}
