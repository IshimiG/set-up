.pragma library
.import "TareasLogica.js" as Tareas

// Las reglas de ver el servidor en el cajón, sin nada de interfaz: qué dice y
// qué botones lleva cada contenedor y cada stack, qué se explica antes de una
// acción que pide confirmación, y cómo se escriben los bytes y los %. Es lo de
// la web (panel/internal/panel/web/app.js, repo homelab, «Botones que siguen
// al estado real» de la nota 19) llevado aquí: los botones siguen a lo que
// dice Docker ahora, no al último botón que se pulsó. Qué acciones existen y
// cuáles piden escribir un nombre lo decide el NUC (las «acciones» de cada
// contenedor y stack, que Api.qml deja vacías para quien no puede actuar).

var ETIQUETAS = {
    start: "Arrancar",
    stop: "Parar",
    restart: "Reiniciar",
    up: "Levantar todo",
    update: "Actualizar",
    down: "Bajar (down)"
};

function bytes(n) {
    if (!n)
        return "0";
    var u = ["B", "KiB", "MiB", "GiB", "TiB"];
    var i = 0;
    while (n >= 1024 && i < u.length - 1) {
        n /= 1024;
        i++;
    }
    return (n >= 10 || i === 0 ? n.toFixed(0) : n.toFixed(1)).replace(".", ",") + " " + u[i];
}

function pct(n) {
    return (n >= 10 ? n.toFixed(0) : n.toFixed(1)).replace(".", ",") + " %";
}

// El color de una barra de consumo: "mal" pasado el 90 %, "aviso" pasado el
// 75 %.
function nivelUso(frac) {
    return frac > 0.9 ? "mal" : frac > 0.75 ? "aviso" : "";
}

// Lo que enseña un contenedor: { punto ("ok", "aviso", "mal", "ocupado" o ""),
// texto, botones: [{ accion, principal }] }. Los botones son los que tienen
// sentido en su estado; quien pinta deja solo los que traen sus acciones.
function vista(c) {
    if (c.ocupado)
        return {
            punto: "ocupado",
            texto: c.ocupado + "…",
            botones: []
        };
    var desde = Tareas.hace(c.desde);
    switch (c.estado) {
    case "running":
        if (c.salud === "starting")
            return {
                punto: "aviso",
                texto: "arrancando" + (desde ? " · " + desde : ""),
                botones: []
            };
        if (c.salud === "unhealthy")
            return {
                punto: "mal",
                texto: "con fallos" + (desde ? " · arriba " + desde : ""),
                botones: [{
                        accion: "restart",
                        principal: true
                    }, {
                        accion: "stop",
                        principal: false
                    }]
            };
        return {
            punto: "ok",
            texto: "arriba" + (desde ? " " + desde : "") + (c.salud === "healthy" ? " · sano" : ""),
            botones: [{
                    accion: "stop",
                    principal: true
                }, {
                    accion: "restart",
                    principal: false
                }]
        };
    case "restarting":
        return {
            punto: "aviso",
            texto: "reiniciándose (" + c.reinicios + ")",
            botones: [{
                    accion: "stop",
                    principal: false
                }]
        };
    case "paused":
        return {
            punto: "aviso",
            texto: "en pausa",
            botones: [{
                    accion: "stop",
                    principal: false
                }]
        };
    case "created":
        return {
            punto: "",
            texto: "creado, sin arrancar",
            botones: [{
                    accion: "start",
                    principal: true
                }]
        };
    case "dead":
        return {
            punto: "mal",
            texto: "muerto",
            botones: [{
                    accion: "start",
                    principal: true
                }]
        };
    default:
        var parado = Tareas.hace(c.hasta);
        return {
            punto: "",
            texto: "parado" + (parado ? " " + parado : "") + (c.codigo ? " · código " + c.codigo : ""),
            botones: [{
                    accion: "start",
                    principal: true
                }]
        };
    }
}

// Los botones de un contenedor que se pueden pulsar: los de su estado que el
// NUC le deja hacer.
function botones(c) {
    return vista(c).botones.filter(function (b) {
        return b.accion in c.acciones;
    }).map(function (b) {
        return {
            accion: b.accion,
            principal: b.principal,
            etiqueta: ETIQUETAS[b.accion],
            peligro: b.accion === "stop" && c.acciones.stop !== ""
        };
    });
}

function enMarcha(st) {
    return st.contenedores.filter(function (c) {
        return c.estado === "running";
    }).length;
}

// Algún contenedor del stack, o el stack, con una acción en marcha.
function ocupado(st) {
    return st.ocupado !== "" || st.contenedores.some(function (c) {
        return c.ocupado !== "";
    });
}

// Los botones de la cabecera de un stack: levantar lo que falta y parar lo
// que está en marcha. Solo los stacks de la configuración del panel.
function botonesStack(st) {
    var out = [];
    if (!st.gestionado || ocupado(st))
        return out;
    var n = enMarcha(st);
    var total = st.contenedores.length;
    if ((n < total || total === 0) && "up" in st.acciones)
        out.push({
            accion: "up",
            principal: n === 0,
            etiqueta: "Levantar todo",
            peligro: false
        });
    if (n > 0 && "stop" in st.acciones)
        out.push({
            accion: "stop",
            principal: n === total,
            etiqueta: "Parar todo",
            peligro: st.acciones.stop !== ""
        });
    return out;
}

// Lo del menú «⋯» de un stack: actualizar las imágenes y bajarlo.
function menuStack(st) {
    var out = [];
    if (!st.gestionado || ocupado(st))
        return out;
    if ("update" in st.acciones)
        out.push({
            accion: "update",
            principal: false,
            etiqueta: "Actualizar imágenes",
            peligro: false
        });
    if ("down" in st.acciones)
        out.push({
            accion: "down",
            principal: false,
            etiqueta: "Bajar (down)",
            peligro: true
        });
    return out;
}

// El contenedor o el stack de ese nombre.
function buscar(stacks, tipo, nombre) {
    for (var i = 0; i < stacks.length; i++) {
        var st = stacks[i];
        if (tipo === "stack" && st.nombre === nombre)
            return st;
        if (tipo === "contenedor") {
            for (var j = 0; j < st.contenedores.length; j++)
                if (st.contenedores[j].nombre === nombre)
                    return st.contenedores[j];
        }
    }
    return null;
}

// La palabra que hay que escribir para confirmar la acción, o "".
function palabra(stacks, tipo, nombre, accion) {
    var t = buscar(stacks, tipo, nombre);
    return t && t.acciones && t.acciones[accion] ? t.acciones[accion] : "";
}

// Lo que se explica en la confirmación, como en la web.
function explicar(stacks, tipo, nombre, accion) {
    var t = buscar(stacks, tipo, nombre) || {};
    var st = tipo === "stack" ? t : (buscar(stacks, "stack", t.stack) || {});
    var lineas = [];
    if (st.protegido)
        lineas.push(st.nombre + " está protegido: su biblioteca y sus datos no se tocan.");
    var critico = tipo === "stack" ? (t.contenedores || []).some(function (c) {
        return c.critico;
    }) : t.critico;
    if (accion === "stop" && critico)
        lineas.push("Caddy es la puerta del panel: si lo paras, la web y este cajón dejan de responder hasta que lo arranques por SSH.");
    if (accion === "down")
        lineas.push("Quita los contenedores y redes del stack. Los volúmenes y los datos se quedan.");
    if (accion === "update")
        lineas.push("Descarga las imágenes de las versiones fijadas en el compose y recrea los contenedores que cambien.");
    return lineas.join("\n");
}
