.pragma library

// Las reglas de ver el Registro del NUC en el cajón, sin nada de interfaz: los
// filtros y los nombres de la web (el «Registro» de
// panel/internal/panel/web/app.js e index.html, repo homelab) y las líneas
// partidas por días.

// [valor del filtro, lo que pone]. El valor es el de GET /api/journal: una
// fuente, o «level:warn» para avisos y errores.
var FILTROS = [["", "Todo"], ["level:warn", "Avisos y errores"], ["container", "Contenedores"], ["apt", "Paquetes"], ["system", "Sistema"], ["disk", "Discos"], ["panel", "Panel"]];

var FUENTES = {
    container: "contenedor",
    apt: "paquetes",
    system: "sistema",
    disk: "disco",
    panel: "panel"
};

var DIAS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
var MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

function fuente(f) {
    return FUENTES[f] || f;
}

function mismoDia(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

// «Hoy», «Ayer» o «martes 14 de octubre» (con el año si no es este).
function dia(fecha, ahora) {
    var hoy = ahora || new Date();
    var ayer = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() - 1);
    if (mismoDia(fecha, hoy))
        return "Hoy";
    if (mismoDia(fecha, ayer))
        return "Ayer";
    var t = DIAS[fecha.getDay()] + " " + fecha.getDate() + " de " + MESES[fecha.getMonth()];
    return fecha.getFullYear() === hoy.getFullYear() ? t : t + " de " + fecha.getFullYear();
}

function dos(n) {
    return (n < 10 ? "0" : "") + n;
}

// «14:03».
function hora(fecha) {
    return dos(fecha.getHours()) + ":" + dos(fecha.getMinutes());
}

// Las entradas con una cabecera cada vez que cambia el día: [{ tipo ("dia" o
// "entrada"), clave, texto, e }].
function conDias(entradas, ahora) {
    var out = [];
    var ultimo = "";
    (entradas || []).forEach(function (e) {
        var d = e.hora;
        var k = d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
        if (k !== ultimo) {
            out.push({
                tipo: "dia",
                clave: "d" + k,
                texto: dia(d, ahora),
                e: null
            });
            ultimo = k;
        }
        out.push({
            tipo: "entrada",
            clave: "e" + e.id,
            texto: "",
            e: e
        });
    });
    return out;
}
