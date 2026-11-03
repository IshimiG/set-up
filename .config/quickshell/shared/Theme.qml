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
// Los valores que cambian con el tema (el cristal, el canto, el texto, el
// brillo…; nunca las medidas) no se escriben aquí arriba sino en una Paleta
// por tema, al final del fichero. Las propiedades públicas son siempre las
// mismas y apuntan a la paleta del tema activo, así que cambiar de tema
// repinta en caliente los 50 y tantos ficheros que usan Theme sin tocar
// ninguno.
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
    readonly property var paletas: [paletaDefault, paletaLiquido]
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
    // default es negro translúcido; en liquido, blanco muy translúcido.
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
    // sobre negro se lee como un subrayado. En liquido el canto de una lámina
    // lo pinta el shader (ver vidrio, más abajo) y éste queda para los filos
    // planos: un aviso, la ayuda de atajos, el respaldo sin shader.
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

    // Cristal de vidrio (sólo liquido): la lámina la pinta entera un shader
    // (shared/cristal.frag, desde Cristal.qml) en vez del canto de abajo y el
    // cuerpo de encima, porque con un cuerpo tan translúcido el canto de
    // debajo se vería a través y lo volvería lechoso. Lo que lleva:
    //   - rimStops: las paradas del canto, de arriba a la izquierda a abajo a
    //     la derecha: blancos con distinto alfa, más brillante donde da la luz
    //     y tenue abajo. Sin color: el cristal es neutro.
    //   - rimCorner y rimMid: cuánto de ese alfa en las esquinas y en el medio
    //     de los lados (el filo brilla más donde se curva).
    //   - rimLight: cuánto aviva la luz (de arriba a la izquierda) el canto de
    //     arriba y la media luna especular de dentro; rimReflect, el reflejo
    //     del canto de abajo, el lado contrario a la luz.
    //   - thickness: el ancho máximo del resplandor blanco de dentro del
    //     canto, el grosor del vidrio (en una lámina baja se estrecha solo).
    //   - sheen: el brillo ancho y muy tenue de la parte de arriba.
    // En default, apagado (vidrio false, sin paradas y a 0): Cristal pinta el
    // canto con degradado y el cuerpo de siempre.
    readonly property bool vidrio: theme.activo.vidrio
    readonly property list<color> rimStops: theme.activo.rimStops
    readonly property real rimCorner: theme.activo.rimCorner
    readonly property real rimMid: theme.activo.rimMid
    readonly property real rimLight: theme.activo.rimLight
    readonly property real rimReflect: theme.activo.rimReflect
    readonly property real thickness: theme.activo.thickness
    readonly property real sheen: theme.activo.sheen
    // Un velo neutro oscuro para las láminas con mucho texto que caen encima
    // de las ventanas (el cajón, los avisos, la isla abierta, el lanzador…):
    // sobre una ventana clara, un cristal tan translúcido deja el texto blanco
    // sin contraste. Lo pide cada lámina con Cristal.lectura. En default,
    // transparente: el cuerpo negro ya basta.
    readonly property color readingVeil: theme.activo.readingVeil

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
    // Las mismas en todos los temas: un tema cambia el material (colores,
    // canto, brillos, sombra), nunca la forma ni el tamaño. Por eso no están
    // en las paletas.
    readonly property int cardWidth: 380
    // El radio de una lámina (una tarjeta, el cajón, un panel).
    readonly property int radius: 16
    // El de lo que va dentro de una lámina: un botón, un campo, una fila.
    readonly property int radiusSmall: 8
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

        property bool vidrio: false
        property list<color> rimStops: []
        property real rimCorner: 0
        property real rimMid: 0
        property real rimLight: 0
        property real rimReflect: 0
        property real thickness: 0
        property real sheen: 0
        property color readingVeil: "transparent"

        property color text: Qt.rgba(1, 1, 1, 0.78)
        property color strong: "#ffffff"
        property color muted: Qt.rgba(1, 1, 1, 0.55)
        property color faint: Qt.rgba(1, 1, 1, 0.35)
        property color rule: Qt.rgba(1, 1, 1, 0.12)
        property color accent: "#ffffff"

        property color ok: "#6dc89e"
        property color warn: "#e59625"
        property color danger: "#e90b25"

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

    // Cristal neutro y sencillo, a la manera del Liquid Glass de Apple (las
    // baldosas de la pantalla de inicio de iOS 26):
    //   - Una lámina blanca muy translúcida (al 0.17 arriba y al 0.16 abajo)
    //     que deja ver el color del fondo desenfocado (el blur lo pone
    //     Hyprland). Sin tinte: el color es el del fondo. Su alfa va justo por
    //     encima del ignore_alpha de este tema (0.15), que hyprland.lua baja
    //     para eso: por debajo, Hyprland no desenfocaría.
    //   - Un canto fino blanco, brillante arriba a la izquierda y tenue abajo,
    //     con un resplandor fino por dentro (el grosor del vidrio) y un brillo
    //     especular muy discreto arriba. Lo pinta shared/cristal.frag (ver
    //     vidrio, más arriba).
    //   - Las medidas (radios, rellenos, huecos, cápsulas) son las de default:
    //     el tema cambia el material, no la forma.
    //   - Texto blanco puro y atenuados más altos que en default: sobre
    //     cristal claro, un blanco al 35 % desaparece. Los acentos, los de
    //     default.
    //   - Ningún color propio: ni tinte, ni lavados, ni canto de color.
    //   - Sólo en la capa de navegación (barra, isla, cajón, lanzador,
    //     avisos). El contenido que flota encima (glassDense) no es cristal
    //     sino una lámina casi opaca: el cristal no se pone sobre cristal.
    Paleta {
        id: paletaLiquido
        nombre: "liquido"

        glassTop: Qt.rgba(1, 1, 1, 0.17)
        glassBottom: Qt.rgba(1, 1, 1, 0.16)
        glassClear: Qt.rgba(1, 1, 1, 0.16)
        glassDense: Qt.rgba(0.08, 0.08, 0.09, 0.90)
        ignoreAlpha: 0.15

        // El canto plano, para lo que no es una lámina entera (el filo de un
        // aviso, de la ayuda de atajos, el respaldo sin shader).
        edgeTop: Qt.rgba(1, 1, 1, 0.55)
        edgeBottom: Qt.rgba(1, 1, 1, 0.14)
        bordeAnchura: 1.5

        specular: Qt.rgba(1, 1, 1, 0.14)
        specularHeight: 0.33
        shadowColor: Qt.rgba(0, 0, 0, 0.22)
        shadowRadius: 22

        vidrio: true
        rimStops: [Qt.rgba(1, 1, 1, 0.95), Qt.rgba(1, 1, 1, 0.62), Qt.rgba(1, 1, 1, 0.36), Qt.rgba(1, 1, 1, 0.22), Qt.rgba(1, 1, 1, 0.30)]
        rimCorner: 1
        rimMid: 0.6
        rimLight: 0.6
        rimReflect: 0.25
        thickness: 4
        sheen: 0.04
        readingVeil: Qt.rgba(0, 0, 0, 0.16)

        text: "#ffffff"
        strong: "#ffffff"
        muted: Qt.rgba(1, 1, 1, 0.75)
        faint: Qt.rgba(1, 1, 1, 0.52)
        rule: Qt.rgba(1, 1, 1, 0.22)

        animIn: 460
        animOut: 300
        overshootIn: 1.5
        overshootOut: 1.3
    }
}
