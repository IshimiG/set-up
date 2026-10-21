.pragma library

// Las reglas de enseñar una nota del vault como página en el cajón, sin nada
// de interfaz: el Markdown de la nota partido en bloques (cabeceras, párrafos,
// listas, tablas, código, citas, avisos de Obsidian y rayas) y, dentro de cada
// bloque, el texto en línea ya convertido en StyledText de Qt. Es lo mismo que
// la página de nota de la web (notaCuerpo, notaLista y notaCeldas de
// panel/internal/panel/web/nota.js, y md() y notaRuta de home.js y nota.js,
// repo homelab), con las mismas reglas para los enlaces [[…]].
//
// La nota es un dato que no es de fiar: de su HTML no se interpreta nada. Todo
// su texto se escapa (&, < y >) antes de ponerle marcas, y las únicas etiquetas
// que salen son las de aquí: <b>, <i>, <s>, <br>, <font color> y <a href="n:3">.
// El href es sólo el número del enlace en la lista de enlaces de la página: ni
// una dirección ni nada de la nota va dentro de un atributo. Por eso no se usa
// Text.MarkdownText: el importador de Markdown de Qt mete el HTML de la nota
// tal cual (un <img> cargaría una dirección de fuera), no sabe de [[…]] y no
// deja dar estilo a las tablas.

// --- Los bloques (los de la web) ------------------------------------------------

