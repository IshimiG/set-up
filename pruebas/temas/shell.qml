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
    property real radiusAlNacer: 0

    Component.onCompleted: {
        prueba.alNacer = Theme.nombreTema;
        prueba.radiusAlNacer = Theme.radius;
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
    }

    // Liquido, por sus reglas: no se fijan los colores exactos (para poder
    // afinarlos sin tocar la prueba), sí lo que no se puede romper.
    function comprobarLiquido(donde) {
        prueba.ok(Theme.nombreTema === "liquido" && Theme.liquido, donde + ": nombreTema es liquido y liquido, true");
        prueba.ok(Theme.radius === 24 && Theme.radiusSmall === 14 && Theme.radiusPill === 999, donde + ": radios 24, 14 y 999");
        prueba.ok(Theme.bordeAnchura === 1.5, donde + ": bordeAnchura 1.5");
        prueba.ok(prueba.cerca(Theme.ignoreAlpha, Number(Quickshell.env("PRUEBA_IA_LIQUIDO"))), donde + ": ignoreAlpha (" + Theme.ignoreAlpha + ") es el de hyprland.lua en liquido (" + Quickshell.env("PRUEBA_IA_LIQUIDO") + ")");
        const cuerpo = [Theme.glassTop.a, Theme.glassBottom.a];
        prueba.ok(cuerpo.every(a => a >= 0.25 - 0.002 && a <= 0.4 + 0.002), donde + ": el cristal va de 0.25 a 0.4 de alfa (" + cuerpo.map(a => a.toFixed(2)).join(", ") + ")");
        prueba.ok([Theme.glassTop, Theme.glassBottom, Theme.glassClear].every(c => c.a >= Theme.ignoreAlpha), donde + ": todo el cristal, también glassClear, queda por encima del ignoreAlpha");
        prueba.ok(Theme.glassTop.a > Theme.glassBottom.a, donde + ": el cristal es más denso arriba");
        prueba.ok([Theme.glassTop, Theme.glassBottom].every(c => c.b >= c.r && c.b >= c.g && c.r > 0.7), donde + ": el cristal es blanco azulado");
        prueba.ok(Theme.glassDense.a >= 0.85, donde + ": lo que flota sobre el contenido es casi opaco, no cristal sobre cristal (" + Theme.glassDense.a.toFixed(2) + ")");
        prueba.ok(prueba.cerca(Theme.edgeTop.a, 0.55) && Theme.edgeBottom.a < Theme.edgeTop.a / 2, donde + ": canto marcado arriba (" + Theme.edgeTop.a.toFixed(2) + ") y tenue abajo (" + Theme.edgeBottom.a.toFixed(2) + ")");
        prueba.ok(Theme.specular.a > 0 && prueba.cerca(Theme.specularHeight, 0.33), donde + ": brillo especular en el tercio de arriba");
        prueba.ok(Theme.tint.a > 0 && Theme.tint.a <= 0.15 && Theme.tint.b > Theme.tint.r, donde + ": tinte frío y sutil");
        prueba.ok(Theme.shadowColor.a > 0 && Theme.shadowRadius > 0, donde + ": sombra suave");
        prueba.ok(prueba.mismo(Theme.text, "#ffffff") && prueba.mismo(Theme.strong, "#ffffff"), donde + ": texto blanco puro");
        prueba.ok(prueba.mismo(Theme.prioAlta, "#ff9a4d") && Theme.font === "JetBrainsMono Nerd Font" && Theme.pad === 14 && Theme.dropTop === 38, donde + ": lo que no es del tema (prioridades, letra, medidas) no cambia");
    }

    readonly property var pasos: prueba.modo === "inicio" ? pasosInicio : pasosCambio

    readonly property var pasosInicio: [function () {
            prueba.ok(prueba.alNacer === "liquido" && prueba.radiusAlNacer === 24, "al arrancar con el fichero en liquido, Theme ya es liquido desde el primer momento (" + prueba.alNacer + ", radio " + prueba.radiusAlNacer + ")");
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
