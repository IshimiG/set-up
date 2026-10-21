.pragma library

// La agenda del escritorio: lo que tiene fecha, en un formato que entiende el
// calendario de la barra. Es el contrato entre dos procesos de qs que no se
// hablan de otra forma:
//
//   - el cajón del homelab (homelab/Agenda.qml), el único que habla con el
//     panel del NUC, la escribe en un fichero de $XDG_RUNTIME_DIR (en memoria,
//     solo del usuario, modo 600) cada vez que cambian las tareas;
//   - la barra (bar/Agenda.qml) vigila ese fichero y el calendario
//     (bar/CalendarPanel.qml) lo pinta.
//
// Sin el fichero (el cajón no está en marcha, no tiene credenciales o aún no
// ha leído las tareas) la barra enseña la rejilla del mes sin nada más.
//
// El fichero, formato 1:
//   { formato: 1,
//     conectado: true si el cajón tenía la conexión con el panel al escribirlo,
//     actualizado: cuándo se leyó lo que lleva ("2026-10-21T15:04:05.000Z" o ""),
//     eventos: [evento], ordenados por día }
// y cada evento:
//   { dia: "2026-10-22",
//     titulo: el texto, sin marcas de Markdown,
//     origen: "clase" (una entrega de Aules, la sección Clase de 00 Inicio) o
//             "tarea" (cualquier otra tarea con fecha),
//     prioridad: "maxima", "alta", "media", "baja", "minima", "pausa" o "",
//     todoElDia: true, hora: "HH:mm" o "" (todo el día),
//     vencida, hecha: bool,
//     area: el área de la tarea ("Clase" en las entregas de Aules) o "",
//     seccion: el título de su sección, color: "#rrggbb" o "" }
//
// Es lo mismo que el panel lleva a los calendarios «Clase» y «Personal» de
// Google: las tareas con fecha de 00 Inicio. Para más adelante queda leer las
// reuniones de Google de verdad (un endpoint nuevo en el panel); entrarían en
// este mismo fichero como eventos con origen "google", todoElDia false y su
// hora, y la barra ya los sabe pintar. Un campo o un origen nuevos no cambian
// el formato; solo un cambio que la barra de antes leería mal sube el número,
// y esa barra deja de enseñar la agenda en vez de enseñarla mal.

var FORMATO = 1;
var NOMBRE = "escritorio-agenda.json";
var DIA = /^\d{4}-\d\d-\d\d$/;
var HORA = /^\d\d:\d\d$/;
var COLOR = /^#[0-9a-fA-F]{6}$/;
var PRIORIDADES = ["maxima", "alta", "media", "baja", "minima", "pausa"];
var ORIGENES_TAREA = ["tarea", "clase"];

// El fichero, dentro del directorio de ejecución del usuario; "" si no hay.
function ruta(dirEjecucion) {
    var d = String(dirEjecucion || "").replace(/\/+$/, "");
    return d === "" ? "" : d + "/" + NOMBRE;
}

function dos(n) {
    return n < 10 ? "0" + n : String(n);
}

// "2026-10-21" de un año, un mes (0–11) y un día del mes.
function clave(anio, mes, dia) {
    return anio + "-" + dos(mes + 1) + "-" + dos(dia);
}

// "2026-10-21" de una fecha, en la hora local.
function claveDe(fecha) {
    return clave(fecha.getFullYear(), fecha.getMonth(), fecha.getDate());
}

// La fecha local (a medianoche) de "2026-10-21".
function fechaDe(dia) {
    var m = /^(\d{4})-(\d\d)-(\d\d)$/.exec(dia || "");
    return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null;
}

// --- Del lado del cajón ---------------------------------------------------------

// El título de una tarea: el texto sin Markdown (el «plano» de Api.qml), en una
// línea. El área va aparte: las entregas de Aules tienen el área «Clase» y el
// texto ya lleva la asignatura delante («MIA: Tarea 3»).
function titulo(plano) {
    return String(plano || "").replace(/\s+/g, " ").trim().slice(0, 300);
}

