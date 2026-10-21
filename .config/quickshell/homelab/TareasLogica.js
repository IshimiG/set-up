.pragma library

// Las reglas de ver las tareas del cajón, sin nada de interfaz: qué entra en
// «Ahora», cómo se agrupa cada vista y cómo se resume un grupo. Es el Foco de
// la web (panel/internal/panel/web/tareas.js, repo homelab) llevado aquí. Las
// reglas de verdad (la prioridad que sube cerca de la fecha, qué se puede
// escribir) siguen en el NUC: aquí solo se ordena y se agrupa lo que llega ya
// normalizado de Api.qml.
//
// Una «entrada» es una tarea de Api.tareas con los datos de su sección
// pegados (seccionId, seccionTitulo, seccionColor, pausa): así una fila se
// pinta con un solo objeto.

var NIVELES = ["maxima", "alta", "media", "baja", "minima"];
var NOMBRES = {
    maxima: "Máxima",
    alta: "Alta",
    media: "Media",
    baja: "Baja",
    minima: "Mínima"
};
var VISTAS = [["plazo", "Plazo"], ["proyecto", "Proyecto"], ["prioridad", "Prioridad"], ["todas", "Todas"]];

var MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

function rango(p) {
    var i = NIVELES.indexOf(p);
    return i < 0 ? 5 : i;
}

// «2026-10-22» → «22 oct».
function fechaCorta(s) {
    var m = /^(\d{4})-(\d\d)-(\d\d)/.exec(s || "");
    return m ? (+m[3]) + " " + MESES[+m[2] - 1] : "";
}

// Las abiertas por la prioridad de hoy, después la fecha y después el orden
// de la nota.
function porUrgencia(a, b) {
    var r = rango(a.efectiva) - rango(b.efectiva);
    if (r !== 0)
        return r;
    var fa = a.vence || "9999", fb = b.vence || "9999";
    if (fa !== fb)
        return fa < fb ? -1 : 1;
    return a.linea - b.linea;
}

// Todas las tareas con los datos de su sección.
function entradas(datos) {
    var out = [];
    if (!datos)
        return out;
    for (var i = 0; i < datos.secciones.length; i++) {
        var s = datos.secciones[i];
        for (var j = 0; j < s.tareas.length; j++)
            out.push(Object.assign({}, s.tareas[j], {
                seccionId: s.id,
                seccionTitulo: s.titulo,
                seccionColor: s.color,
                pausa: s.pausa
            }));
    }
    return out;
}

// «Ahora»: lo fijado a mano y, hasta tres, lo más urgente de lo abierto (nunca
// En pausa ni lo que aún no ha empezado). Si hay tres o más fijadas, todas.
function ahora(todas) {
    var abiertas = todas.filter(function (t) {
        return !t.hecha;
    });
    var fijadas = abiertas.filter(function (t) {
        return t.fijada;
    }).sort(porUrgencia);
    if (fijadas.length >= 3)
        return fijadas;
    var resto = abiertas.filter(function (t) {
        return !t.fijada && !t.pausa && !t.noEmpezada;
    }).sort(porUrgencia);
    return fijadas.concat(resto.slice(0, 3 - fijadas.length));
}

function plural(n, uno, varios) {
    return n + " " + (n === 1 ? uno : varios);
}

// Lo que se dice de un grupo junto a su cuenta: «la próxima vence mañana»
// (o «vencida hace 2 días»), y nada si ninguna tiene fecha.
function resumen(lista) {
    var dias = lista.filter(function (t) {
        return t.dias !== null;
    }).map(function (t) {
        return t.dias;
    });
    if (!dias.length)
        return "";
    var m = Math.min.apply(null, dias);
    return m < 0 ? "vencida hace " + plural(-m, "día", "días") : m === 0 ? "la próxima vence hoy" : m === 1 ? "la próxima vence mañana" : "la próxima vence en " + m + " días";
}

// Un grupo plegable. tipo: "normal", "pausa" o "hechas" (los dos últimos
// empiezan plegados).
function grupo(clave, titulo, items, o) {
    o = o || {};
    return {
        clave: clave,
        titulo: titulo,
        items: items,
        tipo: o.tipo || "normal",
        cuadrado: o.cuadrado === undefined ? false : o.cuadrado,
        color: o.color || "",
        punto: o.punto || "",
        resumen: o.tipo === "hechas" ? "" : resumen(items),
        vacio: o.vacio || "Nada aquí."
    };
}

