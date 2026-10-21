.pragma library

// Las reglas de Finanzas en el cajón, sin nada de interfaz: formatear los
// euros, leer lo que escribe el usuario y partir los movimientos por días. Los
// importes llegan del NUC en céntimos enteros (como en la web) y aquí se
// quedan así hasta pintarlos. Los euros solo se pintan con el cajón
// desplegado (E11): euros() lo decide con «ver».

var MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

// Lo que sale en lugar de una cantidad mientras el cajón no está desplegado.
// Sin el signo del euro: es lo que comprueban las pruebas.
var OCULTO = "•••";

// 123456 → "1.234,56 €"; -500 → "-5,00 €". Con ver a false, OCULTO.
function euros(cents, ver) {
    if (!ver)
        return OCULTO;
    if (cents === null || cents === undefined || !isFinite(cents))
        return "—";
    var n = Math.abs(Math.round(cents));
    var ent = String(Math.floor(n / 100)).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    var dec = ("0" + (n % 100)).slice(-2);
    return (cents < 0 ? "-" : "") + ent + "," + dec + " €";
}

// Lo que se escribe en el campo del importe → céntimos enteros, o null si no
// vale: «12», «12,5», «12.50», «1.234,56», con o sin €. Más de dos decimales o
// cero no valen (el NUC pide un importe positivo).
function centimos(texto) {
    var t = String(texto || "").replace(/€/g, "").replace(/\s+/g, "");
    if (t === "")
        return null;
    if (t.indexOf(",") >= 0)
        t = t.replace(/\./g, "").replace(",", ".");
    else if (/^\d{1,3}(\.\d{3})+$/.test(t))
        t = t.replace(/\./g, "");
    var m = /^(\d{1,9})(?:\.(\d{1,2}))?$/.exec(t);
    if (!m)
        return null;
    var c = Number(m[1]) * 100 + (m[2] ? Number((m[2] + "0").slice(0, 2)) : 0);
    return c > 0 ? c : null;
}

// "2026-10" → "octubre 2026".
function nombreMes(mes) {
    var m = /^(\d{4})-(\d\d)/.exec(mes || "");
    return m && MESES[+m[2] - 1] ? MESES[+m[2] - 1] + " " + m[1] : "";
}

// "2026-10-21" → "21 oct".
function diaCorto(f) {
    var m = /^\d{4}-(\d\d)-(\d\d)/.exec(f || "");
    return m && MESES[+m[1] - 1] ? Number(m[2]) + " " + MESES[+m[1] - 1].slice(0, 3) : String(f || "");
}

// Gasto del mes frente al anterior, en palabras y sin cantidades:
// "un 12 % más que septiembre". "" si no hay con qué comparar.
function comparar(gastos) {
    if (!gastos || !(gastos.anterior > 0))
        return "";
    var d = Math.round((gastos.total - gastos.anterior) * 100 / gastos.anterior);
    var mes = nombreMes(gastos.mesAnterior).split(" ")[0] || "el mes anterior";
    if (d === 0)
        return "igual que " + mes;
    return "un " + Math.abs(d) + " % " + (d > 0 ? "más" : "menos") + " que " + mes;
}