// La agenda de las tareas de Api.qml (api.tareas, ya normalizadas: secciones
// con sus tareas, cada una con vence, plano, hecha, vencida, prioridad y
// efectiva). Solo entran las que tienen fecha. null si no hay tareas que
// enseñar (sin cargar, o el panel no tiene las tareas activadas).
function deTareas(tareas, conectado, actualizado) {
    if (!tareas || tareas.habilitado === false)
        return null;
    var eventos = [];
    var secciones = tareas.secciones || [];
    for (var i = 0; i < secciones.length; i++) {
        var s = secciones[i];
        var lista = s.tareas || [];
        for (var j = 0; j < lista.length; j++) {
            var t = lista[j];
            var dia = String(t.vence || "");
            if (!DIA.test(dia))
                continue;
            var hecha = !!t.hecha;
            // La de hoy (la que el panel sube cerca de la fecha), salvo en
            // pausa; una hecha ya no sube, se queda con la suya.
            var prio = s.pausa ? "pausa" : String((hecha ? t.prioridad : t.efectiva || t.prioridad) || "");
            var texto = titulo(t.plano || t.texto);
            if (texto === "")
                continue;
            eventos.push({
                dia: dia,
                titulo: texto,
                origen: s.id === "clase" ? "clase" : "tarea",
                prioridad: PRIORIDADES.indexOf(prio) >= 0 ? prio : "",
                todoElDia: true,
                hora: "",
                vencida: !hecha && !!t.vencida,
                hecha: hecha,
                area: String(t.area || "").replace(/\s+/g, " ").trim().slice(0, 80),
                seccion: String(s.titulo || ""),
                color: COLOR.test(s.color || "") ? s.color : ""
            });
        }
    }
    // Por día; dentro del día, en el orden de la nota (sort es estable).
    eventos.sort(function (a, b) {
        return a.dia < b.dia ? -1 : a.dia > b.dia ? 1 : 0;
    });
    return {
        formato: FORMATO,
        conectado: !!conectado,
        actualizado: actualizado instanceof Date && isFinite(actualizado.getTime()) ? actualizado.toISOString() : "",
        eventos: eventos
    };
}

// --- Del lado de la barra -------------------------------------------------------

// Un evento del fichero, comprobado campo a campo; null si no vale. Lo que
// sobra se ignora y lo que falta toma su valor por defecto.
function limpio(e) {
    if (!e || typeof e !== "object" || !DIA.test(String(e.dia || "")))
        return null;
    var titulo = String(e.titulo || "").trim();
    if (titulo === "")
        return null;
    var prio = String(e.prioridad || "");
    var hora = String(e.hora || "");
    return {
        dia: String(e.dia),
        titulo: titulo.slice(0, 300),
        origen: String(e.origen || "tarea"),
        prioridad: PRIORIDADES.indexOf(prio) >= 0 ? prio : "",
        todoElDia: e.todoElDia !== false || !HORA.test(hora),
        hora: HORA.test(hora) ? hora : "",
        vencida: e.vencida === true,
        hecha: e.hecha === true,
        area: String(e.area || ""),
        seccion: String(e.seccion || ""),
        color: COLOR.test(String(e.color || "")) ? String(e.color) : ""
    };
}

function rango(prio) {
    var i = PRIORIDADES.indexOf(prio);
    return i < 0 ? PRIORIDADES.length : i;
}

// Si es una tarea sin hacer de un día que ya ha pasado. Lo calcula la barra con
// su «hoy», además de fiarse del panel: el fichero puede ser de ayer. Una
// reunión (cuando las haya) no vence, y una tarea en pausa tampoco: está
// aparcada a posta, y sale con el color de la pausa, no con el de vencida.
function vencida(e, hoy) {
    if (e.hecha || e.prioridad === "pausa" || ORIGENES_TAREA.indexOf(e.origen) < 0)
        return false;
    return e.vencida || (!!hoy && e.dia < hoy);
}

