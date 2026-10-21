.pragma library

// Las reglas de ver los proyectos en el cajón, sin nada de interfaz: los
// grupos por estado, los subproyectos de cada proyecto y el texto sin marcas.
// Es lo de la columna y las tarjetas de Proyectos de la web
// (panel/internal/panel/web/github.js y home.js, repo homelab). Qué se puede
// escribir en una nota de proyecto lo decide el NUC.

var GRUPOS = [["activo", "Activos"], ["pausado", "Pausados"], ["idea", "Ideas"], ["hecho", "Hechos"]];
// Los que acepta POST /api/proyectos.
var ESTADOS = ["activo", "pausado", "idea", "hecho", "archivado"];
var PRIORIDADES = ["alta", "media", "baja"];

// Un subproyecto cuyo proyecto no se encuentra sale como uno más.
function esRaiz(lista, p) {
    return !p.padre || !lista.some(function (q) {
        return q.ruta === p.padre;
    });
}

// Los grupos de la lista, con solo los proyectos de arriba (los subproyectos
// van dentro de su proyecto), en el orden del NUC: [{ clave, titulo,
// proyectos }]. Lo que no es de ningún estado conocido (archivado, sin
// estado) va al final, en «Otros».
function grupos(lista) {
    var raiz = (lista || []).filter(function (p) {
        return esRaiz(lista, p);
    });
    var conocidos = GRUPOS.map(function (g) {
        return g[0];
    });
    var out = [];
    GRUPOS.forEach(function (g) {
        var ps = raiz.filter(function (p) {
            return p.estado === g[0];
        });
        if (ps.length)
            out.push({
                clave: g[0],
                titulo: g[1],
                proyectos: ps
            });
    });
    var otros = raiz.filter(function (p) {
        return conocidos.indexOf(p.estado) < 0;
    });
    if (otros.length)
        out.push({
            clave: "otros",
            titulo: "Otros",
            proyectos: otros
        });
    return out;
}

function subsDe(lista, ruta) {
    return (lista || []).filter(function (p) {
        return p.padre === ruta;
    });
}

function buscar(lista, ruta) {
    var l = lista || [];
    for (var i = 0; i < l.length; i++)
        if (l[i].ruta === ruta)
            return l[i];
    return null;
}

// Sin las marcas de Markdown, como plain() de la web: los enlaces [[…]] y
// [texto](url) se quedan en su texto.
function plano(texto) {
    return String(texto || "").replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, function (_, a, b) {
        return (b || a.split("#")[0].split("/").pop()).trim();
    }).replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, "$1").replace(/\*\*|~~|`/g, "");
}

// El repo de un proyecto o, en un subproyecto sin el suyo, el de su
// proyecto: { repo, heredado (el título del proyecto del que viene, o "") }.
function repoDe(lista, p) {
    if (p.repo)
        return {
            repo: p.repo,
            heredado: ""
        };
    var padre = p.padre ? buscar(lista, p.padre) : null;
    if (padre && padre.repo)
        return {
            repo: padre.repo,
            heredado: padre.titulo
        };
    return {
        repo: "",
        heredado: ""
    };
}

// Lo que se ve de un repo junto al proyecto: «dueño/nombre», o solo
// «nombre» si es del usuario de GitHub.
function repoCorto(repo, usuario) {
    var partes = String(repo || "").split("/");
    return usuario && partes.length === 2 && partes[0].toLowerCase() === usuario.toLowerCase() ? partes[1] : repo;
}
