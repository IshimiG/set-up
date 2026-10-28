.pragma library

// El orden de las secciones de la tira, sin nada de interfaz. El orden guardado
// es una lista de ids; las secciones son las de siempre (Contenido.qml). El
// orden nunca manda sobre qué secciones existen: sólo las coloca.

// Las secciones colocadas según «guardado» (lista de ids). Las que el orden no
// nombra (secciones nuevas) van al final, en su orden de siempre; los ids
// desconocidos y los repetidos se ignoran. Un guardado que no es una lista deja
// el orden de siempre.
function ordenar(secciones, guardado) {
    var lista = Array.isArray(guardado) ? guardado : [];
    var porId = {};
    secciones.forEach(function (s) {
        porId[s.id] = s;
    });
    var vistas = {};
    var salida = [];
    lista.forEach(function (id) {
        if (typeof id === "string" && porId[id] && !vistas[id]) {
            vistas[id] = true;
            salida.push(porId[id]);
        }
    });
    secciones.forEach(function (s) {
        if (!vistas[s.id])
            salida.push(s);
    });
    return salida;
}

// La lista de ids con el de la posición «de» llevado a la posición «a». Una
// copia: la original no cambia. Fuera de rango, no se mueve nada.
function mover(ids, de, a) {
    var copia = ids.slice();
    if (de < 0 || de >= copia.length || a < 0 || a >= copia.length || de === a)
        return copia;
    copia.splice(a, 0, copia.splice(de, 1)[0]);
    return copia;
}

// La posición a la que cae lo arrastrado: parte de «desde» (su posición al
// empezar), se ha movido «dy» píxeles y cada hueco mide «paso».
function destino(desde, dy, paso, total) {
    return Math.max(0, Math.min(total - 1, Math.round(desde + dy / paso)));
}