// El orden dentro de un día: lo vencido arriba, lo hecho abajo; en medio, lo
// de todo el día antes que lo que tiene hora, y después la prioridad.
function comparador(hoy) {
    return function (a, b) {
        var x = [vencida(a, hoy) ? 0 : 1, a.hecha ? 1 : 0, a.todoElDia ? "" : a.hora, rango(a.prioridad)];
        var y = [vencida(b, hoy) ? 0 : 1, b.hecha ? 1 : 0, b.todoElDia ? "" : b.hora, rango(b.prioridad)];
        for (var i = 0; i < x.length; i++) {
            if (x[i] < y[i])
                return -1;
            if (x[i] > y[i])
                return 1;
        }
        return a.titulo.localeCompare(b.titulo);
    };
}

// El texto del fichero, leído: { conectado, actualizado (Date o null),
// eventos, porDia: { "2026-10-22": [evento] } }, o null si no es una agenda
// de este formato. Nunca lanza: un fichero roto es como no tenerlo.
function leer(texto) {
    var d;
    try {
        d = JSON.parse(texto);
    } catch (e) {
        return null;
    }
    if (!d || typeof d !== "object" || d.formato !== FORMATO || !Array.isArray(d.eventos))
        return null;
    var eventos = [];
    var porDia = {};
    for (var i = 0; i < d.eventos.length; i++) {
        var e = limpio(d.eventos[i]);
        if (!e)
            continue;
        eventos.push(e);
        (porDia[e.dia] = porDia[e.dia] || []).push(e);
    }
    var cuando = typeof d.actualizado === "string" ? Date.parse(d.actualizado) : NaN;
    return {
        conectado: d.conectado === true,
        actualizado: isFinite(cuando) ? new Date(cuando) : null,
        eventos: eventos,
        porDia: porDia
    };
}

// Lo de un día, ordenado. Hoy lleva delante, además, las tareas vencidas de
// días anteriores que siguen sin hacer, con deAntes: true.
function delDia(agenda, dia, hoy) {
    if (!agenda)
        return [];
    var lista = (agenda.porDia[dia] || []).slice().sort(comparador(hoy));
    if (dia !== hoy)
        return lista;
    var antes = [];
    for (var i = 0; i < agenda.eventos.length; i++) {
        var e = agenda.eventos[i];
        if (e.dia < hoy && vencida(e, hoy))
            antes.push(Object.assign({}, e, {
                deAntes: true
            }));
    }
    // Las que vencieron antes, primero; las del mismo día, como en el día.
    var orden = comparador(hoy);
    antes.sort(function (a, b) {
        return a.dia < b.dia ? -1 : a.dia > b.dia ? 1 : orden(a, b);
    });
    return antes.concat(lista);
}

// Con qué color se pinta un evento: "vencida", "hecha" o su prioridad ("" sin
// ella). El color de cada uno lo pone la barra, con la paleta de Theme.
function tipo(e, hoy) {
    return vencida(e, hoy) ? "vencida" : e.hecha ? "hecha" : e.prioridad;
}

// Los puntos de una casilla del mes: como mucho «max», uno por evento, en el
// orden del día; cada uno, su tipo().
function puntos(agenda, dia, hoy, max) {
    if (!agenda || !agenda.porDia[dia])
        return [];
    var lista = agenda.porDia[dia].slice().sort(comparador(hoy));
    var r = [];
    for (var i = 0; i < lista.length && i < max; i++)
        r.push(tipo(lista[i], hoy));
    return r;
}

// «19 oct», de "2026-10-19". Los meses van escritos aquí y no con el formato
// "MMM" de Qt, que según la versión de los datos regionales lleva punto o no.
var MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

function diaCorto(dia) {
    var f = fechaDe(dia);
    return f ? f.getDate() + " " + MESES[f.getMonth()] : "";
}
