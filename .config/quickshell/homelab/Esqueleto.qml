pragma ComponentBehavior: Bound
import QtQuick
import "shared"

// El cuerpo esqueleto, en ASCII de verdad: una cuadrícula de caracteres
// monoespaciados. Cada tarjeta es un marco redondeado (╭─╮│╰╯) con un avatar
// de 6x3 celdas de █, una barra de título, una de subtítulo y dos de texto, y
// una banda diagonal de brillo recorre los █ en 8 tonos de gris azulado. Se
// enseña en lugar de un hueco mientras una sección carga (SeccionPerezosa.qml).
//
// Inspirado en Skeleton Loader de ASCII Magic (MIT):
// https://www.ascii-magic.com/ascii/skeleton-loader
//
// Rendimiento: ni un Text por celda ni uno por tarjeta; el cuerpo entero es UN
// Text (StyledText, que es más barato que RichText) con tramos <font color>
// agrupados por tono, y la cabecera, otro. El reloj es el único de todos los
// esqueletos (shared/Reloj.qml, ~24 fps) y sólo corre mientras alguno se ve.
// La maqueta (qué celda es marco, barra o hueco) se calcula sólo al cambiar el
// tamaño o la variante; en cada cuadro sólo se recolorean los █.
//
//   variante "filas":    cabecera y una lista de tarjetas a todo el ancho
//   variante "tarjetas": cabecera y una rejilla de tarjetas (2 columnas si caben)
Item {
    id: esqueleto

    property string variante: "filas"
    // Cuántas tarjetas se dibujan como máximo (el resto se recorta al alto).
    property int cantidad: 8
    // Cuadros pintados (para medir ticks por segundo).
    property int cuadros: 0
    // Decorativo: no recibe ni anuncia nada.
    Accessible.ignored: true

    // Los 8 tonos, del más oscuro al más claro (#1c2128 -> #2d333b -> #444c56 -> #636e7b).
    readonly property var tonos: ["#1c2128", "#232930", "#2d333b", "#394049", "#444c56", "#525b66", "#5c6672", "#636e7b"]
    // Color del marco (≈ #484f58).
    readonly property string colorMarco: "#484f58"

    // La celda de la fuente de Theme.
    TextMetrics {
        id: medida

        font.family: Theme.font
        font.pixelSize: 13
        text: "█"
    }
    readonly property real celdaAncho: Math.max(1, medida.advanceWidth)
    readonly property real celdaAlto: Math.max(1, Math.ceil(medida.height))
    readonly property int columnas: Math.max(8, Math.floor(cuerpo.width / esqueleto.celdaAncho))
    readonly property int filasMax: Math.max(1, Math.floor((cuerpo.height - esqueleto.celdaAlto * 2) / esqueleto.celdaAlto))

    // La maqueta: por fila, un texto de caracteres y un texto de clases
    // (' ' hueco, 'm' marco, 'b' barra). Se rehace sólo al cambiar algo.
    property var maqueta: []
    property var cabeceraMaqueta: []
    // Recuerda la columna y fila de cada celda para el brillo (x, y de la rejilla).
    readonly property bool vivo: esqueleto.visible && esqueleto.width > 0 && esqueleto.height > 0

    function _fila(n: int): var {
        return {
            c: new Array(n).fill(" "),
            k: new Array(n).fill(" ")
        };
    }

    // Escribe `txt` en la fila desde la columna x con la clase k.
    function _poner(f: var, x: int, txt: string, k: string): void {
        for (let i = 0; i < txt.length && x + i < f.c.length; i++) {
            if (x + i < 0)
                continue;
            f.c[x + i] = txt[i];
            f.k[x + i] = k;
        }
    }
    function _barra(f: var, x: int, largo: int, tope: int): void {
        const l = Math.max(0, Math.min(largo, tope));
        if (l > 0)
            esqueleto._poner(f, x, "█".repeat(l), "b");
    }

    // Dibuja una tarjeta de `an` columnas en las filas desde y0 de `filas`,
    // empezando en la columna x0. `n` varía un poco los largos.
    function _tarjeta(filas: var, x0: int, y0: int, an: int, n: int): void {
        const alto = 7;
        const arriba = "╭" + "─".repeat(an - 2) + "╮";
        const abajo = "╰" + "─".repeat(an - 2) + "╯";
        esqueleto._poner(filas[y0], x0, arriba, "m");
        for (let r = 1; r < alto - 1; r++) {
            esqueleto._poner(filas[y0 + r], x0, "│", "m");
            esqueleto._poner(filas[y0 + r], x0 + an - 1, "│", "m");
        }
        esqueleto._poner(filas[y0 + alto - 1], x0, abajo, "m");
        // Avatar 6x3 (si cabe).
        const av = an >= 20 ? 6 : 0;
        for (let r = 1; r <= 3 && av > 0; r++)
            esqueleto._barra(filas[y0 + r], x0 + 2, av, av);
        const xt = x0 + 2 + (av > 0 ? av + 1 : 0);
        const disp = an - 2 - (xt - x0 - 1) - 1;
        // Título (18), subtítulo (11), y dos de texto (44 y 36) a lo ancho.
        esqueleto._barra(filas[y0 + 1], xt, n % 2 === 0 ? 18 : 15, disp);
        esqueleto._barra(filas[y0 + 2], xt, n % 3 === 0 ? 11 : 9, disp);
        const dispAncho = an - 4;
        esqueleto._barra(filas[y0 + 4], x0 + 2, 44, dispAncho);
        esqueleto._barra(filas[y0 + 5], x0 + 2, n % 3 === 0 ? 30 : 36, dispAncho);
    }

    function rehacer(): void {
        const cols = esqueleto.columnas;
        const total = esqueleto.filasMax;
        const filas = [];
        for (let i = 0; i < total; i++)
            filas.push(esqueleto._fila(cols));
        const dos = esqueleto.variante === "tarjetas" && cols >= 58;
        const an = dos ? Math.floor((cols - 2) / 2) : cols;
        let n = 0;
        for (let y = 0; y + 7 <= total && n < esqueleto.cantidad; y += 8) {
            esqueleto._tarjeta(filas, 0, y, an, n++);
            if (dos && n < esqueleto.cantidad)
                esqueleto._tarjeta(filas, an + 2, y, cols - an - 2, n++);
        }
        // Cabecera: una barra de título.
        const cab = esqueleto._fila(cols);
        esqueleto._barra(cab, 0, Math.min(24, Math.floor(cols / 2)), cols);
        esqueleto.maqueta = filas;
        esqueleto.cabeceraMaqueta = [cab];
        esqueleto.pintar();
    }

    // El tono k de la celda (x, y) en t segundos.
    function _tono(x: int, y: int, t: real): int {
        const c = Math.cos((x * 0.12 - y * 0.25 - t * 2.4) * 1.3);
        const v = c > 0 ? Math.pow(c, 6) : 0;
        return Math.min(7, Math.max(0, Math.round(2 + v * 5)));
    }

    // El StyledText de un bloque de filas; `y0` desplaza la fila para el brillo.
    function _html(filas: var, y0: int, t: real): string {
        const tn = esqueleto.tonos;
        const marco = esqueleto.colorMarco;
        let sal = "";
        for (let y = 0; y < filas.length; y++) {
            const f = filas[y];
            const n = f.c.length;
            let i = 0;
            while (i < n) {
                const k = f.k[i];
                if (k === " ") {
                    let j = i + 1;
                    while (j < n && f.k[j] === " ")
                        j++;
                    sal += "&nbsp;".repeat(j - i);
                    i = j;
                } else if (k === "m") {
                    let j = i + 1;
                    let s = f.c[i];
                    while (j < n && f.k[j] === "m")
                        s += f.c[j++];
                    sal += "<font color=\"" + marco + "\">" + s + "</font>";
                    i = j;
                } else {
                    const tono = esqueleto._tono(i, y + y0, t);
                    let j = i + 1;
                    while (j < n && f.k[j] === "b" && esqueleto._tono(j, y + y0, t) === tono)
                        j++;
                    sal += "<font color=\"" + tn[tono] + "\">" + "█".repeat(j - i) + "</font>";
                    i = j;
                }
            }
            if (y < filas.length - 1)
                sal += "<br>";
        }
        return sal;
    }

    function pintar(): void {
        esqueleto.cuadros++;
        const t = Reloj.t;
        cuerpoTexto.text = esqueleto._html(esqueleto.maqueta, 2, t);
        cabeceraTexto.text = esqueleto._html(esqueleto.cabeceraMaqueta, 0, t);
    }

    onColumnasChanged: esqueleto.rehacer()
    onFilasMaxChanged: esqueleto.rehacer()
    onVarianteChanged: esqueleto.rehacer()
    onCantidadChanged: esqueleto.rehacer()
    Component.onCompleted: esqueleto.rehacer()

    // Mientras se ve, pide el reloj; al esconderse, lo suelta.
    onVivoChanged: {
        if (esqueleto.vivo) {
            Reloj.pedir();
            esqueleto.pintar();
        } else {
            Reloj.soltar();
        }
    }
    Component.onDestruction: if (esqueleto.vivo)
        Reloj.soltar()

    Connections {
        target: Reloj
        enabled: esqueleto.vivo

        function onTicksChanged(): void {
            esqueleto.pintar();
        }
    }

    Item {
        id: cuerpo

        anchors.fill: parent
        anchors.margins: Theme.pad
        clip: true

        Text {
            id: cabeceraTexto

            objectName: "esqueletoCabecera"
            width: parent.width
            textFormat: Text.StyledText
            font.family: Theme.font
            font.pixelSize: 13
            lineHeight: 1
            wrapMode: Text.NoWrap
        }

        Text {
            id: cuerpoTexto

            objectName: esqueleto.variante === "tarjetas" ? "esqueletoTarjetas" : "esqueletoFilas"
            y: esqueleto.celdaAlto * 2
            width: parent.width
            textFormat: Text.StyledText
            font.family: Theme.font
            font.pixelSize: 13
            lineHeight: 1
            wrapMode: Text.NoWrap
        }
    }
}
