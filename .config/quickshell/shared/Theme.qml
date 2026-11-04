pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
//
// --- Temas ---------------------------------------------------------------
// Los valores que cambian con el tema (el cristal, el texto, los radios, el
// brillo…) no se escriben aquí arriba sino en una Paleta por tema, al final
// del fichero. Las propiedades públicas son siempre las mismas y apuntan a la
// paleta del tema activo, así que cambiar de tema repinta en caliente los 50
// y tantos ficheros que usan Theme sin tocar ninguno.
//
// El tema activo es una palabra en ${XDG_STATE_HOME:-~/.local/state}/
// escritorio/tema, que escribe ~/.config/hypr/scripts/tema.sh (SUPER+SHIFT+CTRL+T
// alterna). El mismo fichero lo lee hyprland.lua para el borde, el blur y el
// ignore_alpha de las superficies. Si falta, está vacío o dice algo que no es
// un tema, vale "default". No va en el repo: es de cada máquina.
//
// Para añadir un tema: una Paleta más abajo, con su `nombre` y sólo lo que
// cambie respecto a default (lo que no se toca sale de los valores de
// Paleta, que son los de default), metida en `paletas`; su tabla en `temas`
// de hyprland.lua y su nombre en TEMAS de tema.sh. Lo explica el README.
Singleton {
    id: theme

    // --- Tema activo -------------------------------------------------------
    // El fichero de estado. La carpeta la crea setup.sh (y tema.sh si falta):
    // el vigilante de FileView no ve aparecer un fichero en una carpeta que no
    // existía cuando arrancó Quickshell.
    readonly property string rutaEstado: {
        const xdg = Quickshell.env("XDG_STATE_HOME");
        return (xdg ? xdg : Quickshell.env("HOME") + "/.local/state") + "/escritorio/tema";
    }

    // Los temas que hay, en el orden de `tema.sh lista`.
    readonly property var paletas: [paletaDefault, paletaLiquido, paletaCatppuccin, paletaTokyonight, paletaGruvbox, paletaKanagawa, paletaPhosphor]
    readonly property var temas: theme.paletas.map(p => p.nombre)

    // El nombre del tema activo: lo que diga el fichero si es un tema que
    // existe; si no, "default".
    readonly property string nombreTema: {
        const leido = estado.text().trim();
        return theme.temas.indexOf(leido) >= 0 ? leido : "default";
    }
    // Atajo para el único otro tema que hay hoy: el cristal claro.
    readonly property bool liquido: theme.nombreTema === "liquido"

    readonly property Paleta activo: theme.paletas.find(p => p.nombre === theme.nombreTema) ?? paletaDefault

    FileView {
        id: estado

        path: theme.rutaEstado
        // El vigilante avisa al crearse, al reemplazarse (tema.sh escribe un
        // temporal y lo renombra encima) y al borrarse.
        watchChanges: true
        onFileChanged: estado.reload()
        // La primera lectura bloquea: es una palabra, y así ninguna superficie
        // se pinta un fotograma con default antes de saber el tema.
        blockLoading: true
        // Que no exista es lo normal en una máquina que nunca cambió de tema.
        printErrors: false
    }

    // --- Cristal ---------------------------------------------------------
    // El cuerpo de una lámina de cristal: un degradado vertical de glassTop a
    // glassBottom, algo más denso arriba, donde la lámina recoge la luz. En
    // default es negro translúcido; en liquido, blanco azulado.
    //
    // El alfa no puede bajar de ignoreAlpha. Los layer_rule de
    // ~/.config/hypr/hyprland.lua usan ese ignore_alpha, y por debajo de ese
    // umbral Hyprland deja de desenfocar la superficie: el cristal se queda
    // liso y se pierde el frosted. Al revés, lo que no deba desenfocarse (un
    // velo para oscurecer el fondo, una sombra) tiene que ir por debajo.
    readonly property color glassTop: theme.activo.glassTop
    readonly property color glassBottom: theme.activo.glassBottom
    // La variante "clear" del cristal de Apple: más transparente, para ir
    // sobre algo con mucho color (una imagen, el fondo) y siempre con el
    // texto en strong. En default es el mismo cuerpo que glassBottom.
    readonly property color glassClear: theme.activo.glassClear
    // Lo que flota sobre el propio contenido de una superficie (la ayuda de
    // atajos o un aviso del cajón) va casi opaco: debajo no hay un fondo
    // desenfocado sino texto, y se leería a través. Por eso nunca es cristal:
    // el cristal no se pone encima de otro cristal.
    readonly property color glassDense: theme.activo.glassDense
    // El umbral de desenfoque, el mismo número que el ignore_alpha de los
    // layer_rule de hyprland.lua en este tema: 0.5 en default, 0.15 en
    // liquido.
    readonly property real ignoreAlpha: theme.activo.ignoreAlpha

    // Canto: blanco puro, igual que el borde de ventana de Hyprland. Sólo
    // varía el alfa, y en default va muy contenido porque un filo brillante
    // sobre negro se lee como un subrayado. En liquido el de arriba es el
    // filo de luz que define la lámina.
    readonly property color edgeTop: theme.activo.edgeTop
    readonly property color edgeBottom: theme.activo.edgeBottom
    // El grueso del canto, en píxeles lógicos.
    readonly property real bordeAnchura: theme.activo.bordeAnchura

    // Brillo especular: un degradado de `specular` a transparente que cubre
    // el `specularHeight` de arriba de la lámina (0 = nada, 1 = entera). Es
    // el reflejo de la luz en la cara del cristal. En default, transparente y
    // de altura 0: no se pinta.
    readonly property color specular: theme.activo.specular
    readonly property real specularHeight: theme.activo.specularHeight

    // Tinte: un color que se pone encima del cuerpo, muy suave, para teñir el
    // cristal sin cambiar su alfa. En default, transparente.
    readonly property color tint: theme.activo.tint

    // La sombra de la lámina sobre lo que tiene detrás. En default no hay
    // (transparente y radio 0): la pone Hyprland en las ventanas, no en las
    // superficies de Quickshell.
    readonly property color shadowColor: theme.activo.shadowColor
    readonly property real shadowRadius: theme.activo.shadowRadius

    // Aberración cromática: el filo de liquido se separa a ratos en una franja
    // roja y otra cian, como una lente. En las ventanas la pone
    // ~/.config/hypr/scripts/aberracion.sh, a pulsos aleatorios; aquí sólo
    // está el interruptor y los dos colores, los mismos de hyprland.lua, por si
    // una superficie quiere hacer algo parecido. En default, apagada.
    readonly property bool aberracion: theme.activo.aberracion
    readonly property color franjaRoja: theme.activo.franjaRoja
    readonly property color franjaCian: theme.activo.franjaCian

    // --- Texto -----------------------------------------------------------
    readonly property color text: theme.activo.text
    readonly property color strong: theme.activo.strong
    // El mismo atenuado que usa la barra para lo que está ahí pero no reclama
    // la vista (la campana y el botón de sesión en reposo van a opacity 0.55).
    readonly property color muted: theme.activo.muted
    readonly property color faint: theme.activo.faint
    readonly property color rule: theme.activo.rule

    // El resalte no es un color de marca: es otra lámina de cristal, blanca y
    // casi transparente, por encima de la anterior. De ahí que el acento sea
    // blanco y lo que cambie sea el alfa con el que se aplica.
    readonly property color accent: theme.activo.accent

    // --- Acentos ---------------------------------------------------------
    // Reservados para lo que de verdad los merece: verde "algo está activo",
    // naranja aviso, rojo crítico. Son los mismos de los estados de la barra.
    readonly property color ok: theme.activo.ok
    readonly property color warn: theme.activo.warn
    readonly property color danger: theme.activo.danger

    // Los diez colores de los puntos de escritorio de la barra, del 1 al 10.
    readonly property var workspaceColores: theme.activo.workspaces

    // --- Prioridades -----------------------------------------------------
    // Las de las tareas del panel del homelab, copiadas de su web (las --p-*
    // de panel/internal/panel/web/style.css, repo homelab) para que una tarea
    // se vea del mismo color en la web y en el escritorio. Las usa el cajón
    // del panel (quickshell/homelab). En pausa es siempre azul. No cambian
    // con el tema, por lo mismo.
    readonly property color prioMaxima: "#ff6b7c"
    readonly property color prioAlta: "#ff9a4d"
    readonly property color prioMedia: "#f2d14b"
    readonly property color prioBaja: "#6dc89e"
    readonly property color prioMinima: "#7c7b8a"
    readonly property color prioPausa: "#6aa8ff"

    // El color de una prioridad por su nombre en español ("maxima", "alta",
    // "media", "baja", "minima" o "pausa"); sin prioridad, el gris de la mínima.
    function colorPrioridad(nombre) {
        switch (nombre) {
        case "maxima":
            return prioMaxima;
        case "alta":
            return prioAlta;
        case "media":
            return prioMedia;
        case "baja":
            return prioBaja;
        case "pausa":
            return prioPausa;
        default:
            return prioMinima;
        }
    }

    readonly property string font: "JetBrainsMono Nerd Font"

    // --- Medidas ---------------------------------------------------------
    readonly property int cardWidth: 380
    // El radio de una lámina (una tarjeta, el cajón, un panel).
    readonly property int radius: theme.activo.radius
    // El de lo que va dentro de una lámina: un botón, un campo, una fila.
    readonly property int radiusSmall: theme.activo.radiusSmall
    // Cápsula: con un radio mayor que medio alto, Qt redondea los dos lados
    // enteros. Es 999 en todos los temas; está aquí para que se lea como
    // "cápsula" y no como un número mágico.
    readonly property int radiusPill: 999
    readonly property int pad: 14
    readonly property int gap: 10

    // Distancia desde el borde de la pantalla a la que cuelgan los paneles.
    // Salen de la barra: margin-top 3 + height 26 + un dedo de aire, y el
    // margin-left/right 12 del propio waybar redondeado a 14.
    readonly property int dropTop: 38
    readonly property int dropSide: 14

    // Aire que las superficies que animan se dejan alrededor de su contenido.
    // Sin él la superficie mide justo lo que la tarjeta y la animación se
    // recorta a cuchillo contra su propio borde, que es exactamente lo que no
    // debe verse: lo que sale de la pantalla se va, lo que choca contra un
    // borde invisible parece un fallo.
    //
    // Hace falta por los cuatro lados, no sólo por donde la tarjeta entra: el
    // rebote de OutBack pasa de largo *más allá* del sitio donde va a pararse y
    // vuelve, así que una tarjeta que entra desde la derecha se sale unos
    // píxeles por la izquierda antes de asentarse, y el encogido de salida
    // crece un pelín antes de irse.
    readonly property int slideRoom: 44

    // --- Tiempos ---------------------------------------------------------
    // Cuánto se queda en pantalla una notificación antes de recogerse sola.
    // Diez segundos es el suelo de la casa: da tiempo a leerla de reojo sin
    // tener que ir a por ella, y es tiempo de sobra para decidir si merece un
    // clic. Se aplica también cuando la aplicación pide menos, porque muchas
    // piden dos o tres segundos pensando en un escritorio donde el aviso es lo
    // único que se mueve; aquí sale por un lado de la pantalla y hay que verlo
    // llegar. Lo que sí se respeta es pedir *más*, y pedir cero —que en el
    // protocolo significa "no te vayas sola"—.
    readonly property int minTimeout: 10000

    // Las críticas no se van solas: si algo es crítico, se cierra a mano.
    function timeoutFor(urgency) {
        if (urgency === 2)
            return 0;
        return minTimeout;
    }

    // --- Animación -------------------------------------------------------
    // El vocabulario de movimiento del escritorio, el mismo que los
    // `animation` de ~/.config/hypr/hyprland.lua: lo que aparece rebota al
    // llegar (OutBack, que pasa de largo y vuelve en el primer balanceo) y lo
    // que se va toma carrerilla hacia el otro lado antes de salir (InBack, el
    // mismo gesto leído al revés). La duración es fija en vez de un muelle de
    // verdad para que varias propiedades animadas a la vez —escala, opacidad,
    // altura— lleguen juntas. En liquido el rebote es más corto y el gesto un
    // pelín más largo: el cristal se deforma y se asienta, no bota.
    readonly property int animIn: theme.activo.animIn
    readonly property int animOut: theme.activo.animOut
    readonly property real overshootIn: theme.activo.overshootIn
    readonly property real overshootOut: theme.activo.overshootOut

    // --- Paletas ---------------------------------------------------------
    // Lo que cambia con el tema. Los valores de Paleta son los de default, así
    // que default es una Paleta sin tocar y cada tema sólo escribe lo suyo.
    component Paleta: QtObject {
        property string nombre: "default"

        property color glassTop: Qt.rgba(0, 0, 0, 0.76)
        property color glassBottom: Qt.rgba(0, 0, 0, 0.64)
        property color glassClear: Qt.rgba(0, 0, 0, 0.64)
        property color glassDense: Qt.rgba(0, 0, 0, 0.92)
        property real ignoreAlpha: 0.5

        property color edgeTop: Qt.rgba(1, 1, 1, 0.30)
        property color edgeBottom: Qt.rgba(1, 1, 1, 0.08)
        property real bordeAnchura: 1

        property color specular: Qt.rgba(1, 1, 1, 0)
        property real specularHeight: 0
        property color tint: "transparent"
        property color shadowColor: "transparent"
        property real shadowRadius: 0

        property bool aberracion: false
        property color franjaRoja: "transparent"
        property color franjaCian: "transparent"

        property color text: Qt.rgba(1, 1, 1, 0.78)
        property color strong: "#ffffff"
        property color muted: Qt.rgba(1, 1, 1, 0.55)
        property color faint: Qt.rgba(1, 1, 1, 0.35)
        property color rule: Qt.rgba(1, 1, 1, 0.12)
        property color accent: "#ffffff"

        property color ok: "#6dc89e"
        property color warn: "#e59625"
        property color danger: "#e90b25"

        property var workspaces: ["#e90b25", "#e59625", "#ffd966", "#deffa0", "#6dc89e", "#40e0d0", "#00aef2", "#bf3e81", "#df6280", "#ffe9ff"]

        property int radius: 16
        property int radiusSmall: 8

        property int animIn: 420
        property int animOut: 300
        property real overshootIn: 1.9
        property real overshootOut: 1.5
    }

    // El de siempre: cristal negro esmerilado con un filo blanco contenido.
    Paleta {
        id: paletaDefault
        nombre: "default"
    }

    // Cristal claro a la manera del Liquid Glass de Apple, traducido:
    //   - Una lámina blanco azulada muy translúcida, con degradado, que deja
    //     ver el fondo desenfocado (el blur lo pone Hyprland: más grande y con
    //     más vibrancy en este tema). Su alfa (0.26-0.34) va por encima del
    //     ignore_alpha de este tema (0.15), que hyprland.lua baja para eso.
    //   - Canto blanco marcado arriba y tenue abajo, y un brillo especular en
    //     el tercio de arriba: la luz entra por arriba y se refleja en la cara.
    //   - Un tinte frío muy suave y una sombra amplia y difusa debajo.
    //   - Texto blanco puro y atenuados más altos: sobre cristal claro, un
    //     blanco al 35 % desaparece.
    //   - Radios grandes y cápsulas (radiusPill) para los controles.
    //   - Sólo en la capa de navegación (barra, isla, cajón, lanzador,
    //     avisos). El contenido que flota encima (glassDense) no es cristal
    //     sino una lámina casi opaca: el cristal no se pone sobre cristal.
    //   - Los acentos son los colores de sistema de Apple en oscuro, que
    //     aguantan sobre un fondo claro.
    Paleta {
        id: paletaLiquido
        nombre: "liquido"

        glassTop: Qt.rgba(0.84, 0.89, 1, 0.34)
        glassBottom: Qt.rgba(0.80, 0.86, 1, 0.26)
        glassClear: Qt.rgba(0.86, 0.91, 1, 0.18)
        glassDense: Qt.rgba(0.08, 0.10, 0.15, 0.90)
        ignoreAlpha: 0.15

        edgeTop: Qt.rgba(1, 1, 1, 0.55)
        edgeBottom: Qt.rgba(1, 1, 1, 0.14)
        bordeAnchura: 1.5

        specular: Qt.rgba(1, 1, 1, 0.30)
        specularHeight: 0.33
        tint: Qt.rgba(0.55, 0.72, 1, 0.08)
        shadowColor: Qt.rgba(0, 0.02, 0.08, 0.35)
        shadowRadius: 24

        aberracion: true
        franjaRoja: Qt.rgba(1, 0.23, 0.42, 0.6)
        franjaCian: Qt.rgba(0.23, 0.91, 1, 0.6)

        text: "#ffffff"
        strong: "#ffffff"
        muted: Qt.rgba(1, 1, 1, 0.75)
        faint: Qt.rgba(1, 1, 1, 0.52)
        rule: Qt.rgba(1, 1, 1, 0.22)
        accent: "#ffffff"

        ok: "#30d158"
        warn: "#ff9f0a"
        danger: "#ff453a"

        radius: 24
        radiusSmall: 14

        animIn: 460
        animOut: 300
        overshootIn: 1.5
        overshootOut: 1.3
    }

    // Catppuccin Mocha: cristal malva-oscuro (base #1e1e2e), texto lavanda
    // claro, acento mauve y radios grandes.
    Paleta {
        id: paletaCatppuccin
        nombre: "catppuccin"

        glassTop: Qt.alpha("#1e1e2e", 0.74)
        glassBottom: Qt.alpha("#1e1e2e", 0.62)
        glassClear: Qt.alpha("#1e1e2e", 0.50)
        glassDense: Qt.alpha("#11111b", 0.94)
        ignoreAlpha: 0.3

        edgeTop: Qt.alpha("#cba6f7", 0.45)
        edgeBottom: Qt.alpha("#89b4fa", 0.14)
        bordeAnchura: 1.5

        specular: Qt.alpha("#f5e0dc", 0.08)
        specularHeight: 0.25
        shadowColor: Qt.alpha("#11111b", 0.5)
        shadowRadius: 20

        text: "#cdd6f4"
        strong: "#f5e0dc"
        muted: "#a6adc8"
        faint: "#6c7086"
        rule: Qt.alpha("#cdd6f4", 0.12)
        accent: "#cba6f7"

        ok: "#a6e3a1"
        warn: "#fab387"
        danger: "#f38ba8"

        workspaces: ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89dceb", "#89b4fa", "#cba6f7", "#f5c2e7", "#f5e0dc"]

        radius: 20
        radiusSmall: 12

        animIn: 460
        animOut: 300
        overshootIn: 2.0
        overshootOut: 1.5
    }

    // Tokyo Night (night): cristal índigo, canto azul eléctrico y una sombra
    // azul que hace de resplandor.
    Paleta {
        id: paletaTokyonight
        nombre: "tokyonight"

        glassTop: Qt.alpha("#1a1b26", 0.72)
        glassBottom: Qt.alpha("#16161e", 0.60)
        glassClear: Qt.alpha("#1a1b26", 0.48)
        glassDense: Qt.alpha("#16161e", 0.94)
        ignoreAlpha: 0.3

        edgeTop: Qt.alpha("#7aa2f7", 0.65)
        edgeBottom: Qt.alpha("#bb9af7", 0.25)
        bordeAnchura: 1.5

        tint: Qt.alpha("#7aa2f7", 0.04)
        shadowColor: Qt.alpha("#7aa2f7", 0.35)
        shadowRadius: 30

        text: "#c0caf5"
        strong: "#e0e6ff"
        muted: "#a9b1d6"
        faint: "#565f89"
        rule: Qt.alpha("#7aa2f7", 0.18)
        accent: "#7aa2f7"

        ok: "#9ece6a"
        warn: "#e0af68"
        danger: "#f7768e"

        workspaces: ["#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#1abc9c", "#7dcfff", "#7aa2f7", "#bb9af7", "#9d7cd8", "#c0caf5"]

        radius: 12
        radiusSmall: 8

        animIn: 380
        animOut: 260
        overshootIn: 1.6
        overshootOut: 1.3
    }

    // Gruvbox dark hard: plano, mate y opaco. Sin blur no hay cristal que
    // valga, así que el cuerpo es casi sólido, el canto un filo sólido de
    // papel viejo, y cero radio, brillo y sombra.
    Paleta {
        id: paletaGruvbox
        nombre: "gruvbox"

        glassTop: Qt.alpha("#282828", 0.98)
        glassBottom: Qt.alpha("#282828", 0.98)
        glassClear: Qt.alpha("#282828", 0.94)
        glassDense: "#1d2021"
        ignoreAlpha: 0.5

        edgeTop: "#665c54"
        edgeBottom: "#504945"
        bordeAnchura: 2

        text: "#ebdbb2"
        strong: "#fbf1c7"
        muted: "#a89984"
        faint: "#7c6f64"
        rule: "#504945"
        accent: "#fe8019"

        ok: "#b8bb26"
        warn: "#fabd2f"
        danger: "#fb4934"

        workspaces: ["#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#458588", "#d3869b", "#b16286", "#ebdbb2"]

        radius: 0
        radiusSmall: 0

        animIn: 160
        animOut: 120
        overshootIn: 0
        overshootOut: 0
    }

    // Kanagawa Wave: tinta sumi, cristal sobrio y contraste moderado, canto
    // fino y apagado, radios medios y poco rebote.
    Paleta {
        id: paletaKanagawa
        nombre: "kanagawa"

        glassTop: Qt.alpha("#1f1f28", 0.82)
        glassBottom: Qt.alpha("#1f1f28", 0.72)
        glassClear: Qt.alpha("#1f1f28", 0.58)
        glassDense: Qt.alpha("#16161d", 0.95)
        ignoreAlpha: 0.3

        edgeTop: Qt.alpha("#54546d", 0.85)
        edgeBottom: Qt.alpha("#363646", 0.6)
        bordeAnchura: 1

        shadowColor: Qt.alpha("#16161d", 0.5)
        shadowRadius: 14

        text: "#dcd7ba"
        strong: "#fffbe0"
        muted: "#c8c093"
        faint: "#727169"
        rule: Qt.alpha("#dcd7ba", 0.12)
        accent: "#7e9cd8"

        ok: "#98bb6c"
        warn: "#ffa066"
        danger: "#e46876"

        workspaces: ["#e46876", "#ffa066", "#e6c384", "#98bb6c", "#7aa89f", "#7fb4ca", "#7e9cd8", "#957fb8", "#d27e99", "#dcd7ba"]

        radius: 10
        radiusSmall: 6

        animIn: 380
        animOut: 260
        overshootIn: 1.2
        overshootOut: 1.1
    }

    // Terminal de fósforo verde, brutalista: negro puro, una sola tinta, filo
    // duro, cero radio, cero sombra y animaciones secas. Sólo el aviso y el
    // peligro se salen del verde, porque tienen que distinguirse.
    Paleta {
        id: paletaPhosphor
        nombre: "phosphor"

        glassTop: "#000000"
        glassBottom: "#020a02"
        glassClear: Qt.alpha("#000000", 0.92)
        glassDense: "#000000"
        ignoreAlpha: 0.5

        edgeTop: "#00a600"
        edgeBottom: "#0a3a0a"
        bordeAnchura: 1

        text: "#00d900"
        strong: "#00ff00"
        muted: "#00a600"
        faint: "#006a00"
        rule: "#0a3a0a"
        accent: "#23ff18"

        ok: "#00ff00"
        warn: "#e5e500"
        danger: "#e50000"

        workspaces: ["#006a00", "#008a00", "#00a600", "#00c000", "#00d900", "#00ee00", "#00ff00", "#23ff18", "#66ff66", "#b3ffb3"]

        radius: 0
        radiusSmall: 0

        animIn: 90
        animOut: 70
        overshootIn: 0
        overshootOut: 0
    }
}
