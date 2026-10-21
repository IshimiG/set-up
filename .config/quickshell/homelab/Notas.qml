import QtQuick
import QtQuick.Layouts
import "shared"
import "MarkdownLogica.js" as Logica

// Las notas del vault como página, en el cajón: lo mismo que la página de
// nota de la web (#/nota/<ruta>), sólo para leer. El Markdown lo pinta un
// renderizador propio (MarkdownLogica.js y NotaBloques.qml): cabeceras,
// párrafos, listas (con las casillas de las tareas, que aquí sólo se miran),
// tablas, código, citas, avisos de Obsidian, énfasis y enlaces.
//
// Los enlaces [[…]] se abren aquí mismo, si son de las carpetas que el NUC
// enseña (api.notasPermitidas, como en la web: con la ruta entera); los demás
// se quedan en su texto. [[nota#Cabecera]] lleva a esa cabecera. Los enlaces
// http(s) van al navegador. Cada nota abierta entra en una pila: atrás y
// adelante (los botones, Alt+←/→, los botones de atrás y adelante del ratón;
// Escape y Retroceso, atrás), y cada una recuerda por dónde se iba.
//
// Sin nota abierta, el índice: las notas recientes. También se llega desde el
// Inicio (sus «Notas recientes») con abrir().
FocusScope {
    id: notas

    required property var shell
    readonly property var api: notas.shell.api

    property string lineaConexion: ""
    // El cajón entero fuera y quieto (Contenido.desplegado): si no, los euros de
    // la nota se tapan (E11).
    property bool desplegado: false

    signal abrirEnlace(string url)

    // La pila: [{ ruta, cabecera, y }], y dónde se está en ella (-1: el índice).
    // y es por dónde se iba al dejarla (-1 mientras no se ha dejado: entonces
    // se va a la cabecera, o arriba).
    property var historial: []
    property int posicion: -1
    readonly property var actual: notas.posicion >= 0 && notas.posicion < notas.historial.length ? notas.historial[notas.posicion] : null
    readonly property bool puedeAtras: notas.posicion >= 0
    readonly property bool puedeAdelante: notas.posicion < notas.historial.length - 1

    // Las notas ya leídas ({ ruta: nota }): atrás y adelante las enseñan al
    // momento, y la copia nueva llega detrás.
    property var leidas: ({})
    readonly property int maxLeidas: 30
    // La nota de la página ({ ruta, titulo, modificada, texto }), o null.
    property var nota: null
    property bool cargando: false
    property string error: ""
    property int secuencia: 0

    // Lo que se pinta. Son textos para que la misma copia (o la misma lista de
    // carpetas, que llega otra vez con cada Inicio) no rehaga la página.
    property string textoPagina: ""
    property string rutaPagina: ""
    readonly property string clavePermitidas: notas.api && notas.api.notasPermitidas ? notas.api.notasPermitidas.join("\n") : ""
    readonly property var pagina: notas.rutaPagina === "" ? null : Logica.pagina(notas.textoPagina, notas.rutaPagina, notas.clavePermitidas === "" ? [] : notas.clavePermitidas.split("\n"), {
        codigo: String(Theme.strong)
    })
    // Las veces que se ha hecho la página (para la prueba).
    property int paginasHechas: 0
    onPaginaChanged: notas.paginasHechas++

    // --- Ir y volver -----------------------------------------------------------

    // Abre una nota (con una cabecera, si viene) y la pone encima de la pila;
    // lo de delante se pierde, como en un navegador. Una cabecera de la misma
    // nota sólo mueve la página.
    function abrir(ruta, cabecera) {
        if (!ruta)
            return;
        notas.guardarY();
        const h = notas.historial.slice(0, notas.posicion + 1);
        h.push({
            ruta: String(ruta),
            cabecera: String(cabecera || ""),
            y: -1
        });
        notas.historial = h;
        const misma = notas.nota !== null && notas.nota.ruta === String(ruta);
        notas.posicion = h.length - 1;
        if (notas.visible)
            sumidero.forceActiveFocus();
        if (misma && notas.error === "") {
            notas.colocar();
            return;
        }
        notas.entrar();
    }

    function atras() {
        if (!notas.puedeAtras)
            return;
        notas.irA(notas.posicion - 1);
    }

    function adelante() {
        if (!notas.puedeAdelante)
            return;
        notas.irA(notas.posicion + 1);
    }

    function indice() {
        notas.irA(-1);
    }

    function irA(n) {
        notas.guardarY();
        const antes = notas.actual;
        notas.posicion = n;
        const ahora = notas.actual;
        if (ahora && antes && antes.ruta === ahora.ruta && notas.nota !== null && notas.error === "")
            notas.colocar();
        else
            notas.entrar();
        sumidero.forceActiveFocus();
    }

    // Por dónde se iba, en la entrada de la pila que se deja.
    function guardarY() {
        const e = notas.actual;
        if (!e)
            return;
        const h = notas.historial.slice();
        h[notas.posicion] = Object.assign({}, e, {
            y: desplazable.contentY
        });
        notas.historial = h;
    }

    // La entrada de ahora: lo que ya se tenga, al momento, y la nota fresca del
    // NUC detrás.
    function entrar() {
        const e = notas.actual;
        const sec = ++notas.secuencia;
        notas.error = "";
        if (!e) {
            notas.cargando = false;
            desplazable.contentY = 0;
            return;
        }
        const ya = notas.leidas[e.ruta] || null;
        notas.ponerNota(ya);
        if (ya)
            notas.colocar();
        else
            desplazable.contentY = 0;
        if (!notas.api) {
            notas.error = "Sin conexión con el NUC";
            return;
        }
        notas.cargando = true;
        notas.api.leerNota(e.ruta, (nota, error) => {
            if (sec !== notas.secuencia)
                return;
            notas.cargando = false;
            if (!nota) {
                notas.error = error;
                return;
            }
            const l = Object.keys(notas.leidas).length >= notas.maxLeidas ? {} : Object.assign({}, notas.leidas);
            l[e.ruta] = nota;
            notas.leidas = l;
            const nueva = notas.nota === null;
            notas.ponerNota(nota);
            if (nueva)
                notas.colocar();
        });
    }

    function ponerNota(n) {
        notas.nota = n;
        notas.textoPagina = n ? n.texto : "";
        notas.rutaPagina = n ? n.ruta : "";
    }

    function recargar() {
        notas.entrar();
    }

    // Un enlace de la página (el href de NotaTexto).
    function enlace(href) {
        const e = Logica.enlace(notas.pagina, href);
        if (!e)
            return;
        if (e.tipo === "web")
            notas.abrirEnlace(e.url);
        else
            notas.abrir(e.ruta, e.cabecera);
    }

    // La dirección de la nota en la web, para «En la web».
    function rutaWeb() {
        const e = notas.actual;
        if (!e)
            return "#/";
        return "#/nota/" + encodeURIComponent(e.ruta) + (e.cabecera ? "?h=" + encodeURIComponent(e.cabecera) : "");
    }

    // --- Dónde se pone la página ---------------------------------------------------

    // Por donde se iba en esa entrada o, la primera vez, a la cabecera que pide
    // (o arriba). La página tarda un poco en colocarse (los textos se miden
    // después), así que se reintenta.
    function colocar() {
        llevar.intentos = 0;
        llevar.restart();
    }

    function buscarCabecera(item, clave) {
        if (item.objectName === "cabeceraNota" && item.clave === clave)
            return item;
        for (let k = 0; k < item.children.length; k++) {
            const r = notas.buscarCabecera(item.children[k], clave);
            if (r)
                return r;
        }
        return null;
    }

    function maxY() {
        return Math.max(0, desplazable.contentHeight - desplazable.height);
    }

    Timer {
        id: llevar

        property int intentos: 0

        interval: 40
        onTriggered: {
            const e = notas.actual;
            if (!e || !notas.pagina)
                return;
            if (e.y >= 0 || !e.cabecera) {
                const y = Math.max(0, e.y);
                if (y <= notas.maxY() || llevar.intentos >= 10) {
                    desplazable.contentY = Math.min(y, notas.maxY());
                    return;
                }
            } else {
                const c = notas.buscarCabecera(cuerpo, Logica.normal(e.cabecera));
                if (c && c.height > 0) {
                    desplazable.contentY = Math.min(notas.maxY(), c.mapToItem(columna, 0, 0).y);
                    return;
                }
            }
            if (++llevar.intentos < 25)
                llevar.restart();
        }
    }

    // --- Teclado y ratón ---------------------------------------------------------

    onVisibleChanged: if (notas.visible)
        Qt.callLater(() => sumidero.forceActiveFocus())

    Keys.onPressed: event => {
        if (!notas.shell.abierto)
            return;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        if ((alt && event.key === Qt.Key_Left) || ((event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) && notas.puedeAtras)) {
            notas.atras();
            event.accepted = true;
        } else if (alt && event.key === Qt.Key_Right) {
            notas.adelante();
            event.accepted = true;
        }
    }

    Item {
        id: sumidero
        focus: true
    }

    TapHandler {
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onTapped: (punto, boton) => {
            if (boton === Qt.BackButton)
                notas.atras();
            else
                notas.adelante();
        }
    }

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            visible: notas.lineaConexion !== ""
            spacing: 8

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.muted
            }

            Text {
                objectName: "lineaConexionNotas"
                Layout.fillWidth: true
                text: notas.lineaConexion
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        // Atrás, adelante, el índice y la nota en la web.
        RowLayout {
            Layout.fillWidth: true
            visible: notas.posicion >= 0 || notas.historial.length > 0
            spacing: 6

            Chip {
                objectName: "notaAtras"
                glifo: ""
                implicitWidth: 28
                encendido: notas.puedeAtras
                onActivado: notas.atras()
            }

            Chip {
                objectName: "notaAdelante"
                glifo: ""
                implicitWidth: 28
                encendido: notas.puedeAdelante
                onActivado: notas.adelante()
            }

            Chip {
                objectName: "notaIndice"
                texto: "Recientes"
                glifo: ""
                activo: notas.posicion < 0
                onActivado: notas.indice()
            }

            Item {
                Layout.fillWidth: true
            }

            Chip {
                objectName: "notaWeb"
                visible: notas.actual !== null
                texto: "En la web"
                glifo: ""
                onActivado: notas.abrirEnlace(notas.api.urlWeb(notas.rutaWeb()))
            }
        }

        Flickable {
            id: desplazable

            objectName: "desplazableNotas"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 12
                opacity: notas.lineaConexion === "" ? 1 : 0.5

                // --- El índice ---
                NotasRecientes {
                    objectName: "indiceNotas"
                    Layout.fillWidth: true
                    visible: notas.actual === null
                    lista: notas.api ? notas.api.notasRecientes : null
                    onAbrir: ruta => notas.abrir(ruta, "")
                }

                // La nota de siempre, a mano.
                Chip {
                    objectName: "abrirInicioNota"
                    visible: notas.actual === null && notas.clavePermitidas.split("\n").indexOf("00 Inicio.md") >= 0
                    texto: "00 Inicio"
                    glifo: ""
                    onActivado: notas.abrir("00 Inicio.md", "")
                }

                Text {
                    Layout.fillWidth: true
                    visible: notas.actual === null
                    text: "Los enlaces [[…]] de las notas se abren aquí; los de la web, en el navegador."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                // --- La página ---
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: notas.actual !== null
                    spacing: 4

                    Etiqueta {
                        objectName: "carpetaNota"
                        Layout.fillWidth: true
                        text: (notas.nota ? Logica.carpeta(notas.nota.ruta) : (notas.actual ? Logica.carpeta(notas.actual.ruta) : "")) || "Vault"
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                    }

                    Text {
                        objectName: "tituloNota"
                        Layout.fillWidth: true
                        text: {
                            if (notas.nota)
                                return notas.desplegado ? notas.nota.titulo : Logica.taparEuros(notas.nota.titulo);
                            return notas.actual ? notas.actual.ruta.split("/").pop().replace(/\.md$/i, "") : "";
                        }
                        // El título sale de la nota (su «nombre»): texto plano.
                        textFormat: Text.PlainText
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 17
                        wrapMode: Text.Wrap
                    }

                    Text {
                        objectName: "modificadaNota"
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: notas.nota && notas.nota.modificada ? "Modificada " + Logica.hace(notas.nota.modificada) : ""
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                Text {
                    objectName: "notaCargando"
                    Layout.fillWidth: true
                    visible: notas.actual !== null && notas.cargando && notas.nota === null
                    text: "Abriendo la nota…"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                // El fallo (la nota no se puede abrir, no contesta el NUC…), con
                // «Reintentar». Si ya se tenía una copia, se sigue viendo debajo.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: notas.actual !== null && notas.error !== ""
                    spacing: 6

                    Text {
                        objectName: "errorNota"
                        Layout.fillWidth: true
                        text: notas.error
                        textFormat: Text.PlainText
                        color: Theme.warn
                        font.family: Theme.font
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    Chip {
                        objectName: "reintentarNota"
                        texto: "Reintentar"
                        glifo: ""
                        encendido: !notas.cargando
                        onActivado: notas.recargar()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: notas.actual !== null && notas.pagina !== null
                    implicitHeight: 1
                    color: Theme.rule
                }

                NotaBloques {
                    id: cuerpo

                    objectName: "cuerpoNota"
                    Layout.fillWidth: true
                    visible: notas.actual !== null && notas.pagina !== null
                    bloques: notas.pagina ? notas.pagina.bloques : []
                    ctrl: notas
                }

                Text {
                    Layout.fillWidth: true
                    visible: notas.actual !== null && notas.pagina !== null && notas.pagina.bloques.length === 0
                    text: "La nota está vacía."
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