// Los grupos de una vista: "plazo", "proyecto", "prioridad" o "todas".
// filtro es lo que se teclea en el filtro («/»); vacío no filtra. ahoraLineas
// son las líneas de lo que ya sale en «Ahora» (la vista Plazo no lo repite,
// como en la web).
function grupos(datos, vista, filtro, ahoraLineas) {
    var q = (filtro || "").trim().toLowerCase();
    var todas = entradas(datos);
    var coincide = function (t) {
        return !q || (t.plano + " " + t.area + " " + t.seccionTitulo).toLowerCase().indexOf(q) >= 0;
    };
    var abiertas = todas.filter(function (t) {
        return !t.hecha && !t.pausa && coincide(t);
    });
    var enPausa = todas.filter(function (t) {
        return !t.hecha && t.pausa && coincide(t);
    }).sort(porUrgencia);
    var hechas = todas.filter(function (t) {
        return t.hecha && coincide(t);
    }).sort(function (a, b) {
        return a.hechaEl < b.hechaEl ? 1 : a.hechaEl > b.hechaEl ? -1 : a.linea - b.linea;
    });
    var out = [];

    if (vista === "plazo") {
        var resto = abiertas.filter(function (t) {
            return ahoraLineas.indexOf(t.linea) < 0;
        }).sort(porUrgencia);
        [["Esta semana", function (t) {
                    return t.dias !== null && t.dias <= 7;
                }], ["Con fecha más adelante", function (t) {
                    return t.dias !== null && t.dias > 7;
                }], ["Sin fecha", function (t) {
                    return t.dias === null;
                }]].forEach(function (par) {
            var g = resto.filter(par[1]);
            if (g.length)
                out.push(grupo("plazo|" + par[0], par[0], g));
        });
    } else if (vista === "proyecto") {
        datos.secciones.forEach(function (s) {
            if (s.pausa)
                return;
            var mias = abiertas.filter(function (t) {
                return t.seccionId === s.id;
            }).sort(porUrgencia);
            if (q && !mias.length)
                return;
            out.push(grupo("proyecto|" + s.id, s.titulo, mias, {
                cuadrado: true,
                color: s.color
            }));
        });
    } else if (vista === "prioridad") {
        NIVELES.concat([""]).forEach(function (n) {
            var g = abiertas.filter(function (t) {
                return t.efectiva === n;
            }).sort(porUrgencia);
            if (g.length)
                out.push(grupo("prioridad|" + (n || "ninguna"), n ? NOMBRES[n] : "Sin prioridad", g, {
                    punto: n
                }));
        });
    } else {
        out.push(grupo("todas|todas", "Todas", abiertas.slice().sort(porUrgencia)));
    }

    if (enPausa.length)
        out.push(grupo("pausa", "En pausa", enPausa, {
            tipo: "pausa"
        }));
    if (hechas.length)
        out.push(grupo("hechas", "Hechas", hechas, {
            tipo: "hechas"
        }));
    return out;
}

// El orden en que se recorre con j y k: primero las tarjetas de «Ahora» y
// después las filas de los grupos desplegados.
function recorrido(listaAhora, listaGrupos, plegado) {
    var out = listaAhora.map(function (t) {
        return {
            ctx: "a",
            linea: t.linea
        };
    });
    listaGrupos.forEach(function (g) {
        if (plegado(g))
            return;
        g.items.forEach(function (t) {
            out.push({
                ctx: "r",
                linea: t.linea
            });
        });
    });
    return out;
}

// El texto de «cuándo» de una fila: relativo y corto.
function cuando(t) {
    if (t.hecha)
        return t.hechaEl ? "hecha " + fechaCorta(t.hechaEl) : "hecha";
    if (t.dias === null)
        return t.noEmpezada ? "desde " + fechaCorta(t.empieza) : "";
    if (t.dias < 0)
        return "vencida";
    if (t.dias === 0)
        return "hoy";
    if (t.dias === 1)
        return "mañana";
    return "en " + t.dias + " d";
}

// La cuenta atrás grande de una tarjeta de «Ahora».
function cuentaAtras(t) {
    if (t.dias === null)
        return "sin fecha";
    if (t.dias < 0)
        return "vencida";
    if (t.dias === 0)
        return "hoy";
    return plural(t.dias, "día", "días");
}

// Un detalle `**Etiqueta**: texto` con la etiqueta en negrita (StyledText);
// todo lo demás, escapado.
function detalleHtml(raw) {
    var esc = function (x) {
        return String(x).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    };
    var l = String(raw).trim().replace(/^[-*]\s+/, "");
    var m = /^\*\*([^*]+?)\*\*(\s*\([^)]*\))?\s*:\s*(.*)$/.exec(l);
    if (m)
        return "<b>" + esc(m[1].trim() + (m[2] ? " " + m[2].trim() : "")) + "</b>: " + esc(m[3]);
    return esc(l.replace(/\*\*|~~|`/g, ""));
}

// Fechas para los atajos del editor: hoy + n días, como «2026-10-22».
function fechaMasDias(hoy, n) {
    var m = /^(\d{4})-(\d\d)-(\d\d)/.exec(hoy || "");
    var d = m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])) : new Date();
    d.setUTCDate(d.getUTCDate() + n);
    var dos = function (x) {
        return (x < 10 ? "0" : "") + x;
    };
    return d.getUTCFullYear() + "-" + dos(d.getUTCMonth() + 1) + "-" + dos(d.getUTCDate());
}

// «hace 5 min», «hace 2 h», «hace 3 días» (fecha es un Date).
function hace(fecha) {
    if (!fecha)
        return "";
    var s = Math.max(0, (Date.now() - fecha.getTime()) / 1000);
    if (s < 60)
        return "hace un momento";
    if (s < 3600)
        return "hace " + Math.floor(s / 60) + " min";
    if (s < 86400)
        return "hace " + Math.floor(s / 3600) + " h";
    var d = Math.floor(s / 86400);
    return "hace " + d + (d === 1 ? " día" : " días");
}
