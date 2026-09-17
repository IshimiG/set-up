pragma Singleton

import QtQuick
import Quickshell

// Paleta y medidas del escritorio. Única fuente de verdad.
//
// Antes esto estaba copiado a mano en seis sitios: el CSS de waybar y las
// propiedades `cAlgo` de cada configuración de Quickshell —el lanzador, el menú
// de sesión, el aviso de actualizaciones, el recordatorio rápido y las
// notificaciones—. Cambiar un color significaba acordarse de los seis, y ya
// habían empezado a divergir: el lanzador tenía un `cAccent` que los demás no,
// y el aviso de actualizaciones se había quedado sin `cRule`. Ahora todos
// importan esto.
//
// Sólo queda un duplicado fuera de aquí: waybar/style.css, porque es GTK y no
// puede leer QML. Ese se muere con waybar cuando la bandeja del sistema pase a
// Quickshell; hasta entonces, lo que se cambie aquí hay que replicarlo allí, y
// el CSS lleva un comentario que apunta a este fichero.
//
// El enlace es un symlink "shared" dentro de cada directorio de configuración,
// y tiene que apuntar a ../shared y no al repo: si apunta fuera de la raíz de
// configuración, el vigilante de ficheros de Quickshell no sigue el symlink,
// avisa de "unresolvable import" y se pierde la recarga en caliente al tocar
// este fichero.
Singleton {
    // --- Cristal ---------------------------------------------------------
    // El cuerpo es negro translúcido con un degradado vertical: algo más denso
    // arriba, donde la lámina recoge la luz.
    //
    // El alfa no puede bajar de 0.5. Los layer_rule de
    // ~/.config/hypr/hyprland.lua usan ignore_alpha = 0.5, y por debajo de ese
    // umbral Hyprland deja de desenfocar la superficie: el cristal se queda
    // liso y se pierde el frosted.
    readonly property color glassTop: Qt.rgba(0, 0, 0, 0.76)
    readonly property color glassBottom: Qt.rgba(0, 0, 0, 0.64)

    // Canto: blanco puro, igual que el borde de ventana de Hyprland. Sólo
    // varía el alfa, y va muy contenido porque un filo brillante sobre negro se
    // lee como un subrayado.
    readonly property color edgeTop: Qt.rgba(1, 1, 1, 0.30)
    readonly property color edgeBottom: Qt.rgba(1, 1, 1, 0.08)

    // --- Texto -----------------------------------------------------------
    readonly property color text: Qt.rgba(1, 1, 1, 0.78)
    readonly property color strong: "#ffffff"
    // El mismo atenuado que usa la barra para lo que está ahí pero no reclama
    // la vista (la campana y el botón de sesión en reposo van a opacity 0.55).
    readonly property color muted: Qt.rgba(1, 1, 1, 0.55)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.35)
    readonly property color rule: Qt.rgba(1, 1, 1, 0.12)

    // El resalte no es un color de marca: es otra lámina de cristal, blanca y
    // casi transparente, por encima de la anterior. De ahí que el acento sea
    // blanco y lo que cambie sea el alfa con el que se aplica.
    readonly property color accent: "#ffffff"

    // --- Acentos ---------------------------------------------------------
    // Reservados para lo que de verdad los merece: verde "algo está activo",
    // naranja aviso, rojo crítico. Son los mismos de los estados de la barra.
    readonly property color ok: "#6dc89e"
    readonly property color warn: "#e59625"
    readonly property color danger: "#e90b25"

    readonly property string font: "JetBrainsMono Nerd Font"

    // --- Medidas ---------------------------------------------------------
    readonly property int cardWidth: 380
    readonly property int radius: 16
    readonly property int pad: 14
    readonly property int gap: 10

    // Distancia desde el borde de la pantalla a la que cuelgan los paneles.
    // Salen de la barra: margin-top 3 + height 26 + un dedo de aire, y el
    // margin-left/right 12 del propio waybar redondeado a 14.
    readonly property int dropTop: 38
    readonly property int dropSide: 14

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
