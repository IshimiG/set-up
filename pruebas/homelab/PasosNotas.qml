import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

// Los pasos de la prueba de Notas (fase 5), aparte de shell.qml, que sólo los
// mete en su lista: la página de nota con el Markdown de mentira de
// ApiFalsa.qml (notasFalsas), los enlaces [[…]] y los de la web, la pila de
// atrás y adelante, los euros tapados con el cajón a medio sacar (E11), los
// fallos y las «Notas recientes» de Inicio.
//
// Con PRUEBA_NOTA_REAL (una ruta del vault, como «30 Áreas/Servidor/
// 26-panel-escritorio.md»), además abre esa nota de verdad y la primera nota
// a la que enlaza, y deja sus capturas. Las lee de PRUEBA_VAULT (~/Notes si no
// se dice), sólo para leer y sólo de las carpetas que abre el NUC
// (ApiFalsa.notaPermitida): nada de fuera de ellas.
QtObject {
    id: pasosNotas

    // La ventana de shell.qml, con sus ayudas (comprobar, uno, clic…).
    required property var v
    required property var api
    // Donde caen el ratón, la rueda y el Escape que sube (envoltura).
    required property var zona
    // El shell falso: abierto y fijado.
    required property var shell

    property TestEvent ev: TestEvent {}

    property FileView lector: FileView {
        blockAllReads: true
        printErrors: false
    }

    readonly property string notaReal: Quickshell.env("PRUEBA_NOTA_REAL") || ""
    readonly property string vault: String(Quickshell.env("PRUEBA_VAULT") || (Quickshell.env("HOME") + "/Notes")).replace(/\/+$/, "")

    // Una nota del vault de verdad, sin el frontmatter (como el NUC), o null.
    function leerReal(ruta) {
        pasosNotas.lector.path = pasosNotas.vault + "/" + ruta;
        const t = pasosNotas.lector.text();
        if (!t)
            return null;
        const l = t.split("\n");
        let desde = 0;
        if (l[0].trim() === "---")
            for (let k = 1; k < l.length; k++)
                if (l[k].trim() === "---") {
                    desde = k + 1;
                    break;
                }
        return {
            titulo: ruta.split("/").pop().replace(/\.md$/i, ""),
            texto: l.slice(desde).join("\n")
        };
    }

    // --- Ayudas ----------------------------------------------------------------

    property real yAntes: 0
    property int hechasAntes: 0
    property int pedidasAntes: 0
    property int escapesAntes: 0

    readonly property string prueba: "30 Áreas/Servidor/Prueba.md"
    readonly property string otra: "30 Áreas/Servidor/Otra nota.md"

    function ui() {
        return pasosNotas.v.cualquiera("seccionNotas");
    }

    function lista() {
        return pasosNotas.v.uno("desplazableNotas");
    }

    function texto(nombre) {
        const t = pasosNotas.v.uno(nombre);
        return t ? t.text : "";
    }

    // Los NotaTexto visibles de la página.
    function trozos() {
        const l = [];
        pasosNotas.v.recorrer(pasosNotas.ui(), it => {
            if (it.visible && it.trozo !== undefined && it.ctrl !== undefined && typeof it.text === "string")
                l.push(it);
        });
        return l;
    }

    // El primer NotaTexto (esté a la vista o no) cuyo texto lleva «trozo».
    function conTexto(trozo) {
        let r = null;
        pasosNotas.v.recorrer(pasosNotas.ui(), it => {
            if (!r && it.trozo !== undefined && it.ctrl !== undefined && typeof it.text === "string" && it.text.indexOf(trozo) >= 0)
                r = it;
        });
        return r;
    }

    // Lleva la página hasta que el item se vea.
    function verEn(item) {
        const f = pasosNotas.lista();
        const y = item.mapToItem(f.contentItem, 0, 0).y;
        if (y < f.contentY + 8 || y + item.height > f.contentY + f.height - 8)
            f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - 100));
    }

    function clic(item) {
        pasosNotas.verEn(item);
        const p = item.mapToItem(pasosNotas.zona, item.width / 2, item.height / 2);
        pasosNotas.ev.mouseClick(pasosNotas.zona, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
    }

    // El href («n:3») del primer enlace de la página que cumple f, o "".
    function hrefDe(f) {
        const p = pasosNotas.ui().pagina;
        const i = p ? p.enlaces.findIndex(f) : -1;
        return i < 0 ? "" : "n:" + i;
    }

    // Un clic en un enlace de verdad: busca el texto que lo lleva, lo pone a
    // la vista y busca con linkAt dónde está.
    function clicEnlace(href) {
        const t = pasosNotas.conTexto('href="' + href + '"');
        if (!t)
            return false;
        pasosNotas.verEn(t);
        for (let y = 2; y < t.height; y += 3)
            for (let x = 2; x < t.width; x += 3)
                if (t.linkAt(x, y) === href) {
                    const p = t.mapToItem(pasosNotas.zona, x, y);
                    pasosNotas.ev.mouseClick(pasosNotas.zona, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
                    return true;
                }
        return false;
    }

    // Si la cabecera está arriba de lo que se ve (o la página no da para más).
    function cabeceraArriba(clave) {
        const c = pasosNotas.ui().buscarCabecera(pasosNotas.v.cualquiera("cuerpoNota"), clave);
        const f = pasosNotas.lista();
        if (!c)
            return false;
        const y = c.mapToItem(f.contentItem, 0, 0).y;
        return f.contentY > 0 && (Math.abs(y - f.contentY) < 30 || Math.abs(f.contentY - (f.contentHeight - f.height)) < 1);
    }

    function dondeCabecera(clave) {
        const c = pasosNotas.ui().buscarCabecera(pasosNotas.v.cualquiera("cuerpoNota"), clave);
        const f = pasosNotas.lista();
        return (c ? "cabecera en " + c.mapToItem(f.contentItem, 0, 0).y : "sin cabecera") + ", contentY " + f.contentY + ", máximo " + (f.contentHeight - f.height);
    }

    function ultimoEnlace() {
        const l = pasosNotas.v.enlaces;
        return l.length ? l[l.length - 1] : null;
    }

    // --- Los pasos ----------------------------------------------------------------

    readonly property var pasosReal: pasosNotas.notaReal === "" ? [] : [
        [200, () => {
            pasosNotas.api.lectorReal = pasosNotas.leerReal;
            pasosNotas.v.cualquiera("contenido").abrirNota(pasosNotas.notaReal, "");
        }],
        [1500, () => {
            const p = pasosNotas.ui().pagina;
            const aNotas = p ? p.enlaces.filter(e => e.tipo === "nota") : [];
            pasosNotas.v.comprobar(p !== null && p.bloques.length > 0 && pasosNotas.texto("errorNota") === "", "la nota de verdad (" + pasosNotas.notaReal + ") se abre y se pinta", p ? p.bloques.length + " bloques, " + p.enlaces.length + " enlaces (" + aNotas.length + " a notas)" : pasosNotas.texto("errorNota"));
            pasosNotas.v.comprobar(pasosNotas.trozos().every(t => !/<(img|script|style|iframe|table|div|span)\b/i.test(t.text) && !/<a href="(?!n:\d+")/.test(t.text)), "  sin ninguna etiqueta suya ni ningún href que no sea de la página");
            pasosNotas.v.captura("notas-real-1");
            // La primera tabla sola (grabToImage de la ventana entera no pinta
            // bien una lista desplazada).
            const tabla = pasosNotas.v.uno("tablaNota");
            if (tabla)
                tabla.grabToImage(r => r.saveToFile(pasosNotas.v.dir + "notas-real-tabla.png"));
        }],
        [300, () => {
            const p = pasosNotas.ui().pagina;
            const otra = p ? p.enlaces.find(e => e.tipo === "nota" && e.ruta !== pasosNotas.notaReal) : null;
            if (otra)
                pasosNotas.clicEnlace(pasosNotas.hrefDe(e => e === otra));
        }],
        [1500, () => {
            const n = pasosNotas.ui().nota;
            pasosNotas.v.comprobar(pasosNotas.texto("errorNota") === "" && n !== null && pasosNotas.ui().posicion >= 1, "  y su primer [[enlace]] a otra nota, también", n ? n.ruta : pasosNotas.texto("errorNota"));
            pasosNotas.v.captura("notas-real-2");
            pasosNotas.api.lectorReal = null;
        }]
    ]

    readonly property var pasos: [
        [300, () => pasosNotas.v.seccion("notas")],
        [500, () => {
            pasosNotas.v.comprobar(pasosNotas.v.uno("seccionNotas") !== null && pasosNotas.v.uno("indiceNotas") !== null && pasosNotas.v.porNombre("notaReciente").length === 2, "Notas, sin nada abierto, enseña las notas recientes");
            pasosNotas.v.comprobar(pasosNotas.v.uno("notaAtras") === null && pasosNotas.v.uno("cuerpoNota") === null, "  sin atrás ni adelante, y sin página");
            pasosNotas.v.comprobar(pasosNotas.v.uno("abrirInicioNota") !== null, "  y con un botón para 00 Inicio");
            pasosNotas.v.comprobar(pasosNotas.v.porNombre("tituloReciente").every(t => t.textFormat === Text.PlainText), "  los títulos (de las notas) van en texto plano, nunca como HTML");
            pasosNotas.v.captura("notas-1-indice");
        }],
        // (Las capturas se hacen en el siguiente fotograma: lo que cambia la
        // vista va en el paso de después.)
        [300, () => {
            pasosNotas.api.retenerNotas = true;
            pasosNotas.clic(pasosNotas.v.porNombre("notaReciente")[0]);
        }],
        [300, () => {
            pasosNotas.v.comprobar(pasosNotas.api.notasPedidas[pasosNotas.api.notasPedidas.length - 1] === pasosNotas.prueba && pasosNotas.v.uno("notaCargando") !== null, "un clic en una reciente la pide al NUC y dice que la está abriendo", JSON.stringify(pasosNotas.api.notasPedidas));
            pasosNotas.v.comprobar(pasosNotas.texto("tituloNota") === "Prueba" && pasosNotas.texto("carpetaNota") === "30 Áreas/Servidor", "  con su nombre y su carpeta mientras tanto");
            pasosNotas.api.retenerNotas = false;
            pasosNotas.api.soltarNotas();
        }],
        [600, () => {
            const v = pasosNotas.v;
            const t = pasosNotas.trozos().map(x => x.text);
            const todo = t.join("\n");
            v.comprobar(v.uno("notaCargando") === null && v.uno("cuerpoNota") !== null && pasosNotas.texto("modificadaNota") === "Modificada hace 2 h", "llega la nota y se pinta, con cuándo se cambió");
            v.comprobar(v.uno("tituloNota").textFormat === Text.PlainText && v.uno("carpetaNota").textFormat === Text.PlainText, "  el título y la carpeta, en texto plano");
            v.comprobar(v.porNombre("cabeceraNota").map(c => c.clave).join("|") === "una nota de prueba|listas|tabla|relleno", "  las cabeceras", v.porNombre("cabeceraNota").map(c => c.clave).join("|"));
            v.comprobar(todo.indexOf("<b>negrita</b>") >= 0 && todo.indexOf("<i>cursiva</i>") >= 0 && todo.indexOf("<s>tachado</s>") >= 0 && /<font color="[^"]+">código &lt;b&gt;<\/font>/.test(todo), "  la negrita, la cursiva, el tachado y el código");
            v.comprobar(todo.indexOf("&lt;b&gt;no es html&lt;/b&gt; &lt;img src=") >= 0 && todo.indexOf("&amp;amp;") >= 0 && t.every(x => !/<(img|script)\b/i.test(x) && !/<a href="(?!n:\d+")/.test(x)), "  el HTML de la nota sale como texto, sin interpretar (ni imágenes, ni enlaces suyos)");
            const c = v.uno("codigoNota");
            let codigo = "";
            v.recorrer(c, it => {
                if (typeof it.text === "string" && it.text !== "")
                    codigo = it.text;
            });
            v.comprobar(codigo === 'echo "<script>alert(1)</script>"', "  el código, tal cual y en texto plano", codigo);
            v.comprobar(!v.tiene("un comentario que no sale"), "  los comentarios %% %% no salen");
            v.comprobar(v.porNombre("elementoNota").length === 8 && v.porNombre("casillaNota").length === 2, "  las listas (también las anidadas y las del aviso) y las casillas de las tareas", String(v.porNombre("elementoNota").length));
            const lineas = v.textos().split("\n");
            v.comprobar(lineas.indexOf("1.") >= 0 && lineas.indexOf("2.") >= 0, "  las numeradas, con su número");
            v.comprobar(v.porNombre("cabezaTablaNota").length === 3 && v.porNombre("celdaNota").length === 6, "  la tabla, con la barra del [[enlace|alias]] dentro de una celda", v.porNombre("cabezaTablaNota").length + " + " + v.porNombre("celdaNota").length);
            v.comprobar(v.porNombre("citaNota").length === 1 && pasosNotas.texto("tituloAvisoNota") === "Cuidado", "  la cita y el aviso de Obsidian");
            const p = pasosNotas.ui().pagina;
            const en = p.enlaces;
            // Las direcciones del HTML que sale como texto también son enlaces a la
            // web, como cualquier dirección suelta: sólo se abren con un clic.
            v.comprobar(en.length === 8 && en.filter(e => e.tipo === "web").map(e => e.url).join(" ") === "https://example.org/web https://example.org/suelta http://127.0.0.1:9/x.png https://example.org/mal", "los enlaces: a la web (también las direcciones sueltas, sin su punto) y a notas", JSON.stringify(en));
            const sinEnlaces = todo.replace(/<a href="n:\d+">[^<]*<\/a>/g, "");
            v.comprobar(en.every(e => e.tipo === "web" || e.ruta.indexOf("MentalHealth") < 0) && sinEnlaces.indexOf("Sin carpeta, Diario, escapada y ") >= 0, "  los [[…]] sin carpeta o de fuera de las permitidas (también con «..») se quedan en su texto");
            v.comprobar(en.some(e => e.tipo === "nota" && e.ruta === pasosNotas.prueba && e.cabecera === "Tabla") && en.some(e => e.tipo === "nota" && e.ruta === pasosNotas.otra && e.cabecera === "Segunda parte"), "  [[#Cabecera]] es esta misma nota, y [[nota#Cabecera]] lleva la cabecera");
            v.comprobar(v.tiene("1.234,56 € y 300€"), "con el cajón desplegado, los euros se ven");
            v.captura("notas-2-pagina");
        }],
        [300, () => pasosNotas.shell.abierto = false],
        [100, () => {
            const e = pasosNotas.conTexto("Gasto del mes");
            pasosNotas.v.comprobar(e !== null && e.text === "Gasto del mes: ••• € y ••• €." && pasosNotas.conTexto("12 €") === null && pasosNotas.conTexto("1.234") === null, "con el cajón a medio sacar, los euros de la nota se tapan (E11)", e ? e.text : "");
            pasosNotas.shell.abierto = true;
        }],
        [900, () => {
            pasosNotas.v.comprobar(pasosNotas.conTexto("1.234,56 €") !== null, "  y al desplegarlo, otra vez se ven");
            pasosNotas.hechasAntes = pasosNotas.ui().paginasHechas;
            pasosNotas.api.notasPermitidas = pasosNotas.api.notasPermitidas.slice();
        }],
        [200, () => {
            pasosNotas.v.comprobar(pasosNotas.ui().paginasHechas === pasosNotas.hechasAntes, "las mismas carpetas otra vez (con cada Inicio) no rehacen la página");
            const tabla = pasosNotas.v.uno("tablaNota");
            const celdas = pasosNotas.v.porNombre("celdaNota");
            const larga = celdas.find(c => c.modelData.t.html.indexOf("Fila dos") >= 0);
            const corta = celdas.find(c => c.modelData.t.html.indexOf("Fila uno") >= 0);
            pasosNotas.v.comprobar(larga && corta && larga.height > corta.height * 1.8 && tabla.width <= pasosNotas.lista().width + 1, "  una celda larga se parte en varias líneas, y la tabla cabe", larga && corta ? larga.height + " / " + corta.height : "");
            pasosNotas.verEn(tabla);
            pasosNotas.yAntes = pasosNotas.lista().contentY;
            const p = tabla.mapToItem(pasosNotas.zona, tabla.width / 2, tabla.height / 2);
            pasosNotas.ev.mouseWheel(pasosNotas.zona, p.x, p.y, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
        }],
        [400, () => {
            pasosNotas.v.comprobar(pasosNotas.lista().contentY > pasosNotas.yAntes, "la rueda encima de la tabla mueve la página", pasosNotas.yAntes + " → " + pasosNotas.lista().contentY);
            pasosNotas.lista().contentY = 0;
            pasosNotas.pedidasAntes = pasosNotas.api.notasPedidas.length;
            pasosNotas.v.comprobar(pasosNotas.clicEnlace(pasosNotas.hrefDe(e => e.cabecera === "Tabla")), "(clic en [[#Tabla]])");
        }],
        [500, () => {
            const n = pasosNotas.ui();
            pasosNotas.v.comprobar(pasosNotas.api.notasPedidas.length === pasosNotas.pedidasAntes && n.historial.length === 2 && n.posicion === 1, "[[#Cabecera]] no vuelve a pedir la nota, y entra en la pila", JSON.stringify(n.historial));
            pasosNotas.v.comprobar(pasosNotas.cabeceraArriba("tabla"), "  y lleva la página a esa cabecera", pasosNotas.dondeCabecera("tabla"));
            // La lista sola: con toda la ventana, grabToImage pinta mal una lista
            // desplazada dentro de otra cosa recortada (lo que se mide está bien).
            pasosNotas.lista().grabToImage(r => r.saveToFile(pasosNotas.v.dir + "notas-3-cabecera.png"));
            pasosNotas.clic(pasosNotas.v.uno("notaAtras"));
        }],
        [400, () => {
            pasosNotas.v.comprobar(pasosNotas.ui().posicion === 0 && pasosNotas.lista().contentY < 1 && pasosNotas.v.uno("notaAdelante").encendido, "«atrás» vuelve a donde se estaba, y se puede ir adelante", String(pasosNotas.lista().contentY));
            pasosNotas.v.comprobar(pasosNotas.clicEnlace(pasosNotas.hrefDe(e => e.ruta === pasosNotas.otra && e.cabecera === "")), "(clic en [[…|la otra nota]])");
        }],
        [500, () => {
            const n = pasosNotas.ui();
            pasosNotas.v.comprobar(pasosNotas.api.notasPedidas[pasosNotas.api.notasPedidas.length - 1] === pasosNotas.otra && pasosNotas.texto("tituloNota") === "Otra nota" && pasosNotas.lista().contentY < 1, "un [[enlace]] abre la otra nota, arriba del todo");
            pasosNotas.v.comprobar(n.historial.length === 2 && n.posicion === 1 && !pasosNotas.v.uno("notaAdelante").encendido, "  y lo que había delante en la pila se pierde, como en un navegador", JSON.stringify(n.historial.map(e => e.ruta + "#" + e.cabecera)));
            pasosNotas.v.captura("notas-4-otra");
        }],
        [300, () => pasosNotas.v.tecla(Qt.Key_Left, Qt.AltModifier)],
        [500, () => {
            pasosNotas.v.comprobar(pasosNotas.texto("tituloNota") === "Prueba" && pasosNotas.ui().posicion === 0, "Alt+← vuelve atrás");
            pasosNotas.lista().contentY = 0;
            pasosNotas.v.comprobar(pasosNotas.clicEnlace(pasosNotas.hrefDe(e => e.cabecera === "Segunda parte")), "(clic en [[…#Segunda parte]])");
        }],
        [600, () => {
            pasosNotas.v.comprobar(pasosNotas.texto("tituloNota") === "Otra nota" && pasosNotas.cabeceraArriba("segunda parte"), "[[nota#Cabecera]] abre la otra nota en esa cabecera", String(pasosNotas.lista().contentY));
            pasosNotas.yAntes = pasosNotas.lista().contentY;
            pasosNotas.escapesAntes = pasosNotas.zona.escapes;
            pasosNotas.v.tecla(Qt.Key_Escape);
        }],
        [500, () => {
            pasosNotas.v.comprobar(pasosNotas.texto("tituloNota") === "Prueba" && pasosNotas.shell.abierto && pasosNotas.zona.escapes === pasosNotas.escapesAntes, "Escape, con algo detrás en la pila, vuelve atrás (y no cierra el cajón)");
            pasosNotas.v.tecla(Qt.Key_Right, Qt.AltModifier);
        }],
        [600, () => {
            pasosNotas.v.comprobar(pasosNotas.texto("tituloNota") === "Otra nota" && Math.abs(pasosNotas.lista().contentY - pasosNotas.yAntes) < 1, "Alt+→ va adelante, a donde se estaba", pasosNotas.yAntes + " / " + pasosNotas.lista().contentY);
            pasosNotas.v.tecla(Qt.Key_Left, Qt.AltModifier);
        }],
        [500, () => {
            pasosNotas.shell.fijado = true;
            pasosNotas.lista().contentY = 0;
            pasosNotas.v.comprobar(pasosNotas.clicEnlace(pasosNotas.hrefDe(e => e.url === "https://example.org/web")), "(clic en [la web](https://…))");
        }],
        [300, () => {
            pasosNotas.v.comprobar(pasosNotas.v.igual(pasosNotas.ultimoEnlace(), ["xdg-open", "https://example.org/web"]), "un enlace a la web se abre en el navegador", JSON.stringify(pasosNotas.ultimoEnlace()));
            pasosNotas.clic(pasosNotas.v.uno("notaWeb"));
        }],
        [300, () => {
            pasosNotas.v.comprobar(pasosNotas.v.igual(pasosNotas.ultimoEnlace(), ["xdg-open", pasosNotas.api.baseUrl + "/#/nota/30%20%C3%81reas%2FServidor%2FPrueba.md"]), "«En la web» abre la misma nota en la web", JSON.stringify(pasosNotas.ultimoEnlace()));
            pasosNotas.shell.fijado = false;
            pasosNotas.v.cualquiera("contenido").abrirNota("30 Áreas/No existe.md", "");
        }],
        [400, () => {
            pasosNotas.v.comprobar(pasosNotas.texto("errorNota") === "No se puede abrir la nota: no encuentro esa nota" && pasosNotas.v.uno("reintentarNota") !== null && pasosNotas.v.uno("cuerpoNota") === null, "una nota que no está lo dice, con «Reintentar»", pasosNotas.texto("errorNota"));
            pasosNotas.pedidasAntes = pasosNotas.api.notasPedidas.length;
            pasosNotas.clic(pasosNotas.v.uno("reintentarNota"));
        }],
        [400, () => {
            pasosNotas.v.comprobar(pasosNotas.api.notasPedidas.length === pasosNotas.pedidasAntes + 1, "  y «Reintentar» la vuelve a pedir");
            pasosNotas.v.cualquiera("contenido").abrirNota("MentalHealth/Diario.md", "");
        }],
        [400, () => {
            pasosNotas.v.comprobar(pasosNotas.texto("errorNota").indexOf("no está en las carpetas que muestra el panel") >= 0 && pasosNotas.v.uno("cuerpoNota") === null, "una de fuera de las carpetas, lo que dice el NUC", pasosNotas.texto("errorNota"));
            pasosNotas.v.captura("notas-5-error");
        }],
        [300, () => pasosNotas.v.seccion("inicio")],
        [500, () => {
            const r = pasosNotas.v.uno("recientesInicio");
            pasosNotas.v.comprobar(r !== null && pasosNotas.v.porNombre("notaReciente").length === 2, "en Inicio, las notas recientes, al final");
            pasosNotas.v.clic(pasosNotas.v.porNombre("notaReciente")[1]);
        }],
        [600, () => {
            const n = pasosNotas.ui();
            pasosNotas.v.comprobar(pasosNotas.v.uno("seccionNotas") !== null && pasosNotas.texto("tituloNota") === "Otra nota" && n.historial[n.posicion].ruta === pasosNotas.otra, "  y un clic la abre en Notas", JSON.stringify(n.historial.map(e => e.ruta)));
            pasosNotas.v.captura("notas-6-desde-inicio");
        }]
    ].concat(pasosNotas.pasosReal, [[300, () => pasosNotas.v.seccion("inicio")]])
}