var LISTA = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/;
var CABECERA = /^(#{1,6})\s+(.*)$/;
var CITA = /^\s*>/;
var TABLA_SEP = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;
var RAYA = /^\s*([-*_])(\s*\1){2,}\s*$/;
var VALLA = /^\s*(```|~~~)/;
// [!tipo] título, la primera línea de un aviso de Obsidian.
var AVISO = /^\[!([\w-]+)\][+-]?\s*(.*)$/;

// Más hondo que esto (citas dentro de listas dentro de citas…), lo que quede
// va como un párrafo: una nota rara no puede crear árboles sin fondo.
var MAX_PROFUNDIDAD = 8;

// --- El texto en línea (md() de la web) --------------------------------------------

// [[destino|alias]], [texto](https://…), `código`, **negrita**, ~~tachado~~,
// *cursiva* y, además de la web, las direcciones sueltas (https://…). Es una
// función para que cada vuelta tenga su propio lastIndex: el motor de QML
// estropea las barras de un RegExp hecho con otro .source.
function enLineaRe() {
    return /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]|\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|`([^`]+)`|\*\*(.+?)\*\*|~~(.+?)~~|\*([^\s*](?:[^*]*[^\s*])?)\*|(https?:\/\/[^\s<>"'`\]]+)/g;
}

// Las cantidades en euros: «1.234,56 €», «300€», «15k€», «€ 12», «40 EUR»,
// «12 euros». Con el cajón a medio sacar se tapan (decisión E11).
var EUROS = /\d(?:[\d.,]*\d)?\s?[kKmM]?\s?(?:€|eur(?:os?)?\b)|€\s?\d(?:[\d.,]*\d)?/gi;
var EUROS_TAPADOS = "••• €";

function escapar(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// El texto de una cabecera, como lo compara la web (notaNorm): sin espacios de
// más y en minúsculas.
function normal(s) {
    return String(s).replace(/\s+/g, " ").trim().toLowerCase();
}

function conEuros(s) {
    EUROS.lastIndex = 0;
    return EUROS.test(String(s));
}

function taparEuros(s) {
    return String(s).replace(EUROS, EUROS_TAPADOS);
}

// La ruta del vault que nombra un [[destino]] si el panel puede abrirla, o
// null (notaRuta de la web): la parte de antes de «#», con «.md» si no lo
// lleva, y dentro de una de las carpetas permitidas (personal.allowed). Como
// el NUC, nada con «..», «.» o una parte oculta: así ni se pide.
function rutaNota(destino, permitidas) {
    var ruta = String(destino).split("#")[0].trim();
    if (!ruta)
        return null;
    if (!/\.md$/i.test(ruta))
        ruta += ".md";
    var partes = ruta.split("/");
    for (var k = 0; k < partes.length; k++)
        if (partes[k] === "" || partes[k].charAt(0) === ".")
            return null;
    var ok = (permitidas || []).some(function (e) {
        return ruta === e || ruta.indexOf(e + "/") === 0;
    });
    return ok ? ruta : null;
}

// La carpeta de una ruta («30 Áreas/Servidor»), o "" en la raíz.
function carpeta(ruta) {
    var i = String(ruta).lastIndexOf("/");
    return i < 0 ? "" : String(ruta).slice(0, i);
}

// El destino de un [[…]] como enlace de la página, o null si no se puede abrir:
// { tipo: "nota", ruta, cabecera }. [[#Cabecera]] es la misma nota.
function enlaceNota(destino, ctx) {
    var partes = String(destino).split("#");
    var cabecera = partes.length > 1 ? partes.slice(1).join("#").trim() : "";
    if (partes[0].trim() === "")
        return cabecera && ctx.ruta ? {
            tipo: "nota",
            ruta: ctx.ruta,
            cabecera: cabecera
        } : null;
    var ruta = rutaNota(destino, ctx.permitidas);
    return ruta ? {
        tipo: "nota",
        ruta: ruta,
        cabecera: cabecera
    } : null;
}

// El texto que enseña un [[destino|alias]]: el alias o, si no, el nombre de la
// nota (o la cabecera, en [[#Cabecera]]).
function etiquetaNota(destino, alias) {
    if (alias && alias.trim())
        return alias.trim();
    var partes = String(destino).split("#");
    var nombre = partes[0].split("/").pop().trim();
    return nombre || partes.slice(1).join("#").trim();
}

function ponerEnlace(ctx, e, etiqueta) {
    ctx.enlaces.push(e);
    return '<a href="n:' + (ctx.enlaces.length - 1) + '">' + etiqueta + "</a>";
}

// Una línea de Markdown en línea, como StyledText. Con enlaces false (el texto
// de un enlace), los de dentro se quedan en su texto. Los enlaces se apuntan
// en ctx.enlaces.
function enLinea(texto, ctx, prof, enlaces) {
    texto = String(texto === undefined || texto === null ? "" : texto);
    prof = prof || 0;
    if (enlaces === undefined)
        enlaces = true;
    if (prof > 4)
        return escapar(texto);
    var re = enLineaRe();
    var out = "";
    var ultimo = 0;
    var m;
    while ((m = re.exec(texto)) !== null) {
        var fin = m.index + m[0].length;
        if (m[9] !== undefined) {
            // Una dirección suelta, sin el punto o la coma que la cierran.
            var url = m[9].replace(/[.,;:!?)]+$/, "");
            fin = m.index + url.length;
            re.lastIndex = fin;
            out += escapar(texto.slice(ultimo, m.index));
            out += enlaces ? ponerEnlace(ctx, {
                tipo: "web",
                url: url
            }, escapar(url)) : escapar(url);
            ultimo = fin;
            continue;
        }
        out += escapar(texto.slice(ultimo, m.index));
        if (m[1] !== undefined) {
            var etiqueta = escapar(etiquetaNota(m[1], m[2]));
            var e = enlaces ? enlaceNota(m[1], ctx) : null;
            out += e ? ponerEnlace(ctx, e, etiqueta) : etiqueta;
        } else if (m[3] !== undefined) {
            var dentro = enLinea(m[3], ctx, prof + 1, false);
            out += enlaces ? ponerEnlace(ctx, {
                tipo: "web",
                url: m[4]
            }, dentro) : dentro;
        } else if (m[5] !== undefined) {
            out += '<font color="' + ctx.colores.codigo + '">' + escapar(m[5]) + "</font>";
        } else if (m[6] !== undefined) {
            out += "<b>" + enLinea(m[6], ctx, prof + 1, enlaces) + "</b>";
        } else if (m[7] !== undefined) {
            out += "<s>" + enLinea(m[7], ctx, prof + 1, enlaces) + "</s>";
        } else {
            out += "<i>" + enLinea(m[8], ctx, prof + 1, enlaces) + "</i>";
        }
        ultimo = fin;
    }
    return out + escapar(texto.slice(ultimo));
}

// Un trozo de texto de la página: { html, oculto }. oculto es el mismo texto
// con los euros tapados; si no lleva euros, es el mismo. Los dos tienen los
// mismos enlaces en el mismo orden, así que el número de cada uno vale en los
// dos (los del tapado se apuntan en una lista que se tira).
function trozo(texto, ctx) {
    var antes = ctx.enlaces.length;
    var html = enLinea(texto, ctx);
    if (!conEuros(texto))
        return {
            html: html,
            oculto: html
        };
    var otro = {
        ruta: ctx.ruta,
        permitidas: ctx.permitidas,
        colores: ctx.colores,
        enlaces: ctx.enlaces.slice(0, antes)
    };
    return {
        html: html,
        oculto: enLinea(taparEuros(texto), otro)
    };
}

// Lo mismo para un texto que va tal cual (el código): { texto, oculto }.
function plano(texto) {
    return {
        texto: texto,
        oculto: conEuros(texto) ? taparEuros(texto) : texto
    };
}

// El texto sin las marcas (plain de la web), para medirlo.
function sinMarcas(texto) {
    return String(texto).replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, function (m, a, b) {
        return etiquetaNota(a, b);
    }).replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, "$1").replace(/\*\*|~~|`/g, "");
}

// El ancho de cada columna de una tabla (naturales: lo que ocupa cada una sin
// partir, en píxeles) para que quepa en «total», como reparte un navegador:
// si sobra sitio, se reparte en proporción; si falta, las columnas que caben
// en su parte se quedan como están y las demás se reparten lo que queda (y su
// texto se parte). Si ni con «minimo» cada una caben, cada columna se queda en
// lo suyo (hasta algo más de la mitad del total) y la tabla se desliza de lado.
function anchosColumnas(naturales, total, minimo) {
    var n = naturales.length;
    if (!n || !(total > 0))
        return naturales.slice();
    var suma = naturales.reduce(function (a, b) {
        return a + b;
    }, 0);
    if (suma <= total)
        return naturales.map(function (w) {
            return w + (total - suma) * w / suma;
        });
    if (n * minimo > total)
        return naturales.map(function (w) {
            return Math.max(minimo, Math.min(w, total * 0.62));
        });
    var anchos = naturales.slice();
    var quedan = naturales.map(function (w, i) {
        return i;
    });
    var resto = total;
    for (;;) {
        var parte = resto / quedan.length;
        var caben = quedan.filter(function (i) {
            return naturales[i] <= parte;
        });
        if (!caben.length) {
            quedan.forEach(function (i) {
                anchos[i] = Math.max(minimo, parte);
            });
            return anchos;
        }
        caben.forEach(function (i) {
            resto -= naturales[i];
        });
        quedan = quedan.filter(function (i) {
            return naturales[i] > parte;
        });
        if (!quedan.length)
            return anchos;
    }
}

// --- La página -----------------------------------------------------------------------

// Si una línea empieza un bloque (y corta el párrafo de antes).
function empiezaBloque(l) {
    return VALLA.test(l) || CABECERA.test(l) || CITA.test(l) || LISTA.test(l) || RAYA.test(l) || /^\s*\|/.test(l);
}

function sangria(l) {
    return /^\s*/.exec(l)[0].length;
}

// Las celdas de una fila de tabla, partida por sus barras y no por las de un
// [[enlace|alias]] (notaCeldas de la web).
function celdas(fila) {
    var out = [];
    var cur = "";
    var enEnlace = false;
    var s = fila.trim().replace(/^\|/, "").replace(/\|$/, "");
    for (var k = 0; k < s.length; k++) {
        if (s.substr(k, 2) === "[[")
            enEnlace = true;
        if (s.substr(k, 2) === "]]")
            enEnlace = false;
        if (s[k] === "|" && !enEnlace && s[k - 1] !== "\\") {
            out.push(cur.trim());
            cur = "";
        } else {
            cur += s[k];
        }
    }
    out.push(cur.trim());
    return out.map(function (c) {
        return c.replace(/\\\|/g, "|");
    });
}

// La lista que empieza en lineas[i] (anidada por la sangría): [bloque, índice
// de la primera línea de después] (notaLista de la web).
function lista(lineas, i, ctx, prof) {
    var primera = LISTA.exec(lineas[i]);
    var base = primera[1].length;
    var ordenada = /\d/.test(primera[2]);
    var inicio = ordenada ? parseInt(primera[2], 10) : 1;
    var crudos = [];
    while (i < lineas.length) {
        var m = LISTA.exec(lineas[i]);
        if (!m || m[1].length !== base || /\d/.test(m[2]) !== ordenada)
            break;
        var item = {
            texto: m[3],
            sub: []
        };
        crudos.push(item);
        for (i++; i < lineas.length; i++) {
            if (lineas[i].trim()) {
                if (sangria(lineas[i]) <= base)
                    break;
                item.sub.push(lineas[i]);
            } else {
                var siguiente = lineas[i + 1];
                if (siguiente === undefined || !siguiente.trim() || sangria(siguiente) <= base)
                    break;
                item.sub.push(lineas[i]);
            }
        }
    }
    var items = crudos.map(function (it, n) {
        var tarea = /^\[([ xX])\]\s+(.*)$/.exec(it.texto);
        // Las líneas sangradas que siguen al elemento, hasta la primera que
        // empieza otra cosa (una sublista, una cita…), son su mismo texto
        // partido: van con él (la web las pone en un párrafo aparte).
        var seguidas = [tarea ? tarea[2] : it.texto];
        while (it.sub.length && it.sub[0].trim() && !empiezaBloque(it.sub[0]))
            seguidas.push(it.sub.shift());
        var sub = it.sub.filter(function (x) {
            return x.trim();
        });
        var menos = sub.length ? Math.min.apply(null, sub.map(sangria)) : 0;
        return {
            marca: ordenada ? (inicio + n) + "." : "•",
            tarea: tarea ? tarea[1] !== " " : null,
            texto: trozoParrafo(seguidas, ctx),
            bloques: it.sub.length ? bloques(it.sub.map(function (x) {
                return x.slice(Math.min(menos, x.length));
            }).join("\n"), ctx, prof + 1) : []
        };
    });
    return [{
            tipo: "lista",
            ordenada: ordenada,
            items: items
        }, i];
}

// Un texto de Markdown en bloques: [{ tipo, … }], con tipo
//   "cabecera": { nivel (1–6), texto, clave (normal()) }
//   "parrafo":  { texto }
//   "codigo":   { codigo: { texto, oculto } }
//   "raya":     {}
//   "cita":     { bloques }
//   "aviso":    { clase, titulo, bloques }
//   "tabla":    { columnas, largos (los caracteres de cada columna), cabeza:
//               [trozo], filas: [[trozo]] }
//   "lista":    { ordenada, items: [{ marca, tarea (null, true o false), texto, bloques }] }
// donde cada texto es un trozo() ({ html, oculto }). Los comentarios de
// Obsidian (%% … %%) no salen.
function bloques(texto, ctx, prof) {
    prof = prof || 0;
    var lineas = String(texto === undefined || texto === null ? "" : texto).replace(/\r/g, "").replace(/%%[\s\S]*?%%/g, "").split("\n");
    var out = [];
    if (prof > MAX_PROFUNDIDAD) {
        var resto = lineas.filter(function (l) {
            return l.trim();
        });
        if (resto.length)
            out.push({
                tipo: "parrafo",
                texto: trozo(resto.map(function (l) {
                    return l.trim();
                }).join(" "), ctx)
            });
        return out;
    }
    var i = 0;
    while (i < lineas.length) {
        var l = lineas[i];
        if (!l.trim()) {
            i++;
            continue;
        }

        var valla = VALLA.exec(l);
        if (valla) {
            var codigo = [];
            for (i++; i < lineas.length && lineas[i].replace(/^\s+/, "").indexOf(valla[1]) !== 0; i++)
                codigo.push(lineas[i]);
            i++;
            out.push({
                tipo: "codigo",
                codigo: plano(codigo.join("\n"))
            });
            continue;
        }

        var cab = CABECERA.exec(l);
        if (cab) {
            var txt = cab[2].replace(/\s+#+\s*$/, "").trim();
            out.push({
                tipo: "cabecera",
                nivel: cab[1].length,
                texto: trozo(txt, ctx),
                clave: normal(txt)
            });
            i++;
            continue;
        }

        if (RAYA.test(l)) {
            out.push({
                tipo: "raya"
            });
            i++;
            continue;
        }

        if (CITA.test(l)) {
            var cita = [];
            for (; i < lineas.length && CITA.test(lineas[i]); i++)
                cita.push(lineas[i].replace(/^\s*>\s?/, ""));
            var aviso = AVISO.exec(cita[0] || "");
            if (aviso)
                out.push({
                    tipo: "aviso",
                    clase: aviso[1].toLowerCase(),
                    titulo: trozo(aviso[2] || aviso[1], ctx),
                    bloques: bloques(cita.slice(1).join("\n"), ctx, prof + 1)
                });
            else
                out.push({
                    tipo: "cita",
                    bloques: bloques(cita.join("\n"), ctx, prof + 1)
                });
            continue;
        }

        if (/^\s*\|/.test(l) && i + 1 < lineas.length && TABLA_SEP.test(lineas[i + 1])) {
            var cabeza = celdas(l);
            var filas = [];
            for (i += 2; i < lineas.length && /^\s*\|/.test(lineas[i]); i++)
                filas.push(celdas(lineas[i]));
            // Todas las filas con las mismas columnas, para la rejilla.
            var n = Math.max.apply(null, [cabeza.length].concat(filas.map(function (f) {
                return f.length;
            })));
            var crudas = [cabeza].concat(filas).map(function (f) {
                var r = f.slice();
                while (r.length < n)
                    r.push("");
                return r;
            });
            // Lo que ocupa cada columna sin partir, en caracteres (la letra del
            // cajón es de ancho fijo): con eso se reparte el ancho.
            var largos = [];
            for (var c = 0; c < n; c++)
                largos.push(Math.max.apply(null, crudas.map(function (f) {
                    return sinMarcas(f[c]).length;
                })));
            var aTrozos = function (f) {
                return f.map(function (x) {
                    return trozo(x, ctx);
                });
            };
            out.push({
                tipo: "tabla",
                columnas: n,
                largos: largos,
                cabeza: aTrozos(crudas[0]),
                filas: crudas.slice(1).map(aTrozos)
            });
            continue;
        }

        if (LISTA.test(l)) {
            var r = lista(lineas, i, ctx, prof);
            out.push(r[0]);
            i = r[1];
            continue;
        }

        var parrafo = [];
        for (; i < lineas.length && lineas[i].trim() && !empiezaBloque(lineas[i]); i++)
            parrafo.push(lineas[i]);
        if (!parrafo.length) {
            // Una línea que parece empezar un bloque y no lo es (una barra
            // sin tabla): va sola, como texto.
            out.push({
                tipo: "parrafo",
                texto: trozo(l.trim(), ctx)
            });
            i++;
            continue;
        }
        out.push({
            tipo: "parrafo",
            texto: trozoParrafo(parrafo, ctx)
        });
    }
    return out;
}

// Las líneas de un párrafo, juntas: el cajón es estrecho y las notas vienen
// partidas a mano a unos 90 caracteres, así que cada salto de línea es un
// espacio y el texto se reparte solo (lo de CommonMark; la web y Obsidian
// ponen un <br> en cada uno). Una línea que acaba en dos espacios o en «\»
// sí corta. Se miran juntas, así que un enlace o una negrita partidos en dos
// líneas siguen siéndolo.
function trozoParrafo(lineas, ctx) {
    var junto = "";
    for (var k = 0; k < lineas.length; k++) {
        var l = lineas[k];
        var corta = / {2,}$|\\$/.test(l);
        junto += l.trim().replace(/\\$/, "");
        if (k < lineas.length - 1)
            junto += corta ? "\n" : " ";
    }
    // El \n sólo puede venir de aquí: el texto de cada línea no lo lleva.
    var t = trozo(junto, ctx);
    return {
        html: t.html.replace(/\n/g, "<br>"),
        oculto: t.oculto.replace(/\n/g, "<br>")
    };
}

// La página entera de una nota: { bloques, enlaces, euros }. ruta es la de la
// nota (para los [[#Cabecera]]), permitidas las carpetas de personal.allowed y
// colores los de Theme.qml que van dentro del texto ({ codigo: "#rrggbb" }).
// enlaces son los destinos de los <a href="n:3">: { tipo: "nota", ruta,
// cabecera } o { tipo: "web", url }. euros dice si algo se tapa con el cajón a
// medio sacar.
function pagina(texto, ruta, permitidas, colores) {
    var ctx = {
        ruta: ruta || "",
        permitidas: permitidas || [],
        colores: colores || {
            codigo: "#ffffff"
        },
        enlaces: []
    };
    return {
        bloques: bloques(texto, ctx, 0),
        enlaces: ctx.enlaces,
        euros: conEuros(texto)
    };
}

// El enlace de un href de la página («n:3»), o null.
function enlace(pag, href) {
    var m = /^n:(\d+)$/.exec(String(href));
    return pag && m ? pag.enlaces[Number(m[1])] || null : null;
}

// --- Para enseñar una ruta ----------------------------------------------------------------

var MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

// «hace 5 min», «hace 2 h», «hace 3 días» (ago de la web); con más de un mes,
// la fecha.
function hace(fecha, ahora) {
    if (!fecha)
        return "";
    var s = Math.max(0, ((ahora || new Date()).getTime() - fecha.getTime()) / 1000);
    if (s < 60)
        return "hace un momento";
    if (s < 3600)
        return "hace " + Math.floor(s / 60) + " min";
    if (s < 86400)
        return "hace " + Math.floor(s / 3600) + " h";
    var d = Math.floor(s / 86400);
    if (d <= 31)
        return "hace " + d + (d === 1 ? " día" : " días");
    return "el " + fecha.getDate() + " de " + MESES[fecha.getMonth()] + " de " + fecha.getFullYear();
}
