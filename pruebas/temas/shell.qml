import QtQuick
import Quickshell
import Quickshell.Io
import "shared"

// Prueba sin pantalla de la paleta con temas (shared/Theme.qml). La lanza
// prueba.sh, al lado, con un $XDG_STATE_HOME de prueba.
//
// PRUEBA_MODO vacío: arranca sin fichero de tema y lo va cambiando con el
// tema.sh del repo (y una vez a mano, con basura), comprobando que Theme se
// entera en caliente y da los valores de cada tema: los de default, exactos
// (los de antes de haber temas), y los de liquido, por sus reglas.
// PRUEBA_MODO=inicio: el fichero ya dice liquido al arrancar, y Theme tiene
// que salir con liquido desde el primer momento, sin pasar por default.
//
// Cada comprobación imprime OK o FALLO; al final, "Resultado: …".
ShellRoot {
    id: prueba

    readonly property string modo: Quickshell.env("PRUEBA_MODO") ?? ""
    readonly property string temaSh: Quickshell.env("PRUEBA_TEMA_SH") ?? ""
    property int fallos: 0
    property int cuenta: 0
    property int paso: 0
    // Lo que valía al crearse la prueba, antes de que nada pueda recargar.
    property string alNacer: ""
    property bool vidrioAlNacer: false

    Component.onCompleted: {
        prueba.alNacer = Theme.nombreTema;
        prueba.vidrioAlNacer = Theme.vidrio;
    }

    function ok(cond, msg) {
        prueba.cuenta++;
        console.log((cond ? "OK     " : "FALLO  ") + msg);
        if (!cond)
            prueba.fallos++;
    }

    // Dos colores iguales si se escriben igual (#aarrggbb).
    function mismo(c, esperado) {
        return String(c) === String(esperado);
    }

    function cerca(a, b) {
        return Math.abs(a - b) < 0.002;
    }

    Process {
        id: orden
    }

    function lanzar(args) {
        orden.command = args;
        orden.running = true;
    }

    // Los valores de default: los de Theme.qml antes de haber temas, uno a
    // uno, y los neutros del contrato nuevo.
    function comprobarDefault(donde) {
        const v =[["glassTop", Qt.rgba(0, 0, 0, 0.76)], ["glassBottom", Qt.rgba(0, 0, 0, 0.64)], ["glassDense", Qt.rgba(0, 0, 0, 0.92)], ["edgeTop", Qt.rgba(1, 1, 1, 0.30)], ["edgeBottom", Qt.rgba(1, 1, 1, 0.08)], ["text", Qt.rgba(1, 1, 1, 0.78)], ["strong", "#ffffff"], ["muted", Qt.rgba(1, 1, 1, 0.55)], ["faint", Qt.rgba(1, 1, 1, 0.35)], ["rule", Qt.rgba(1, 1, 1, 0.12)], ["accent", "#ffffff"], ["ok", "#6dc89e"], ["warn", "#e59625"], ["danger", "#e90b25"], ["prioMaxima", "#ff6b7c"], ["prioAlta", "#ff9a4d"], ["prioMedia", "#f2d14b"], ["prioBaja", "#6dc89e"], ["prioMinima", "#7c7b8a"], ["prioPausa", "#6aa8ff"]];
        const distintos = [];
        for (const [nombre, esperado] of v) {
            if (!prueba.mismo(Theme[nombre], esperado))
                distintos.push(nombre + "=" + Theme[nombre] + " (antes " + esperado + ")");
        }
        prueba.ok(distintos.length === 0, donde + ": los colores de default son los de siempre" + (distintos.length ? ": " + distintos.join(", ") : ""));

        const n = [["font", "JetBrainsMono Nerd Font"], ["cardWidth", 380], ["radius", 16], ["pad", 14], ["gap", 10], ["dropTop", 38], ["dropSide", 14], ["slideRoom", 44], ["minTimeout", 10000], ["animIn", 420], ["animOut", 300], ["overshootIn", 1.9], ["overshootOut", 1.5]];
        const otros = n.filter(([k, e]) => Theme[k] !== e).map(([k, e]) => k + "=" + Theme[k] + " (antes " + e + ")");
        prueba.ok(otros.length === 0, donde + ": las medidas, tiempos y animación de default son los de siempre" + (otros.length ? ": " + otros.join(", ") : ""));
        prueba.ok(Theme.timeoutFor(2) === 0 && Theme.timeoutFor(1) === 10000 && prueba.mismo(Theme.colorPrioridad("alta"), Theme.prioAlta) && prueba.mismo(Theme.colorPrioridad("otra"), Theme.prioMinima), donde + ": timeoutFor y colorPrioridad, igual");

        prueba.ok(Theme.nombreTema === "default" && !Theme.liquido, donde + ": nombreTema es default y liquido, false");
        prueba.ok(Theme.radiusSmall === 8 && Theme.radiusPill === 999, donde + ": radiusSmall 8 y radiusPill 999");
        prueba.ok(Theme.specular.a === 0 && Theme.specularHeight === 0 && Theme.tint.a === 0, donde + ": sin brillo especular ni tinte (transparentes, altura 0)");
        prueba.ok(Theme.shadowColor.a === 0 && Theme.shadowRadius === 0, donde + ": sin sombra (transparente, radio 0)");
        prueba.ok(Theme.bordeAnchura === 1, donde + ": bordeAnchura 1");
        prueba.ok(prueba.mismo(Theme.glassClear, Theme.glassBottom), donde + ": glassClear es el cuerpo de siempre");
        prueba.ok(prueba.cerca(Theme.ignoreAlpha, Number(Quickshell.env("PRUEBA_IA_DEFAULT"))), donde + ": ignoreAlpha (" + Theme.ignoreAlpha + ") es el de hyprland.lua en default (" + Quickshell.env("PRUEBA_IA_DEFAULT") + ")");
        prueba.ok(!Theme.vidrio && Theme.rimStops.length === 0 && Theme.readingVeil.a === 0 && Theme.thickness === 0 && Theme.sheen === 0 && Theme.rimCorner === 0 && Theme.rimMid === 0 && Theme.rimLight === 0 && Theme.rimReflect === 0, donde + ": sin el shader del vidrio, ni velo de lectura (apagado, sin paradas y a 0)");
        prueba.ok(Theme.aberracion === undefined && Theme.franjaRoja === undefined && Theme.franjaCian === undefined, donde + ": Theme ya no tiene aberración cromática");
    }

    // Las medidas: en todos los temas, las de default. Un tema cambia el
    // material, no la forma.
    readonly property var medidas: [["radius", 16], ["radiusSmall", 8], ["radiusPill", 999], ["pad", 14], ["gap", 10], ["cardWidth", 380], ["dropTop", 38], ["dropSide", 14], ["slideRoom", 44]]

    // Liquido, por sus reglas: no se fijan los colores exactos (para poder
    // afinarlos sin tocar la prueba), sí lo que no se puede romper.
    function comprobarLiquido(donde) {
        prueba.ok(Theme.nombreTema === "liquido" && Theme.liquido, donde + ": nombreTema es liquido y liquido, true");
        const otras = prueba.medidas.filter(([k, e]) => Theme[k] !== e).map(([k, e]) => k + "=" + Theme[k] + " (default " + e + ")");
        prueba.ok(otras.length === 0, donde + ": las medidas (radios, cápsula, rellenos, huecos, anchos) son las de default" + (otras.length ? ": " + otras.join(", ") : ""));
        prueba.ok(Theme.bordeAnchura >= 1 && Theme.bordeAnchura <= 2, donde + ": el canto, de 1 a 2 px (" + Theme.bordeAnchura + ")");
        prueba.ok(prueba.cerca(Theme.ignoreAlpha, Number(Quickshell.env("PRUEBA_IA_LIQUIDO"))), donde + ": ignoreAlpha (" + Theme.ignoreAlpha + ") es el de hyprland.lua en liquido (" + Quickshell.env("PRUEBA_IA_LIQUIDO") + ")");
        const cuerpo = [Theme.glassTop.a, Theme.glassBottom.a];
        prueba.ok(cuerpo.every(a => a > Theme.ignoreAlpha && a <= 0.22), donde + ": el cristal es muy translúcido: de alfa, justo por encima del ignoreAlpha y hasta 0.22 (" + cuerpo.map(a => a.toFixed(2)).join(", ") + ")");
        prueba.ok([Theme.glassTop, Theme.glassBottom, Theme.glassClear].every(c => c.a >= Theme.ignoreAlpha), donde + ": todo el cristal, también glassClear, queda por encima del ignoreAlpha");
        prueba.ok(Theme.glassTop.a >= Theme.glassBottom.a, donde + ": el cristal no es menos denso arriba");
        prueba.ok([Theme.glassTop, Theme.glassBottom, Theme.glassClear].every(c => c.r > 0.9), donde + ": el cristal es claro (blanco translúcido)");
        prueba.ok(Theme.glassDense.a >= 0.85, donde + ": lo que flota sobre el contenido es casi opaco, no cristal sobre cristal (" + Theme.glassDense.a.toFixed(2) + ")");
        // Neutro: ningún color propio. Todo gris (r = g = b, con un pelo de
        // margen para el oscuro de glassDense), sin tinte.
        const neutro = c => Math.abs(c.r - c.g) < 0.02 && Math.abs(c.g - c.b) < 0.02;
        const grises = [["glassTop", Theme.glassTop], ["glassBottom", Theme.glassBottom], ["glassClear", Theme.glassClear], ["glassDense", Theme.glassDense], ["edgeTop", Theme.edgeTop], ["edgeBottom", Theme.edgeBottom], ["specular", Theme.specular], ["shadowColor", Theme.shadowColor], ["readingVeil", Theme.readingVeil], ["text", Theme.text], ["strong", Theme.strong], ["muted", Theme.muted], ["faint", Theme.faint], ["rule", Theme.rule], ["accent", Theme.accent]].concat(Array.from(Theme.rimStops).map((c, i) => ["rimStops[" + i + "]", c]));
        const conColor = grises.filter(([k, c]) => !neutro(c)).map(([k, c]) => k + "=" + c);
        prueba.ok(conColor.length === 0 && Theme.tint.a === 0, donde + ": cristal neutro, sin ningún color propio ni tinte" + (conColor.length ? ": " + conColor.join(", ") : ""));
        prueba.ok(prueba.mismo(Theme.ok, "#6dc89e") && prueba.mismo(Theme.warn, "#e59625") && prueba.mismo(Theme.danger, "#e90b25") && prueba.mismo(Theme.accent, "#ffffff"), donde + ": los acentos y estados, los de default");
        prueba.ok(Theme.vidrio && Theme.rimStops.length === 5, donde + ": vidrio, con cinco paradas en el canto");
        const alfas = Array.from(Theme.rimStops).map(c => c.a);
        prueba.ok(alfas[0] >= 0.85 && alfas[0] > alfas[2] && alfas[2] > alfas[3], donde + ": el canto, blanco brillante arriba a la izquierda y tenue abajo (" + alfas.map(a => a.toFixed(2)).join(", ") + ")");
        prueba.ok(Theme.rimCorner >= Theme.rimMid && Theme.rimMid > 0 && Theme.rimCorner <= 1, donde + ": el canto, igual o más vivo en las esquinas (" + Theme.rimCorner + ") que en el medio (" + Theme.rimMid + ")");
        prueba.ok(Theme.rimLight > 0 && Theme.rimReflect > 0 && Theme.rimReflect < Theme.rimLight, donde + ": luz arriba y un reflejo más tenue abajo");
        prueba.ok(Theme.thickness > 0 && Theme.thickness <= 6 && Theme.sheen > 0 && Theme.sheen <= 0.08, donde + ": un resplandor fino (" + Theme.thickness + ") y un brillo de arriba muy discreto (" + Theme.sheen + ")");
        prueba.ok(Theme.readingVeil.a > 0 && Theme.readingVeil.a <= 0.3, donde + ": un velo de lectura suave (" + Theme.readingVeil.a.toFixed(2) + ")");
        prueba.ok(Theme.specular.a > 0 && Theme.specularHeight > 0, donde + ": brillo especular también sin shader");
        prueba.ok(Theme.shadowColor.a > 0 && Theme.shadowRadius > 0, donde + ": sombra suave");
        prueba.ok(Theme.shadowColor.a * 5 / 8 < Theme.ignoreAlpha, donde + ": la sombra del cajón (cinco capas) queda por debajo del ignoreAlpha y Hyprland no la desenfoca");
        prueba.ok(prueba.mismo(Theme.text, "#ffffff") && prueba.mismo(Theme.strong, "#ffffff") && Theme.muted.a >= 0.7 && Theme.faint.a >= 0.5, donde + ": texto blanco puro y atenuados que se leen sobre el cristal claro");
        prueba.ok(Theme.aberracion === undefined, donde + ": sin aberración cromática");
        prueba.ok(prueba.mismo(Theme.prioAlta, "#ff9a4d") && Theme.font === "JetBrainsMono Nerd Font", donde + ": lo que no es del tema (prioridades, letra) no cambia");
    }

    readonly property var pasos: prueba.modo === "inicio" ? pasosInicio : pasosCambio

    readonly property var pasosInicio: [function () {
            prueba.ok(prueba.alNacer === "liquido" && prueba.vidrioAlNacer, "al arrancar con el fichero en liquido, Theme ya es liquido desde el primer momento (" + prueba.alNacer + ", vidrio " + prueba.vidrioAlNacer + ")");
            prueba.comprobarLiquido("al arrancar");
        }]

    readonly property var pasosCambio: [function () {
            prueba.ok(prueba.alNacer === "default", "sin fichero, Theme arranca en default");
            prueba.ok(Theme.temas.join(",") === "default,liquido", "temas: " + Theme.temas.join(", "));
            prueba.comprobarDefault("sin fichero");
            prueba.lanzar([prueba.temaSh, "liquido"]);
        }, function () {
            prueba.comprobarLiquido("tema.sh liquido, en caliente");
            prueba.lanzar(["sh", "-c", "printf 'basura\\n' >\"$1\"", "sh", Theme.rutaEstado]);
        }, function () {
            prueba.comprobarDefault("con basura en el fichero");
            prueba.lanzar([prueba.temaSh, "alternar"]);
        }, function () {
            prueba.ok(Theme.nombreTema === "liquido", "tema.sh alternar, desde default, pasa a liquido");
            prueba.lanzar([prueba.temaSh, "default"]);
        }, function () {
            prueba.comprobarDefault("tema.sh default, en caliente");
        }]

    Timer {
        // Lo que tarda el vigilante de FileView en avisar, con margen.
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            if (prueba.paso < prueba.pasos.length) {
                prueba.pasos[prueba.paso]();
                prueba.paso++;
                return;
            }
            stop();
            console.log("Resultado: " + prueba.cuenta + " comprobaciones, " + prueba.fallos + " fallos");
            Qt.quit();
        }
    }
}
